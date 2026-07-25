-- ==============================================================
-- Tafseer.id — Redefine search_verses with correct 'p_' parameters
-- Run this ENTIRE script in Supabase Dashboard → SQL Editor
-- ==============================================================

-- 1. Drop existing overloaded search_verses functions to prevent confusion
DROP FUNCTION IF EXISTS public.search_verses(text, text, integer, integer);
DROP FUNCTION IF EXISTS public.search_verses(query text, lang_code text, result_limit integer, offset_val integer);
DROP FUNCTION IF EXISTS public.search_verses(p_query text, p_lang_code text, p_result_limit integer, p_offset_val integer);

-- 2. Create the unified search_verses function matching the exact parameters from client apps
CREATE OR REPLACE FUNCTION public.search_verses(
    p_query        text,
    p_lang_code    text    DEFAULT 'id',
    p_result_limit integer DEFAULT 30,
    p_offset_val   integer DEFAULT 0
)
RETURNS TABLE (
    verse_key        text,
    text_ar          text,
    translation_text text,
    match_score      integer,
    matched_tags     text[],
    match_note       text,
    context_snippet  text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    query_words   text[];
    num_words     integer;
    target_source text;
BEGIN
    query_words := regexp_split_to_array(lower(trim(p_query)), '\s+');
    num_words   := array_length(query_words, 1);
    IF num_words IS NULL OR num_words = 0 THEN RETURN; END IF;

    -- Display translation language
    target_source := CASE WHEN p_lang_code = 'id' THEN 'id.kemenag' ELSE 'en.sahih' END;

    RETURN QUERY
    WITH

    -- Step 1: SEPARATE GIN scans for each source language.
    --         Each branch hits a tiny partial index (~6k rows) instead
    --         of scanning all 698k rows.
    matched_translations AS (
        -- Indonesian translations (simple config, partial index)
        SELECT verse_id, 4 AS score, 'Translation'::text AS note
        FROM translations
        WHERE source_id LIKE 'id.%'
          AND to_tsvector('simple', text) @@ plainto_tsquery('simple', p_query)

        UNION ALL

        -- English translations (english config, partial index)
        SELECT verse_id, 4 AS score, 'Translation'::text AS note
        FROM translations
        WHERE source_id LIKE 'en.%'
          AND to_tsvector('english', text) @@ plainto_tsquery('english', p_query)
    ),

    matched_tafsirs AS (
        SELECT verse_id, 2 AS score, 'Tafsir'::text AS note
        FROM tafsirs
        WHERE source_id LIKE 'id.%'
          AND to_tsvector('simple', text) @@ plainto_tsquery('simple', p_query)

        UNION ALL

        SELECT verse_id, 2 AS score, 'Tafsir'::text AS note
        FROM tafsirs
        WHERE source_id LIKE 'en.%'
          AND to_tsvector('english', text) @@ plainto_tsquery('english', p_query)
    ),

    matched_nuzul AS (
        SELECT verse_id, 2 AS score, 'Asbabun Nuzul'::text AS note
        FROM asbabun_nuzul
        WHERE source_id LIKE 'id.%'
          AND to_tsvector('simple', text) @@ plainto_tsquery('simple', p_query)

        UNION ALL

        SELECT verse_id, 2 AS score, 'Asbabun Nuzul'::text AS note
        FROM asbabun_nuzul
        WHERE source_id LIKE 'en.%'
          AND to_tsvector('english', text) @@ plainto_tsquery('english', p_query)
    ),

    -- Arabic text: ILIKE scan over 6,236 rows (fast, no index needed)
    matched_arabic AS (
        SELECT ar_v.id AS verse_id, 5 AS score, 'Arabic'::text AS note
        FROM verses ar_v
        WHERE ar_v.text_ar ILIKE '%' || p_query || '%'
    ),

    -- Tags: ILIKE scan over 3,904 tags (fast)
    matched_tags AS (
        SELECT vt.verse_id, 3 AS score, 'Tag'::text AS note
        FROM verse_tags vt
        JOIN tags tg ON tg.id = vt.tag_id
        WHERE tg.name ILIKE '%' || p_query || '%'
    ),

    all_matches AS (
        SELECT verse_id, score, note FROM matched_translations
        UNION ALL
        SELECT verse_id, score, note FROM matched_tafsirs
        UNION ALL
        SELECT verse_id, score, note FROM matched_nuzul
        UNION ALL
        SELECT verse_id, score, note FROM matched_arabic
        UNION ALL
        SELECT verse_id, score, note FROM matched_tags
    ),

    -- Step 2: Group and de-duplicate by verse, take highest score
    best_matches AS (
        SELECT
            am.verse_id,
            max(am.score) AS match_score,
            min(am.note)  AS match_note
        FROM all_matches am
        GROUP BY am.verse_id
    ),

    -- Step 3: Sort + paginate using Late Row Lookup
    ordered_ids AS (
        SELECT
            bm.verse_id,
            v.verse_key,
            v.text_ar,
            v.sura_id,
            v.ayah_number,
            t.text AS translation_text,
            bm.match_score,
            bm.match_note
        FROM best_matches bm
        JOIN verses v ON v.id = bm.verse_id
        LEFT JOIN translations t 
               ON t.verse_id = bm.verse_id AND t.source_id = target_source
        ORDER BY 
            bm.match_score DESC,
            v.sura_id ASC,
            v.ayah_number ASC
        LIMIT p_result_limit
        OFFSET p_offset_val
    )
    SELECT
        o.verse_key,
        o.text_ar,
        o.translation_text,
        o.match_score,
        (
            SELECT array_agg(tg.name)
            FROM verse_tags vt
            JOIN tags tg ON tg.id = vt.tag_id
            WHERE vt.verse_id = o.verse_id
              AND EXISTS (
                  SELECT 1 FROM unnest(query_words) w(word)
                  WHERE tg.name ILIKE '%' || w.word || '%'
              )
        ) AS matched_tags,
        o.match_note,
        (
            SELECT json_agg(item)::text
            FROM (
                SELECT json_build_object(
                    'source_name', CASE tr2.source_id
                        WHEN 'id.kemenag'   THEN 'Kemenag RI'
                        WHEN 'en.sahih'     THEN 'Sahih International'
                        WHEN 'en.hilali'    THEN 'Hilali & Khan'
                        WHEN 'en.pickthall' THEN 'Pickthall'
                        ELSE tr2.source_id
                    END,
                    'source_type', 'Translation',
                    'source_id', tr2.source_id,
                    'text', (
                        SELECT substring(tr2.text FROM greatest(1,
                            min(strpos(lower(tr2.text), w.word)) - 120) FOR 300)
                        FROM unnest(query_words) w(word)
                        WHERE strpos(lower(tr2.text), w.word) > 0
                    )
                ) AS item
                FROM translations tr2
                WHERE tr2.verse_id = o.verse_id
                  AND EXISTS (SELECT 1 FROM unnest(query_words) w(word)
                              WHERE tr2.text ILIKE '%' || w.word || '%')
                UNION ALL
                SELECT json_build_object(
                    'source_name', CASE tf2.source_id
                        WHEN 'id.jalalayn' THEN 'Tafsir Jalalayn (ID)'
                        WHEN 'id.kemenag'  THEN 'Tafsir Kemenag (ID)'
                        WHEN 'en.katsir'   THEN 'Tafsir Ibn Kathir (EN)'
                        ELSE tf2.source_id
                    END,
                    'source_type', 'Tafsir',
                    'source_id', tf2.source_id,
                    'text', (
                        SELECT substring(tf2.text FROM greatest(1,
                            min(strpos(lower(tf2.text), w.word)) - 120) FOR 300)
                        FROM unnest(query_words) w(word)
                        WHERE strpos(lower(tf2.text), w.word) > 0
                    )
                ) AS item
                FROM tafsirs tf2
                WHERE tf2.verse_id = o.verse_id
                  AND EXISTS (SELECT 1 FROM unnest(query_words) w(word)
                              WHERE tf2.text ILIKE '%' || w.word || '%')
                UNION ALL
                SELECT json_build_object(
                    'source_name', CASE an2.source_id
                        WHEN 'id.kemenag_nuzul' THEN 'Asbabun Nuzul Kemenag RI (ID)'
                        WHEN 'en.wahidi'        THEN 'Asbabun Nuzul (al-Wahidi)'
                        ELSE an2.source_id
                    END,
                    'source_type', 'Asbabun Nuzul',
                    'source_id', an2.source_id,
                    'text', (
                        SELECT substring(an2.text FROM greatest(1,
                            min(strpos(lower(an2.text), w.word)) - 120) FOR 300)
                        FROM unnest(query_words) w(word)
                        WHERE strpos(lower(an2.text), w.word) > 0
                    )
                ) AS item
                FROM asbabun_nuzul an2
                WHERE an2.verse_id = o.verse_id
                  AND EXISTS (SELECT 1 FROM unnest(query_words) w(word)
                              WHERE an2.text ILIKE '%' || w.word || '%')
            ) snippets
        ) AS context_snippet
    FROM ordered_ids o
    ORDER BY o.match_score DESC, o.sura_id ASC, o.ayah_number ASC;
END;
$$;
