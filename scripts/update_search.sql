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
drop function if exists get_query_embedding(text);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. get_query_embedding
--    Fetches sentence embedding from Hugging Face Inference API directly
--    from the database (bypasses client-side network blocking & CORS).
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function get_query_embedding(query_text text)
returns vector(384)
language plpgsql
security definer
as $$
declare
    response http_response;
    embed_json jsonb;
    embed_vector vector(384);
    api_url text := 'https://api-inference.huggingface.co/models/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2';
begin
    -- Perform HTTP POST to Hugging Face
    response := http_post(
        api_url,
        json_build_object('inputs', array[query_text])::text,
        'application/json'
    );
    
    -- Model loading retry logic
    if response.status = 503 then
        perform pg_sleep(3);
        response := http_post(
            api_url,
            json_build_object('inputs', array[query_text])::text,
            'application/json'
        );
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
-- 4. search_verses (UPDATED: High-Performance Multi-Word AND Search)
--    Matches keywords across:
--      - Arabic text (verses)
--      - Translations (translations)
--      - Tafsirs (commentaries)
--      - Asbabun Nuzul (revelation context)
--      - Topic Tags (tags)
--    Returns dynamic matched_tags array, match_note, and context_snippet JSON array.
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
    query_words text[];
    num_words integer;
    target_source text;
