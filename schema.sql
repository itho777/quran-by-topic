-- Supabase SQL Schema for Quran by Topic (tafsir-upgrade)

-- Enable pgvector for semantic search (optional but commented out due to instance availability)
-- create extension if not exists "pgvector";

-- 1. SURAHS TABLE
create table if not exists surahs (
    id integer primary key,
    name_ar text not null,
    name_en text not null,
    name_id text not null,
    meaning text not null,
    meaning_id text not null,
    ayas integer not null,
    type text not null
);

-- 2. VERSES TABLE
create table if not exists verses (
    id serial primary key,
    sura_id integer not null references surahs(id) on delete cascade,
    ayah_number integer not null,
    verse_key text not null unique, -- e.g. "1:1"
    text_ar text not null,
    page_number integer, -- for Mushaf page matching (1-604)
    juz_number integer,  -- for Juz navigation (1-30)
    constraint unique_sura_ayah unique (sura_id, ayah_number)
);

-- Indexes for fast lookup
create index if not exists idx_verses_key on verses(verse_key);
create index if not exists idx_verses_page on verses(page_number);

-- 3. TRANSLATIONS TABLE
create table if not exists translations (
    id serial primary key,
    verse_id integer not null references verses(id) on delete cascade,
    verse_key text not null,
    source_id text not null, -- e.g. "id.kemenag", "en.sahih"
    text text not null
);

create unique index if not exists unique_translation_source_verse on translations(source_id, verse_id);
create index if not exists idx_translations_search on translations(source_id, verse_key);
-- GIN Index for fast full-text search on translation texts
create index if not exists idx_translations_text_gin on translations using gin(to_tsvector('english', text));

-- 4. TAFSIRS TABLE
create table if not exists tafsirs (
    id serial primary key,
    verse_id integer not null references verses(id) on delete cascade,
    verse_key text not null,
    source_id text not null, -- e.g. "id.jalalayn", "en.katsir"
    text text not null
);

create unique index if not exists unique_tafsir_source_verse on tafsirs(source_id, verse_id);
create index if not exists idx_tafsirs_search on tafsirs(source_id, verse_key);

-- 5. ASBABUN NUZUL TABLE
create table if not exists asbabun_nuzul (
    id serial primary key,
    verse_id integer not null references verses(id) on delete cascade,
    verse_key text not null,
    source_id text not null, -- e.g. "en.wahidi", "id.kemenag_nuzul"
    text text not null
);

create unique index if not exists unique_nuzul_source_verse on asbabun_nuzul(source_id, verse_id);
create index if not exists idx_nuzul_search on asbabun_nuzul(source_id, verse_key);

-- 6. TAGS / TOPICS TABLES
create table if not exists tags (
    id integer not null,             -- numeric tag ID from source files
    name text not null,
    lang text not null default 'id', -- 'id' or 'en'
    primary key (id, lang)           -- composite PK: same ID exists in both langs
);

create table if not exists verse_tags (
    id serial primary key,
    verse_id integer not null references verses(id) on delete cascade,
    verse_key text not null,
    tag_id integer not null,
    tag_lang text not null default 'id',
    lang text not null default 'id',
    foreign key (tag_id, tag_lang) references tags(id, lang) on delete cascade
);

create unique index if not exists unique_verse_tag on verse_tags(verse_id, tag_id, lang);
create index if not exists idx_verse_tags_tag on verse_tags(tag_id);
create index if not exists idx_verse_tags_key on verse_tags(verse_key);


-- =========================================================================
-- DATABASE FUNCTIONS & RPCs
-- =========================================================================

-- Exact Word Search Function
-- Searches for an exact word in translations (handling boundaries)
-- E.g. searching 'air' matches 'air' but not 'affairs' or 'hurairah'
create or replace function search_exact_word(
    search_query text,
    lang_code text default 'en',
    limit_val integer default 50,
    offset_val integer default 0
)
returns table (
    verse_key text,
    text_ar text,
    translation_text text,
    translation_source text
) 
language plpgsql
security definer
as $$
begin
    return query
    select 
        v.verse_key,
        v.text_ar,
        t.text as translation_text,
        t.source_id as translation_source
    from translations t
    join verses v on v.id = t.verse_id
    where 
        -- Uses regex word boundary marker (\y in Postgres) for exact matching
        -- Case insensitive matching (~*)
        t.text ~* ('\y' || search_query || '\y')
        and (
            (lang_code = 'id' and t.source_id like 'id.%') or
            (lang_code = 'en' and t.source_id like 'en.%')
        )
    order by v.sura_id asc, v.ayah_number asc
    limit limit_val
    offset offset_val;
end;
$$;


-- Topic Tag Excerpt Finder
-- Retrieves verses mapped to a specific tag along with the active translation
create or replace function get_verses_by_tag(
    target_tag_id text,
    trans_source_id text,
    limit_val integer default 50,
    offset_val integer default 0
)
returns table (
    verse_key text,
    text_ar text,
    translation_text text
)
language plpgsql
security definer
as $$
begin
    return query
    select 
        v.verse_key,
        v.text_ar,
        t.text as translation_text
    from verse_tags vt
    join verses v on v.id = vt.verse_id
    left join translations t on t.verse_id = v.id and t.source_id = trans_source_id
    where vt.tag_id = target_tag_id
    order by v.sura_id asc, v.ayah_number asc
    limit limit_val
    offset offset_val;
end;
$$;
