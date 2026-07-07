-- =============================================================================
-- Tafseer.id — Topic Recommendation Engine (Supabase SQL)
-- Run this in: Supabase Dashboard → SQL Editor
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. get_related_verses_by_topic
--    Given a verse_key, find other verses that share the most tags with it.
--    Used for "You might also find relevant" suggestions on the Ayah detail page.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function get_related_verses(
    input_verse_key text,
    trans_source     text    default 'id.kemenag',
    result_limit     integer default 6
)
returns table (
    verse_key        text,
    text_ar          text,
    translation_text text,
    shared_tags      bigint
)
language sql
security definer
as $$
    with
    -- tags of the input verse
    input_tags as (
        select tag_id
        from   verse_tags vt
        join   verses v on v.id = vt.verse_id
        where  v.verse_key = input_verse_key
    ),
    -- other verses that share at least one tag
    scored as (
        select  vt.verse_id,
                count(*) as shared_tags
        from    verse_tags vt
        join    input_tags it on it.tag_id = vt.tag_id
        join    verses v on v.id = vt.verse_id
        where   v.verse_key <> input_verse_key
        group by vt.verse_id
        order by shared_tags desc
        limit   result_limit
    )
    select
        v.verse_key,
        v.text_ar,
        t.text  as translation_text,
        s.shared_tags
    from   scored s
    join   verses v on v.id = s.verse_id
    left   join translations t
               on  t.verse_id = s.verse_id
               and t.source_id = trans_source
    order  by s.shared_tags desc;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. get_topic_summary
--    Returns a topic/tag with its verse count and a few sample verse keys.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function get_topic_summary(
    target_lang text default 'id'
)
returns table (
    tag_id      text,
    tag_name    text,
    verse_count bigint,
    sample_keys text[]
)
language sql
security definer
as $$
    select
        tg.id                                               as tag_id,
        tg.name                                             as tag_name,
        count(distinct vt.verse_id)                         as verse_count,
        (array_agg(distinct v.verse_key order by v.verse_key)
            filter (where v.verse_key is not null))[1:5]    as sample_keys
    from   tags tg
    join   verse_tags vt on vt.tag_id = tg.id
    join   verses v      on v.id      = vt.verse_id
    where  tg.lang = target_lang
    group  by tg.id, tg.name
    order  by verse_count desc;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. search_verses
--    Unified search: matches Arabic text (exact substring) OR translation text.
--    Returns ranked results — Arabic matches score higher.
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
    match_score      integer
)
language sql
security definer
as $$
    select
        v.verse_key,
        v.text_ar,
        t.text   as translation_text,
        case
            when v.text_ar ilike '%' || query || '%' then 2
            else 1
        end as match_score
    from   translations t
    join   verses v on v.id = t.verse_id
    where  (
               t.text    ilike '%' || query || '%'
            or v.text_ar ilike '%' || query || '%'
           )
    and    (
               (lang_code = 'id' and t.source_id like 'id.%')
            or (lang_code = 'en' and t.source_id like 'en.%')
           )
    order  by match_score desc, v.sura_id asc, v.ayah_number asc
    limit  result_limit
    offset offset_val;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 4. get_reading_stats
--    Quick stats for the home dashboard card.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function get_reading_stats()
returns table (
    total_verses    bigint,
    total_surahs    bigint,
    total_tags      bigint,
    total_tafsirs   bigint,
    total_nuzul     bigint
)
language sql
security definer
as $$
    select
        (select count(*) from verses)       as total_verses,
        (select count(*) from surahs)       as total_surahs,
        (select count(distinct id) from tags) as total_tags,
        (select count(*) from tafsirs)      as total_tafsirs,
        (select count(*) from asbabun_nuzul) as total_nuzul;
$$;


-- ─────────────────────────────────────────────────────────────────────────────
-- 5. semantic_search_setup & function
--    Enable pgvector, add embedding column, and create semantic_search_verses RPC.
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable vector extension
create extension if not exists vector;

-- Add embedding column to translations if not exists (384 dimensions for MiniLM model)
alter table translations add column if not exists embedding vector(384);

-- Create a spatial index for fast cosine distance matching
create index if not exists translations_embedding_idx on translations using hnsw (embedding vector_cosine_ops);

-- Create matching RPC for semantic search
create or replace function semantic_search_verses(
    query_embedding vector(384),
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
      and (
         (lang_code = 'id' and t.source_id like 'id.%')
         or (lang_code = 'en' and t.source_id like 'en.%')
      )
    order by t.embedding <=> query_embedding
    limit result_limit
    offset offset_val;
$$;

