-- ==============================================================
-- Tafseer.id — Database Cleanup & RLS Fix
-- Run this ENTIRE script in Supabase Dashboard → SQL Editor
-- ==============================================================
-- 
-- ROOT CAUSE OF 600MB SIZE:
-- 1. fts_simple + fts_english tsvector GIN indexes on translations & tafsirs 
--    → ~200-300 MB (now redundant since we use static JSON search index)
-- 2. embedding column in translations (12,472 × 1536 floats × 4 bytes = ~76 MB)
-- 3. Too many tafsir sources stored per verse (~12 sources × 6,236 verses = 76,053 rows)
-- 4. Too many translation sources stored per verse (~7 × 6,236 = 43,652 rows)
--
-- GOAL: Drop FTS columns, move embeddings to separate table, trim sources.
-- Expected size after: ~50-80 MB (down from ~600 MB)
-- ==============================================================

-- STEP 1: Disable Row Level Security (allows anon reads from the app)
-- ============================================================
ALTER TABLE public.surahs       DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.verses       DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.translations DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tafsirs      DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.asbabun_nuzul DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags         DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.verse_tags   DISABLE ROW LEVEL SECURITY;

-- STEP 2: Create verse_embeddings table (move embeddings out of translations)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.verse_embeddings (
  id         BIGSERIAL PRIMARY KEY,
  verse_key  TEXT NOT NULL,
  verse_id   BIGINT REFERENCES public.verses(id) ON DELETE CASCADE,
  source_id  TEXT NOT NULL,     -- e.g., 'en.sahih', 'id.kemenag'
  embedding  vector(1536),
  UNIQUE (verse_key, source_id)
);

-- Copy existing embeddings from translations into the new table
INSERT INTO public.verse_embeddings (verse_key, verse_id, source_id, embedding)
SELECT t.verse_key, t.verse_id, t.source_id, t.embedding
FROM   public.translations t
WHERE  t.embedding IS NOT NULL
ON CONFLICT (verse_key, source_id) DO NOTHING;

-- Create HNSW index for fast similarity search
CREATE INDEX IF NOT EXISTS verse_embeddings_embedding_idx
  ON public.verse_embeddings USING hnsw (embedding vector_cosine_ops);

-- Disable RLS on new table too
ALTER TABLE public.verse_embeddings DISABLE ROW LEVEL SECURITY;

-- STEP 3: Drop the bloated columns from translations
-- (FTS columns + embedding now moved to verse_embeddings)
-- ============================================================
-- Drop GIN indexes first to avoid errors
DROP INDEX IF EXISTS translations_fts_simple_idx;
DROP INDEX IF EXISTS translations_fts_english_idx;
DROP INDEX IF EXISTS idx_translations_fts_simple;
DROP INDEX IF EXISTS idx_translations_fts_english;

-- Drop the columns
ALTER TABLE public.translations
  DROP COLUMN IF EXISTS fts_simple,
  DROP COLUMN IF EXISTS fts_english,
  DROP COLUMN IF EXISTS embedding;

-- STEP 4: Drop FTS columns from tafsirs
-- ============================================================
DROP INDEX IF EXISTS tafsirs_fts_simple_idx;
DROP INDEX IF EXISTS tafsirs_fts_english_idx;
DROP INDEX IF EXISTS idx_tafsirs_fts_simple;
DROP INDEX IF EXISTS idx_tafsirs_fts_english;

ALTER TABLE public.tafsirs
  DROP COLUMN IF EXISTS fts_simple,
  DROP COLUMN IF EXISTS fts_english;

-- STEP 5: Keep only essential translations in Supabase
-- (en.sahih + id.kemenag for semantic search; others served from local JSON)
-- ============================================================
-- Keep: en.sahih, id.kemenag, en.transliteration, id.kemenag_translit
-- Delete everything else (it's available via local JSON files)
DELETE FROM public.translations
WHERE source_id NOT IN (
  'en.sahih',
  'id.kemenag',
  'en.transliteration',
  'id.kemenag_translit',
  'id.indonesian'   -- keep this as it's the main Indonesian source
);

-- STEP 6: Keep only essential tafsir sources in Supabase
-- (2-3 per language; rest served from local JSON files)
-- ============================================================
-- Keep: id.jalalayn, en.jalalayn (or maududi), ar.muyassar
-- Delete all others
DELETE FROM public.tafsirs
WHERE source_id NOT IN (
  'id.jalalayn',
  'id.muntakhab',    -- Quraish Shihab (popular Indonesian)
  'en.maududi',
  'ar.muyassar'
);

-- STEP 7: Vacuum to reclaim disk space
-- ============================================================
VACUUM FULL public.translations;
VACUUM FULL public.tafsirs;
VACUUM FULL public.verse_embeddings;

-- STEP 8: Verify the cleanup
-- ============================================================
SELECT
  relname AS table_name,
  pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
  pg_size_pretty(pg_relation_size(oid)) AS data_size,
  pg_size_pretty(pg_indexes_size(oid)) AS index_size
FROM pg_class
WHERE relname IN ('surahs','verses','translations','tafsirs','asbabun_nuzul',
                  'tags','verse_tags','verse_embeddings')
  AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC;
