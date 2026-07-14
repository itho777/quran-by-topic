-- ==============================================================
-- Tafseer.id — Database Cleanup, RLS Fix & Optimized RPCs
-- Run this ENTIRE script in Supabase Dashboard → SQL Editor
-- ==============================================================
-- 
-- ROOT CAUSE OF ~600 MB SIZE:
--   1. fts_simple + fts_english STORED columns + their GIN indexes in
--      translations & tafsirs  → ~200-300 MB (redundant - static JSON index
--      replaced this)
--   2. embedding column in translations (12,472 × 384 floats × 4 bytes ≈ 19 MB
--      data + HNSW index ~80 MB overhead)
--   3. 76,053 tafsir rows + extra translation sources bloat raw text storage
--
-- AFTER THIS SCRIPT:
--   - embeddings live in verse_embeddings (cleaner, faster HNSW)
--   - FTS stored columns gone (expression GIN indexes kept for search_verses)
--   - Only essential sources kept in Supabase; others via local JSON fallback
--   - RLS disabled for anonymous access
--   - Expected size: ~60-100 MB (down from ~600 MB)
-- ==============================================================

-- ============================================================
-- STEP 1: Disable Row Level Security
-- ============================================================
ALTER TABLE public.surahs         DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.verses         DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.translations   DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tafsirs        DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.asbabun_nuzul  DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags           DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.verse_tags     DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 2: Create verse_embeddings table
-- (Move embeddings out of translations into a dedicated table)
-- ============================================================
DROP TABLE IF EXISTS public.verse_embeddings;

CREATE TABLE public.verse_embeddings (
  id         BIGSERIAL PRIMARY KEY,
  verse_key  TEXT NOT NULL,
  verse_id   BIGINT REFERENCES public.verses(id) ON DELETE CASCADE,
  source_id  TEXT NOT NULL,  -- 'en.sahih' or 'id.kemenag'
  embedding  vector(384),    -- BAAI/bge-small-en-v1.5 produces 384-dim vectors
  UNIQUE (verse_key, source_id)
);

-- Copy embeddings from translations into the new dedicated table
INSERT INTO public.verse_embeddings (verse_key, verse_id, source_id, embedding)
SELECT t.verse_key, t.verse_id, t.source_id, t.embedding
FROM   public.translations t
WHERE  t.embedding IS NOT NULL
ON CONFLICT (verse_key, source_id) DO NOTHING;

-- HNSW index for fast cosine similarity search
CREATE INDEX verse_embeddings_hnsw_idx
  ON public.verse_embeddings USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- Regular index for filtering by source
CREATE INDEX verse_embeddings_source_idx
  ON public.verse_embeddings (source_id, verse_key);

-- Disable RLS on new table
ALTER TABLE public.verse_embeddings DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- STEP 3: Drop stored FTS columns from translations
-- (The expression GIN indexes are kept for search_verses RPC)
-- ============================================================
DROP INDEX IF EXISTS translations_fts_simple_idx;
DROP INDEX IF EXISTS translations_fts_english_idx;
DROP INDEX IF EXISTS idx_translations_fts_simple;
DROP INDEX IF EXISTS idx_translations_fts_english;

ALTER TABLE public.translations
  DROP COLUMN IF EXISTS fts_simple,
  DROP COLUMN IF EXISTS fts_english,
  DROP COLUMN IF EXISTS embedding;

-- ============================================================
-- STEP 4: Drop stored FTS columns from tafsirs
-- ============================================================
DROP INDEX IF EXISTS tafsirs_fts_simple_idx;
DROP INDEX IF EXISTS tafsirs_fts_english_idx;
DROP INDEX IF EXISTS idx_tafsirs_fts_simple;
DROP INDEX IF EXISTS idx_tafsirs_fts_english;

ALTER TABLE public.tafsirs
  DROP COLUMN IF EXISTS fts_simple,
  DROP COLUMN IF EXISTS fts_english;

-- ============================================================
-- STEP 5: Trim translations — keep only essential online sources
-- (All other translations are served from local JSON files)
-- ============================================================
DELETE FROM public.translations
WHERE source_id NOT IN (
  'en.sahih',           -- English primary (has embeddings)
  'id.kemenag',         -- Indonesian primary (has embeddings)
  'id.indonesian',      -- Indonesian legacy fallback
  'en.transliteration', -- Latin transliteration for Arabic
  'id.kemenag_translit' -- Indonesian transliteration
);

-- ============================================================
-- STEP 6: Trim tafsirs — keep only most-used online sources
-- (Others are served from local JSON files)
-- ============================================================
DELETE FROM public.tafsirs
WHERE source_id NOT IN (
  'id.jalalayn',   -- Most popular Indonesian tafsir
  'id.muntakhab',  -- Quraish Shihab (widely used in Indonesia)
  'en.maududi',    -- Most widely used English tafsir
  'ar.muyassar'    -- Short Arabic tafsir for Arabic readers
);

-- ============================================================
-- STEP 7: Update semantic search RPCs to use verse_embeddings
-- ============================================================

