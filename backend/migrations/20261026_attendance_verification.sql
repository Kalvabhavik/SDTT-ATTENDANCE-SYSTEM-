-- Supabase/Postgres migration for timed sessions and real submissions.
-- Run through the migration pipeline; never apply ad-hoc edits in the dashboard.

alter table public.sessions
  drop constraint if exists sessions_status_check;
alter table public.sessions
  add constraint sessions_status_check check (status in ('open', 'closed', 'finalized'));
alter table public.sessions
  add column if not exists starts_at timestamptz,
  add column if not exists ends_at timestamptz,
  add column if not exists duration_minutes integer,
  add column if not exists closed_at timestamptz;
alter table public.sessions
  drop constraint if exists sessions_duration_minutes_check;
alter table public.sessions
  add constraint sessions_duration_minutes_check
  check (duration_minutes is null or duration_minutes between 1 and 240);
create index if not exists idx_sessions_open_end on public.sessions(ends_at) where status = 'open';

alter table public.checkin_attempts
  add column if not exists reason_code text,
  add column if not exists rules_json jsonb not null default '{}'::jsonb,
  add column if not exists metrics_json jsonb not null default '{}'::jsonb,
  add column if not exists model_version text,
  add column if not exists received_at timestamptz not null default now();
create unique index if not exists uq_one_verified_checkin_per_student_session
  on public.checkin_attempts(session_id, student_id) where state = 'verified';

create table if not exists public.face_templates (
  student_id uuid primary key references public.profiles(id) on delete cascade,
  encrypted_embedding text not null,
  model_version text not null,
  consent_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.face_templates enable row level security;
-- No client policy is intentional: only the backend service-role can read templates.

create table if not exists public.submission_evidence (
  id uuid primary key default uuid_generate_v4(),
  attempt_id text not null references public.checkin_attempts(attempt_id) on delete cascade,
  storage_path text not null,
  frame_offset_ms integer not null,
  heading_degrees real,
  created_at timestamptz not null default now(),
  unique (attempt_id, storage_path)
);
alter table public.submission_evidence enable row level security;
-- No client policy is intentional; signed URLs are issued after lecturer authorization.

create index if not exists idx_checkin_attempt_session_student
  on public.checkin_attempts(session_id, student_id, created_at desc);
create index if not exists idx_evidence_attempt on public.submission_evidence(attempt_id);

alter table public.checkin_attempts
  add column if not exists review_decision text,
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_note text;
alter table public.checkin_attempts
  drop constraint if exists checkin_review_decision_check;
alter table public.checkin_attempts
  add constraint checkin_review_decision_check
  check (review_decision is null or review_decision in ('accepted', 'rejected'));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attendance-evidence', 'attendance-evidence', false, 20971520, array['image/jpeg', 'image/png'])
on conflict (id) do update set public = false;

-- Called only with the service-role client. Locking serializes a student's
-- concurrent submissions so the attempt limit is enforced by Postgres.
create or replace function public.begin_checkin_attempt(p_attempt_id text, p_session_id uuid, p_student_id uuid, p_max_attempts integer)
returns public.checkin_attempts language plpgsql security definer set search_path = public as $$
declare
  v_row public.checkin_attempts;
  v_count integer;
  v_session public.sessions;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_session_id::text || ':' || p_student_id::text, 0));
  select * into v_session from public.sessions where id = p_session_id for update;
  if not found then raise exception 'session_not_found'; end if;
  if v_session.status = 'finalized' then raise exception 'session_finalized'; end if;
  select * into v_row from public.checkin_attempts where attempt_id = p_attempt_id;
  if found then
    if v_row.session_id = p_session_id and v_row.student_id = p_student_id then
      if v_row.state = 'evaluating' then raise exception 'attempt_in_progress'; end if;
      return v_row;
    end if;
    raise exception 'attempt_id_conflict';
  end if;
  select count(*) into v_count from public.checkin_attempts
    where session_id = p_session_id and student_id = p_student_id;
  if v_count >= p_max_attempts then raise exception 'attempt_limit_reached'; end if;
  insert into public.checkin_attempts(attempt_id, session_id, student_id, state, received_at, created_at, updated_at)
    values (p_attempt_id, p_session_id, p_student_id, 'evaluating', now(), now(), now()) returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.begin_checkin_attempt(text, uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.begin_checkin_attempt(text, uuid, uuid, integer) to service_role;

-- The unused legacy suggestions table is left untouched pending explicit data-deletion approval.
