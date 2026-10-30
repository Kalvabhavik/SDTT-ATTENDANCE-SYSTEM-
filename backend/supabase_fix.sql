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

-- 7. Add missing columns to attendance table (1-attempt policy & idempotency tracking)
alter table public.attendance add column if not exists attempted boolean not null default false;
alter table public.attendance add column if not exists attempt_timestamp timestamptz;
alter table public.attendance add column if not exists idempotency_key text;

-- 8. Enable Row Level Security (RLS) on face_templates
alter table public.face_templates enable row level security;

-- 9. Set RLS policies for face_templates
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

-- 10. Secure trigger for public user signup (strictly enforce 'student' role, disallow self-elevation)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    'student' -- Server-enforced: New self-registered accounts are strictly 'student'. Privileged roles must be authorized.
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- 11. Controller RLS Policies
drop policy if exists "profiles_controller_read_all" on public.profiles;
create policy "profiles_controller_read_all" on public.profiles
  for select using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('controller', 'admin'))
  );

drop policy if exists "classes_controller_all" on public.classes;
create policy "classes_controller_all" on public.classes
  for all using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('controller', 'admin'))
  );

drop policy if exists "enrollments_controller_all" on public.enrollments;
create policy "enrollments_controller_all" on public.enrollments
  for all using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('controller', 'admin'))
  );

drop policy if exists "sessions_controller_read_all" on public.sessions;
create policy "sessions_controller_read_all" on public.sessions
  for select using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('controller', 'admin'))
  );

drop policy if exists "audit_controller_read_all" on public.audit_log;
create policy "audit_controller_read_all" on public.audit_log
  for select using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('controller', 'admin'))
  );

-- 12. Create timetable table if not exists & performance indexes
create table if not exists public.timetable (
  id            uuid primary key default gen_random_uuid(),
  class_id      uuid not null references public.classes(id) on delete cascade,
  day_of_week   integer not null check (day_of_week between 0 and 6),
  day_name      text not null,
  start_time    text not null,
  end_time      text not null,
  room_number   text not null default 'LH-120',
  is_cancelled  boolean not null default false,
  academic_year text not null default '2026-2027',
  semester      text not null default 'Fall 2026',
  created_at    timestamptz not null default now()
);

alter table public.timetable enable row level security;
create policy "timetable_read_all" on public.timetable for select using (true);

create index if not exists idx_attendance_session    on public.attendance(session_id);
create index if not exists idx_sessions_class        on public.sessions(class_id);
create index if not exists idx_sessions_status       on public.sessions(status);
create index if not exists idx_classes_teacher       on public.classes(teacher_id);
create index if not exists idx_profiles_roll         on public.profiles(roll_number);
create index if not exists idx_profiles_role         on public.profiles(role);
create index if not exists idx_audit_actor           on public.audit_log(actor_id);
create index if not exists idx_audit_timestamp       on public.audit_log(timestamp desc);
create index if not exists idx_timetable_class       on public.timetable(class_id, day_of_week);

-- 13. Allow NULL session_id in audit_log to support controller/system administrative events (creating classes, enrolling students, etc.)
alter table public.audit_log alter column session_id drop not null;

-- 14. Reload schema cache for PostgREST API
notify pgrst, 'reload schema';

