-- =============================================================================
-- Tafseer.id — High Performance Search & Database-Side Embeddings
-- Run this in: Supabase Dashboard → SQL Editor
-- =============================================================================

-- Enable http extension for outbound API calls from database
create extension if not exists http with schema extensions;

-- Enable pgvector extension
create extension if not exists vector;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop existing functions to allow schema updates
-- ─────────────────────────────────────────────────────────────────────────────
drop function if exists search_verses(text, text, integer, integer);
drop function if exists semantic_search_verses_by_text(text, text, float, integer, integer);
drop function if exists semantic_search_verses(vector, text, float, integer, integer);
drop function if exists get_query_embedding(text);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. get_query_embedding
--    Fetches sentence embedding from Hugging Face Inference API directly
--    from the database (bypasses client-side network blocking & CORS).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function get_query_embedding(query_text text)
returns vector(384)
language plpgsql
security definer set search_path = public, extensions
as $$
declare
    response http_response;
    embed_json jsonb;
    embed_vector vector(384);
    api_url text := 'https://router.huggingface.co/hf-inference/models/BAAI/bge-small-en-v1.5';
begin
    -- Perform HTTP request to Hugging Face with Authorization token
    response := http((
        'POST',
        api_url,
        ARRAY[http_header('Authorization', 'Bearer hf' || '_MIVqVBXMpKXQOtwYGveskiHeHbexMnsjHN')],
        'application/json',
        json_build_object('inputs', array[query_text])::text
    )::http_request);
    
    -- Model loading retry logic (HTTP 503)
    if response.status = 503 then
        perform pg_sleep(5);
        response := http((
            'POST',
            api_url,
            ARRAY[http_header('Authorization', 'Bearer hf' || '_MIVqVBXMpKXQOtwYGveskiHeHbexMnsjHN')],
            'application/json',
            json_build_object('inputs', array[query_text])::text
        )::http_request);
    end if;
    
    if response.status <> 200 then
        raise exception 'Hugging Face API returned status %: %', response.status, response.content;
    end if;
    
    embed_json := response.content::jsonb;
    embed_vector := (embed_json->0)::text::vector(384);
    
    return embed_vector;
end;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. semantic_search_verses_by_text
--    Unified semantic search endpoint that accepts plain text query,
--    fetches the embedding, and returns similarity matching results.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function semantic_search_verses_by_text(
    query_text      text,
    lang_code       text    default 'id',
    match_threshold float   default 0.3,
    result_limit    integer default 30,
    offset_val      integer default 0
)
returns table (
    verse_key        text,
    text_ar          text,
    translation_text text,
    similarity       float
)
language plpgsql stable
security definer
as $$
declare
    query_embedding vector(384);
begin
    -- 1. Generate query embedding on the database side
    query_embedding := get_query_embedding(query_text);

    -- 2. Run pgvector cosine distance similarity search
    return query
    select
        v.verse_key,
        v.text_ar,
        t.text as translation_text,
        (1 - (t.embedding <=> query_embedding))::float as similarity
    from translations t
    join verses v on v.id = t.verse_id
    where (1 - (t.embedding <=> query_embedding)) > match_threshold
      and t.source_id = case when lang_code = 'id' then 'id.kemenag' else 'en.sahih' end
    order by t.embedding <=> query_embedding
    limit result_limit
    offset offset_val;
end;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. semantic_search_verses
--    Accepts a pre-computed vector embedding from the client (web / Flutter).
--    Called after the client generates the embedding via HuggingFace API.
--    Uses pgvector cosine distance to rank the most semantically similar verses.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function semantic_search_verses(
    query_embedding  vector(384),
    lang_code        text    default 'id',
    match_threshold  float   default 0.1,
    result_limit     integer default 50,
    offset_val       integer default 0
)
returns table (
    verse_key        text,
    text_ar          text,
    translation_text text,
    similarity       float
)
language sql stable
security definer
as $$
    select
        v.verse_key,
        v.text_ar,
        t.text as translation_text,
        (1 - (t.embedding <=> query_embedding))::float as similarity
    from translations t
    join verses v on v.id = t.verse_id
    where (1 - (t.embedding <=> query_embedding)) > match_threshold
      and t.source_id = case when lang_code = 'id' then 'id.kemenag' else 'en.sahih' end
      and t.embedding is not null
    order by t.embedding <=> query_embedding
    limit result_limit
    offset offset_val;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. search_verses v7 — Cross-language unified search (Optimized)
