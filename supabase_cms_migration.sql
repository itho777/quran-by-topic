-- ============================================================
-- CMS & Featured Ayah Migration
-- Run this in Supabase Dashboard → SQL Editor
-- Append to supabase_migration.sql or run separately
-- ============================================================

-- 1. SITE_CONFIG — key/value store for all CMS-editable content
create table if not exists public.site_config (
  key         text primary key,
  value       text not null,
  updated_at  timestamptz not null default now()
);

-- Seed defaults
insert into public.site_config (key, value) values
  ('home_hero_title',    'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'),
  ('home_hero_subtitle', 'In the name of Allah, the Most Gracious, the Most Merciful'),
  ('home_tagline',       'Quran by Topic — Read, Study, and Reflect'),
  ('featured_ayah_key',  '2:255'),   -- verse_key format  sura:ayah
  ('featured_ayah_note', 'Ayat Kursi — The Throne Verse')
on conflict (key) do nothing;

-- RLS
alter table public.site_config enable row level security;

create policy "site_config: public read"
  on public.site_config for select using (true);

create policy "site_config: admin write"
  on public.site_config for all using (
    exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    )
  );

-- 2. Also ensure translations, tafsirs, asbabun_nuzul have admin-write policies
-- (In case they are still read-only from original migration)

-- For translations table
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'translations' and policyname = 'translations: admin write'
  ) then
    create policy "translations: admin write"
      on public.translations for update using (
        exists (
          select 1 from public.profiles
          where id = auth.uid() and role = 'admin'
        )
      );
  end if;
end $$;

-- For tafsirs table
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'tafsirs' and policyname = 'tafsirs: admin write'
  ) then
    create policy "tafsirs: admin write"
      on public.tafsirs for update using (
        exists (
          select 1 from public.profiles
          where id = auth.uid() and role = 'admin'
        )
      );
  end if;
end $$;

-- For asbabun_nuzul table
do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'asbabun_nuzul' and policyname = 'asbabun_nuzul: admin write'
  ) then
    create policy "asbabun_nuzul: admin write"
      on public.asbabun_nuzul for update using (
        exists (
          select 1 from public.profiles
          where id = auth.uid() and role = 'admin'
        )
      );
  end if;
end $$;
