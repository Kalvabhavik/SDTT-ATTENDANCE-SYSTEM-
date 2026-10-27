-- ============================================================
-- Attendrix / SDTT Attendance System — Complete Database Fix Script
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

-- 2. Add missing columns to profiles table
alter table public.profiles add column if not exists roll_number text;
alter table public.profiles add column if not exists student_id text;
alter table public.profiles add column if not exists registration_locked boolean not null default false;

-- 3. Update profiles role check constraint to support controller and admin roles
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('teacher', 'student', 'controller', 'admin'));

-- 4. Add missing columns to sessions table (time limits and venue photo)
alter table public.sessions add column if not exists starts_at timestamptz;
alter table public.sessions add column if not exists ends_at timestamptz;
alter table public.sessions add column if not exists duration_minutes integer not null default 10;
alter table public.sessions add column if not exists room_photo text;

-- Update sessions status check constraint to include 'closed'
alter table public.sessions drop constraint if exists sessions_status_check;
alter table public.sessions add constraint sessions_status_check check (status in ('open', 'closed', 'finalized'));

-- 5. Add missing columns to classes table (section, venue and capacity)
alter table public.classes add column if not exists section text default 'Section A';
alter table public.classes add column if not exists room_number text default 'LH-120';
alter table public.classes add column if not exists capacity integer default 120;
alter table public.classes add column if not exists hall_type text default '120-Seater Lecture Theater';
alter table public.classes add column if not exists room_photo text;

-- 6. Add missing columns to checkin_attempts table (sweep metrics and filmstrips)
alter table public.checkin_attempts add column if not exists metrics_json text;
alter table public.checkin_attempts add column if not exists filmstrip_paths text[];

alter table public.checkin_attempts drop constraint if exists checkin_attempts_state_check;
alter table public.checkin_attempts add constraint checkin_attempts_state_check
  check (state in ('evaluating', 'verified', 'flagged', 'rejected', 'error'));

-- 7. Enable Row Level Security (RLS) on face_templates
alter table public.face_templates enable row level security;

-- 8. Set RLS policies for face_templates
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

-- 9. Reload schema cache for PostgREST API
notify pgrst, 'reload schema';
