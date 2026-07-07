-- ============================================================
-- Tafseer.id — Auth Migration
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. PROFILES table (one row per user, auto-created on signup)
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  avatar_url    text,
  role          text not null default 'user', -- 'user' | 'admin'
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: public read"
  on public.profiles for select using (true);

create policy "profiles: own update"
  on public.profiles for update using (auth.uid() = id);

-- 2. USER_PREFERENCES table (synced settings per user)
create table if not exists public.user_preferences (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid references auth.users(id) on delete cascade unique not null,
  app_language                text not null default 'id',
  default_translation_source  text not null default 'id.kemenag',
  arabic_font_size            float not null default 32,
  translation_font_size       float not null default 14,
  show_transliteration        boolean not null default true,
  selected_reciter            text not null default 'Alafasy_128kbps',
  updated_at                  timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

create policy "prefs: own all"
  on public.user_preferences for all using (auth.uid() = user_id);

-- 3. TRIGGER: auto-create profile on new user signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 4. DESIGNATE YOURSELF AS ADMIN
-- After signing up, run this with your email:
-- update public.profiles set role = 'admin'
-- where id = (select id from auth.users where email = 'your@email.com');
