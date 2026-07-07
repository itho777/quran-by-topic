-- ============================================================
-- CMS Extensions: Featured Playlist & Auto-Rotation Setup
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. FEATURED_PLAYLIST table (curated playlist of verses to cycle through)
create table if not exists public.featured_playlist (
  id          serial primary key,
  verse_key   text not null unique, -- format: 'sura:ayah' (e.g. '2:255')
  note        text,
  added_at    timestamptz not null default now()
);

-- Seed initial playlist with a few famous ayahs
insert into public.featured_playlist (verse_key, note) values
  ('2:255', 'Ayat Kursi (Throne Verse)'),
  ('1:1', 'Al-Fatihah 1 — Bismillah'),
  ('112:1', 'Al-Ikhlas 1 — Sincerity'),
  ('2:286', 'Al-Baqarah 286 — Prayer for Relief'),
  ('3:190', 'Ali Imran 190 — Reflection on Creation')
on conflict (verse_key) do nothing;

-- RLS policies
alter table public.featured_playlist enable row level security;

create policy "playlist: public read"
  on public.featured_playlist for select using (true);

create policy "playlist: admin write"
  on public.featured_playlist for all using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- 2. Add rotation mode seed to site_config
insert into public.site_config (key, value) values
  ('featured_rotation_mode', 'manual') -- 'manual' | 'daily_random' | 'daily_playlist'
on conflict (key) do nothing;