begin
    -- Split query by whitespace into lowercase words
    query_words := regexp_split_to_array(lower(trim(query)), '\s+');
    num_words := array_length(query_words, 1);
    
    if num_words is null or num_words = 0 then
        return;
    end if;

    -- Default display translation source based on language
    target_source := case when lang_code = 'id' then 'id.kemenag' else 'en.sahih' end;

    return query
    with word_matches as (
        -- Match in translations (pre-filtered by target language to avoid scanning 150k rows)
        select tr.verse_id, w.word
        from (
            select translations.verse_id, translations.text
            from translations
            where translations.source_id ilike lang_code || '.%'
        ) tr
        join unnest(query_words) as w(word) on tr.text ilike '%' || w.word || '%'
        
        union all
        
        -- Match in verses (Arabic text, exactly 6,236 rows)
        select v.id as verse_id, w.word
        from verses v
        join unnest(query_words) as w(word) on v.text_ar ilike '%' || w.word || '%'
        
        union all
        
        -- Match in tafsirs (pre-filtered by target language to avoid scanning all commentaries)
        select tf.verse_id, w.word
        from (
            select tafsirs.verse_id, tafsirs.text
            from tafsirs
            where tafsirs.source_id ilike lang_code || '.%'
        ) tf
        join unnest(query_words) as w(word) on tf.text ilike '%' || w.word || '%'
        
        union all
        
        -- Match in asbabun_nuzul (~500 rows)
        select an.verse_id, w.word
        from asbabun_nuzul an
        join unnest(query_words) as w(word) on an.text ilike '%' || w.word || '%'
        
        union all
        
        -- Match in tags (pre-filtered by tag language)
        select vt.verse_id, w.word
        from verse_tags vt
        join tags tg on tg.id = vt.tag_id
        join unnest(query_words) as w(word) on tg.name ilike '%' || w.word || '%'
        where tg.lang = lang_code
    ),
    
    -- Filter verses that match ALL query words
    matching_verse_ids as (
        select wm.verse_id
        from word_matches wm
        group by wm.verse_id
        having count(distinct wm.word) = num_words
    )
    
    select
        v.verse_key,
        v.text_ar,
        t.text   as translation_text,
        case
            -- highest score: exact phrase match in Arabic
            when v.text_ar ilike '%' || query || '%' then 5
            -- high score: exact phrase match in translation
            when t.text ilike '%' || query || '%' then 4
            else 2
        end as match_score,
        
        -- Collect tag names linked to this verse matching any query keyword
        (
            select array_agg(tg.name)
            from verse_tags vt
            join tags tg on tg.id = vt.tag_id
            where vt.verse_id = v.id
              and tg.lang = lang_code
              and (
                  select bool_or(tg.name ilike '%' || w.word || '%')
                  from unnest(query_words) as w(word)
              )
        ) as matched_tags,
        
        -- Match source metadata notes
        case
            when exists (
                select 1 from translations tr
                where tr.verse_id = v.id and tr.source_id = target_source
                  and (select bool_and(tr.text ilike '%' || w.word || '%') from unnest(query_words) as w(word))
            ) then 'Translation'
            when exists (
                select 1 from tafsirs tf
                where tf.verse_id = v.id and tf.source_id ilike lang_code || '.%'
                  and (select bool_and(tf.text ilike '%' || w.word || '%') from unnest(query_words) as w(word))
            ) then 'Tafsir'
            when exists (
                select 1 from asbabun_nuzul an
                where an.verse_id = v.id
                  and (select bool_and(an.text ilike '%' || w.word || '%') from unnest(query_words) as w(word))
            ) then 'Asbabun Nuzul'
            else null
        end as match_note,
        
        -- JSON array of all source matches for context display and highlight in the UI.
        -- Each entry is centered on the first keyword match using strpos() offset.
        (
            select json_agg(item)
            from (
                -- Match in translations (centered on first keyword)
                select
                    json_build_object(
                        'source_name', case when tr.source_id = 'id.kemenag' then 'Kemenag RI Translation' else 'Sahih International' end,
                        'source_type', 'Translation',
                        'text', (
                            select substring(tr.text from greatest(1,
                                min(strpos(lower(tr.text), w.word)) - 120) for 300)
                            from unnest(query_words) as w(word)
                            where strpos(lower(tr.text), w.word) > 0
                        )
                    ) as item
                from translations tr
                where tr.verse_id = v.id
                  and tr.source_id = target_source
                  and (select bool_or(tr.text ilike '%' || w.word || '%') from unnest(query_words) as w(word))

                union all

                -- Match in tafsirs (centered on first keyword)
                select
                    json_build_object(
                        'source_name', case
                            when tf.source_id = 'id.jalalayn' then 'Tafsir Jalalayn (ID)'
                            when tf.source_id = 'id.kemenag'  then 'Tafsir Kemenag (ID)'
                            when tf.source_id = 'en.katsir'   then 'Tafsir Ibn Kathir (EN)'
                            else tf.source_id
                        end,
                        'source_type', 'Tafsir',
                        'text', (
                            select substring(tf.text from greatest(1,
                                min(strpos(lower(tf.text), w.word)) - 120) for 300)
                            from unnest(query_words) as w(word)
                            where strpos(lower(tf.text), w.word) > 0
                        )
                    ) as item
                from tafsirs tf
                where tf.verse_id = v.id
                  and tf.source_id ilike lang_code || '.%'
                  and (select bool_or(tf.text ilike '%' || w.word || '%') from unnest(query_words) as w(word))

                union all

                -- Match in asbabun nuzul (centered on first keyword)
                select
                    json_build_object(
                        'source_name', 'Asbabun Nuzul (al-Wahidi)',
                        'source_type', 'Asbabun Nuzul',
                        'text', (
                            select substring(an.text from greatest(1,
                                min(strpos(lower(an.text), w.word)) - 120) for 300)
                            from unnest(query_words) as w(word)
                            where strpos(lower(an.text), w.word) > 0
                        )
                    ) as item
                from asbabun_nuzul an
                where an.verse_id = v.id
                  and (select bool_or(an.text ilike '%' || w.word || '%') from unnest(query_words) as w(word))
            ) snippets
        )::text as context_snippet
        
    from matching_verse_ids mv
    join verses v on v.id = mv.verse_id
    left join translations t on t.verse_id = mv.verse_id and t.source_id = target_source
    order  by match_score desc, v.sura_id asc, v.ayah_number asc
    limit  result_limit
    offset offset_val;
end;
$$;