-- 7a. semantic_search_verses_by_text (server-side embedding via HuggingFace)
CREATE OR REPLACE FUNCTION semantic_search_verses_by_text(
    query_text      text,
    lang_code       text    DEFAULT 'id',
    match_threshold float   DEFAULT 0.1,
    result_limit    integer DEFAULT 30,
    offset_val      integer DEFAULT 0
)
RETURNS TABLE (
    verse_key        text,
    text_ar          text,
    translation_text text,
    similarity       float
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
AS $$
DECLARE
    query_embedding vector(384);
    target_source   text;
BEGIN
    query_embedding := get_query_embedding(query_text);
    target_source   := CASE WHEN lang_code = 'id' THEN 'id.kemenag' ELSE 'en.sahih' END;

    RETURN QUERY
    SELECT
        v.verse_key,
        v.text_ar,
        t.text AS translation_text,
        (1 - (ve.embedding <=> query_embedding))::float AS similarity
    FROM verse_embeddings ve
    JOIN verses v       ON v.verse_key = ve.verse_key
    LEFT JOIN translations t ON t.verse_key = ve.verse_key AND t.source_id = target_source
    WHERE ve.source_id = target_source
      AND (1 - (ve.embedding <=> query_embedding)) > match_threshold
    ORDER BY ve.embedding <=> query_embedding
    LIMIT result_limit
    OFFSET offset_val;
END;
$$;

-- 7b. semantic_search_verses (client provides pre-computed embedding)
CREATE OR REPLACE FUNCTION semantic_search_verses(
    query_embedding  vector(384),
    lang_code        text    DEFAULT 'id',
    match_threshold  float   DEFAULT 0.1,
    result_limit     integer DEFAULT 50,
    offset_val       integer DEFAULT 0
)
RETURNS TABLE (
    verse_key        text,
    text_ar          text,
    translation_text text,
    similarity       float
)
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
    SELECT
        v.verse_key,
        v.text_ar,
        t.text AS translation_text,
        (1 - (ve.embedding <=> query_embedding))::float AS similarity
    FROM verse_embeddings ve
    JOIN verses v       ON v.verse_key = ve.verse_key
    LEFT JOIN translations t
              ON t.verse_key = ve.verse_key
             AND t.source_id = CASE WHEN lang_code = 'id' THEN 'id.kemenag' ELSE 'en.sahih' END
    WHERE ve.source_id = CASE WHEN lang_code = 'id' THEN 'id.kemenag' ELSE 'en.sahih' END
      AND (1 - (ve.embedding <=> query_embedding)) > match_threshold
    ORDER BY ve.embedding <=> query_embedding
    LIMIT result_limit
    OFFSET offset_val;
$$;

-- 7c. get_related_verses (find similar verses using vector similarity)
--     Called from Flutter's AyahDetailScreen with: input_verse_key, trans_source, result_limit
DROP FUNCTION IF EXISTS get_related_verses(text, text, integer);

CREATE OR REPLACE FUNCTION get_related_verses(
    input_verse_key  text,
    trans_source     text    DEFAULT 'id.kemenag',
    result_limit     integer DEFAULT 6
)
RETURNS TABLE (
    verse_key        text,
    text_ar          text,
    translation_text text,
    similarity       float
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
AS $$
DECLARE
    ref_embedding vector(384);
BEGIN
    -- Get the embedding for the reference verse
    SELECT ve.embedding INTO ref_embedding
    FROM verse_embeddings ve
    WHERE ve.verse_key = input_verse_key
      AND ve.source_id = trans_source
    LIMIT 1;

    -- Fallback: try the other primary source if this one has no embedding
    IF ref_embedding IS NULL THEN
        SELECT ve.embedding INTO ref_embedding
        FROM verse_embeddings ve
        WHERE ve.verse_key = input_verse_key
        LIMIT 1;
    END IF;

    -- If still no embedding, return empty
    IF ref_embedding IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        v.verse_key,
        v.text_ar,
        t.text AS translation_text,
        (1 - (ve.embedding <=> ref_embedding))::float AS similarity
    FROM verse_embeddings ve
    JOIN verses v       ON v.verse_key = ve.verse_key
    LEFT JOIN translations t
              ON t.verse_key = ve.verse_key AND t.source_id = trans_source
    WHERE ve.source_id = trans_source
      AND ve.verse_key <> input_verse_key   -- exclude the input verse itself
      AND (1 - (ve.embedding <=> ref_embedding)) > 0.5
    ORDER BY ve.embedding <=> ref_embedding
    LIMIT result_limit;
END;
$$;

-- ============================================================
-- STEP 8: Ensure partial GIN expression indexes still exist
-- (These power the search_verses RPC for EN/ID text search)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_translations_id_gin
  ON translations USING gin(to_tsvector('simple', text))
  WHERE source_id LIKE 'id.%';

CREATE INDEX IF NOT EXISTS idx_translations_en_gin
  ON translations USING gin(to_tsvector('english', text))
  WHERE source_id LIKE 'en.%';

CREATE INDEX IF NOT EXISTS idx_tafsirs_id_gin
  ON tafsirs USING gin(to_tsvector('simple', text))
  WHERE source_id LIKE 'id.%';

CREATE INDEX IF NOT EXISTS idx_tafsirs_en_gin
  ON tafsirs USING gin(to_tsvector('english', text))
  WHERE source_id LIKE 'en.%';

-- ============================================================
-- STEP 9: VACUUM to reclaim freed disk space
-- ============================================================
VACUUM FULL public.translations;
VACUUM FULL public.tafsirs;
VACUUM FULL public.verse_embeddings;

-- ============================================================
-- STEP 10: Verify — show table sizes after cleanup
-- ============================================================
SELECT
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
  pg_size_pretty(pg_relation_size(oid))       AS data_size,
  pg_size_pretty(pg_indexes_size(oid))        AS index_size
FROM pg_class
WHERE relname IN (
  'surahs','verses','translations','tafsirs',
  'asbabun_nuzul','tags','verse_tags','verse_embeddings'
)
  AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC;
