-- ============================================================
-- Tafseer.id — Bookmarks Migration
-- Run in Supabase Dashboard → SQL Editor
-- ============================================================

create table if not exists public.bookmarks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  surah_id    int not null,
  ayah_number int not null,
  surah_name  text not null,
  verse_key   text not null,
  text_ar     text not null default '',
  translation text not null default '',
  created_at  timestamptz not null default now(),
  -- one bookmark per verse per user
  unique(user_id, verse_key)
);

alter table public.bookmarks enable row level security;

-- user can do anything with their own bookmarks
create policy "bookmarks: own all"
  on public.bookmarks for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- index for fast per-user queries
create index if not exists bookmarks_user_id_idx on public.bookmarks(user_id);
create index if not exists bookmarks_verse_key_idx on public.bookmarks(user_id, verse_key);
