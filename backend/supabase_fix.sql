-- ============================================================
-- Attendrix / SDTT Attendance System — Database Fix Script
-- Run this in your Supabase Dashboard:
-- 1. Open https://supabase.com/dashboard/project/weldmwxlhhhwsedkozli
-- 2. Go to "SQL Editor" -> "New Query"
-- 3. Paste this script and click "Run" (Ctrl+Enter)
-- ============================================================

-- 1. Create face_templates table if not exists (Stores encrypted facial embeddings)
create table if not exists public.face_templates (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references public.profiles(id) on delete cascade unique,
  encrypted_embedding text not null,
  model_version       text not null,
  consent_timestamp   timestamptz not null default now(),
  created_at          timestamptz not null default now()
);

-- 2. Add missing columns to profiles table if they don't already exist
alter table public.profiles add column if not exists roll_number text;
alter table public.profiles add column if not exists student_id text;
alter table public.profiles add column if not exists registration_locked boolean not null default false;

-- 3. Update profiles role check constraint to support controller and admin roles
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('teacher', 'student', 'controller', 'admin'));

-- 4. Enable Row Level Security (RLS) on face_templates
alter table public.face_templates enable row level security;

-- 5. Set RLS policies for face_templates
drop policy if exists "face_templates_read_own" on public.face_templates;
create policy "face_templates_read_own" on public.face_templates
  for select using (auth.uid() = user_id);

drop policy if exists "face_templates_insert_own" on public.face_templates;
create policy "face_templates_insert_own" on public.face_templates
  for insert with check (auth.uid() = user_id);

drop policy if exists "face_templates_update_own" on public.face_templates;
create policy "face_templates_update_own" on public.face_templates
  for update using (auth.uid() = user_id);

drop policy if exists "face_templates_delete_own" on public.face_templates;
create policy "face_templates_delete_own" on public.face_templates
  for delete using (auth.uid() = user_id);

-- 6. Reload schema cache for PostgREST API
notify pgrst, 'reload schema';
