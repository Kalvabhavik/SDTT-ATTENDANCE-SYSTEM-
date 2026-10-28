-- ============================================================
--  Classroom Attendance – Supabase Database Schema
--  Run this in: Supabase Dashboard → SQL Editor → New query
--
--  This script:
--    1. Enables UUID extension
--    2. Creates all tables (using UUIDs for PKs)
--    3. Links profiles to Supabase Auth users
--    4. Sets Row-Level Security (RLS) policies
--    5. Seeds demo data (optional – comment out for production)
-- ============================================================

-- 1. Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- 2. Tables ───────────────────────────────────────────────────

-- profiles: mirrors auth.users and stores role + display name
create table if not exists public.profiles (
  id       uuid primary key references auth.users(id) on delete cascade,
  name     text        not null,
  email    text        not null unique,
  role     text        not null check (role in ('teacher', 'student')),
  created_at timestamptz not null default now()
);

-- classes
create table if not exists public.classes (
  id         uuid primary key default uuid_generate_v4(),
  name       text not null,
  code       text not null unique,
  teacher_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

-- enrollments
create table if not exists public.enrollments (
  class_id   uuid not null references public.classes(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  roll_number integer check (roll_number is null or roll_number > 0),
  primary key (class_id, student_id)
);
create unique index if not exists uq_enrollments_class_roll on public.enrollments(class_id, roll_number) where roll_number is not null;

-- sessions
create table if not exists public.sessions (
  id           uuid primary key default uuid_generate_v4(),
  class_id     uuid not null references public.classes(id),
  status       text not null check (status in ('open', 'finalized')) default 'open',
  created_by   uuid not null references public.profiles(id),
  created_at   timestamptz not null default now(),
  finalized_at timestamptz
);

-- attendance
create table if not exists public.attendance (
  id         uuid primary key default uuid_generate_v4(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id),
  roll_number integer check (roll_number is null or roll_number > 0),
  status     text not null check (status in ('pending', 'present', 'absent')) default 'pending',
  note       text,
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now(),
  unique (session_id, student_id)
);

-- checkin_attempts
create table if not exists public.checkin_attempts (
  id         uuid primary key default uuid_generate_v4(),
  attempt_id text not null unique,
  session_id uuid not null references public.sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  state      text not null check (state in ('evaluating', 'verified', 'flagged', 'rejected', 'error')),
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- suggestions
create table if not exists public.suggestions (
  id         uuid primary key default uuid_generate_v4(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  student_id uuid not null references public.profiles(id),
  confidence real not null,
  label      text not null,
  created_at timestamptz not null default now()
);

-- audit_log
create table if not exists public.audit_log (
  id            uuid primary key default uuid_generate_v4(),
  session_id    uuid not null references public.sessions(id) on delete cascade,
  action        text not null,
  actor_id      uuid not null references public.profiles(id),
  timestamp     timestamptz not null default now(),
  note          text,
  metadata_json text
);

-- notifications
create table if not exists public.notifications (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text not null,
  session_id uuid references public.sessions(id) on delete set null,
  created_at timestamptz not null default now(),
  read_at    timestamptz
);

-- Safe upgrade for databases created before the live roll-number grid.
alter table public.enrollments add column if not exists roll_number integer;
alter table public.attendance add column if not exists roll_number integer;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'enrollments_roll_number_positive') then
    alter table public.enrollments add constraint enrollments_roll_number_positive
      check (roll_number is null or roll_number > 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'attendance_roll_number_positive') then
    alter table public.attendance add constraint attendance_roll_number_positive
      check (roll_number is null or roll_number > 0);
  end if;
end $$;

-- 3. Indexes ──────────────────────────────────────────────────
create index if not exists idx_classes_teacher_created on public.classes(teacher_id, created_at desc);
create index if not exists idx_enrollments_student_class on public.enrollments(student_id, class_id);
create index if not exists idx_enrollments_class_roll on public.enrollments(class_id, roll_number);
create index if not exists idx_sessions_class_created on public.sessions(class_id, created_at desc);
create index if not exists idx_attendance_student    on public.attendance(student_id);
create index if not exists idx_attendance_session_status on public.attendance(session_id, status);
create index if not exists idx_checkin_session       on public.checkin_attempts(session_id);
create index if not exists idx_checkin_student       on public.checkin_attempts(student_id);
create index if not exists idx_suggestions_session_created on public.suggestions(session_id, created_at desc);
create index if not exists idx_audit_session         on public.audit_log(session_id);
create index if not exists idx_audit_session_timestamp on public.audit_log(session_id, timestamp desc);
create index if not exists idx_notifications_user    on public.notifications(user_id, created_at desc);

-- 4. Trigger: auto-create profile on Supabase Auth signup ─────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'role', 'student')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Row-Level Security ───────────────────────────────────────
alter table public.profiles       enable row level security;
alter table public.classes         enable row level security;
alter table public.enrollments     enable row level security;
alter table public.sessions        enable row level security;
alter table public.attendance      enable row level security;
alter table public.suggestions     enable row level security;
alter table public.audit_log       enable row level security;
alter table public.notifications   enable row level security;
alter table public.checkin_attempts enable row level security;

-- profiles: users can read their own; service role sees all
create policy "profiles_read_own" on public.profiles
  for select using (auth.uid() = id);

-- classes: teacher sees their own; enrolled students see their classes
create policy "classes_teacher_own" on public.classes
  for all using (auth.uid() = teacher_id);

create policy "classes_student_enrolled" on public.classes
  for select using (
    exists (
      select 1 from public.enrollments e
      where e.class_id = public.classes.id and e.student_id = auth.uid()
    )
  );

-- enrollments: teacher sees enrollments in their classes; students see their own
create policy "enrollments_teacher" on public.enrollments
  for select using (
    exists (select 1 from public.classes c where c.id = public.enrollments.class_id and c.teacher_id = auth.uid())
  );

create policy "enrollments_student_own" on public.enrollments
  for select using (student_id = auth.uid());

-- sessions: teacher sees own; students see sessions in enrolled classes
create policy "sessions_teacher" on public.sessions
  for all using (
    exists (select 1 from public.classes c where c.id = public.sessions.class_id and c.teacher_id = auth.uid())
  );

create policy "sessions_student" on public.sessions
  for select using (
    exists (
      select 1 from public.enrollments e where e.class_id = public.sessions.class_id and e.student_id = auth.uid()
    )
  );

-- attendance: teacher manages; student reads own
create policy "attendance_teacher" on public.attendance
  for all using (
    exists (
      select 1 from public.sessions s
      join public.classes c on c.id = s.class_id
      where s.id = public.attendance.session_id and c.teacher_id = auth.uid()
    )
  );

create policy "attendance_student_own" on public.attendance
  for select using (student_id = auth.uid());

-- notifications: users read/update their own
create policy "notifications_own" on public.notifications
  for all using (user_id = auth.uid());

-- audit_log: teacher reads their session audits
create policy "audit_teacher" on public.audit_log
  for select using (
    exists (
      select 1 from public.sessions s
      join public.classes c on c.id = s.class_id
      where s.id = public.audit_log.session_id and c.teacher_id = auth.uid()
    )
  );

-- suggestions: teacher reads for their sessions
create policy "suggestions_teacher" on public.suggestions
  for select using (
    exists (
      select 1 from public.sessions s
      join public.classes c on c.id = s.class_id
      where s.id = public.suggestions.session_id and c.teacher_id = auth.uid()
    )
  );

-- ============================================================
--  DEMO SEED DATA  (comment out or delete for production)
--
--  IMPORTANT: You must first create these users through
--  Supabase Auth (Dashboard → Authentication → Users → Add user)
--  and paste their UUIDs below before running this block.
--
--  Or use the Supabase Admin API / supabase CLI to create them.
-- ============================================================

-- After creating users via Supabase Auth, their profiles are
-- auto-created by the trigger above. Update roles with:
--
--   update public.profiles set role = 'teacher' where email = 'teacher@demo.edu';
--   update public.profiles set role = 'student' where email = 'student1@demo.edu';
--   update public.profiles set role = 'student' where email = 'student2@demo.edu';
--
-- Then enroll students:
--
--   insert into public.enrollments (class_id, student_id)
--   select
--     c.id,
--     p.id
--   from public.classes c, public.profiles p
--   where c.code = 'CS-101'
--   and p.email in ('student1@demo.edu', 'student2@demo.edu');