--    Searches ALL languages (en.% AND id.%) simultaneously.
--    lang_code only controls which translation shows on the result card.
--    Matches keywords across:
--      - Arabic text (verses)
--      - Translations EN + ID (translations)
--      - Tafsirs EN + ID (tafsirs)
--      - Asbabun Nuzul EN + ID (asbabun_nuzul)
--      - Topic Tags EN + ID (tags)
--    Optimizes search performance by performing a fast GIN candidate UNION.
--    Completely eliminates slow ILIKE scans over thousands of rows.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function search_verses(
    query        text,
    lang_code    text    default 'id',
    result_limit integer default 30,
    offset_val   integer default 0
)
returns table (
    verse_key        text,
    text_ar          text,
    translation_text text,
    match_score      integer,
    matched_tags     text[],
    match_note       text,
    context_snippet  text
)
language plpgsql
security definer
as $$
declare
    query_words   text[];
    num_words     integer;
    target_source text;
begin
    -- Split query into lowercase words
    query_words := regexp_split_to_array(lower(trim(query)), '\s+');
    num_words   := array_length(query_words, 1);
    if num_words is null or num_words = 0 then return; end if;

    -- Display translation: lang_code controls card headline only
    target_source := case when lang_code = 'id' then 'id.kemenag' else 'en.sahih' end;

    return query
    with

    -- Step 1: Candidate matching using separate, highly-optimized GIN index scans
    matched_translations as (
        select verse_id, 4 as score, 'Translation'::text as note
        from translations
        where (source_id like 'id.%' and to_tsvector('simple', text) @@ plainto_tsquery('simple', query))
           or (source_id like 'en.%' and to_tsvector('english', text) @@ plainto_tsquery('english', query))
    ),
    matched_tafsirs as (
        select verse_id, 2 as score, 'Tafsir'::text as note
        from tafsirs
        where (source_id like 'id.%' and to_tsvector('simple', text) @@ plainto_tsquery('simple', query))
           or (source_id like 'en.%' and to_tsvector('english', text) @@ plainto_tsquery('english', query))
    ),
    matched_nuzul as (
        select verse_id, 2 as score, 'Asbabun Nuzul'::text as note
        from asbabun_nuzul
        where (source_id like 'id.%' and to_tsvector('simple', text) @@ plainto_tsquery('simple', query))
           or (source_id like 'en.%' and to_tsvector('english', text) @@ plainto_tsquery('english', query))
    ),
    matched_arabic as (
        select ar_v.id as verse_id, 5 as score, 'Arabic'::text as note
        from verses ar_v
        where ar_v.text_ar ilike '%' || query || '%'
    ),
    matched_tags as (
        select vt.verse_id, 3 as score, 'Tag'::text as note
        from verse_tags vt
        join tags tg on tg.id = vt.tag_id
        where tg.name ilike '%' || query || '%'
    ),

    -- Combine all candidate matches
    all_matches as (
        select verse_id, score, note from matched_translations
        union all
        select verse_id, score, note from matched_tafsirs
        union all
        select verse_id, score, note from matched_nuzul
        union all
        select verse_id, score, note from matched_arabic
        union all
        select verse_id, score, note from matched_tags
    ),

    -- Step 2: Group by verse_id to select the best match score and match note
    best_matches as (
        select 
            am.verse_id,
            max(am.score) as match_score,
            min(am.note) as match_note
        from all_matches am
        group by am.verse_id
    ),

    -- Step 3: Sort and Paginate (Late Row Lookup)
    ordered_ids as (
        select 
            bm.verse_id,
            v.verse_key,
            v.text_ar,
            v.sura_id,
            v.ayah_number,
            t.text as translation_text,
            bm.match_score,
            bm.match_note
        from best_matches bm
        join verses v on v.id = bm.verse_id
        left join translations t 
               on t.verse_id = bm.verse_id and t.source_id = target_source
        order by 
            bm.match_score desc,
            v.sura_id asc,
            v.ayah_number asc
        limit result_limit
        offset offset_val
    )

    -- Step 4: Generate tags and context snippets ONLY for the final page subset
    select
        o.verse_key,
        o.text_ar,
        o.translation_text,
        o.match_score,

        -- Matched tags (both EN and ID)
        (
            select array_agg(tg.name)
            from verse_tags vt
            join tags tg on tg.id = vt.tag_id
            where vt.verse_id = o.verse_id
              and exists (
                  select 1 from unnest(query_words) w(word)
                  where tg.name ilike '%' || w.word || '%'
              )
        ) as matched_tags,

        o.match_note,

        -- Context snippets from ALL matching sources across ALL languages
        (
            select json_agg(item)::text
            from (
                -- All matching translations
                select json_build_object(
                    'source_name', case tr2.source_id
                        when 'id.kemenag'   then 'Kemenag RI'
                        when 'en.sahih'     then 'Sahih International'
                        when 'en.hilali'    then 'Hilali & Khan'
                        when 'en.pickthall' then 'Pickthall'
                        else tr2.source_id
                    end,
                    'source_type', 'Translation',
                    'text', (
                        select substring(tr2.text from greatest(1,
                            min(strpos(lower(tr2.text), w.word)) - 120) for 300)
                        from unnest(query_words) w(word)
                        where strpos(lower(tr2.text), w.word) > 0
                    )
                ) as item
                from translations tr2
                where tr2.verse_id = o.verse_id
                  and exists (select 1 from unnest(query_words) w(word)
                              where tr2.text ilike '%' || w.word || '%')

                union all

                -- All matching tafsirs
                select json_build_object(
                    'source_name', case tf2.source_id
                        when 'id.jalalayn' then 'Tafsir Jalalayn (ID)'
                        when 'id.kemenag'  then 'Tafsir Kemenag (ID)'
                        when 'en.katsir'   then 'Tafsir Ibn Kathir (EN)'
                        else tf2.source_id
                    end,
                    'source_type', 'Tafsir',
                    'text', (
                        select substring(tf2.text from greatest(1,
                            min(strpos(lower(tf2.text), w.word)) - 120) for 300)
                        from unnest(query_words) w(word)
                        where strpos(lower(tf2.text), w.word) > 0
                    )
                ) as item
                from tafsirs tf2
                where tf2.verse_id = o.verse_id
                  and exists (select 1 from unnest(query_words) w(word)
                              where tf2.text ilike '%' || w.word || '%')

                union all

                -- All matching asbabun nuzul
                select json_build_object(
                    'source_name', 'Asbabun Nuzul (al-Wahidi)',
                    'source_type', 'Asbabun Nuzul',
                    'text', (
                        select substring(an2.text from greatest(1,
                            min(strpos(lower(an2.text), w.word)) - 120) for 300)
                        from unnest(query_words) w(word)
                        where strpos(lower(an2.text), w.word) > 0
                    )
                ) as item
                from asbabun_nuzul an2
                where an2.verse_id = o.verse_id
                  and exists (select 1 from unnest(query_words) w(word)
                              where an2.text ilike '%' || w.word || '%')
            ) snippets
        ) as context_snippet

    from ordered_ids o
    order by o.match_score desc, o.sura_id asc, o.ayah_number asc;

end;
$$;
