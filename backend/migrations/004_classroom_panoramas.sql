create table if not exists public.classroom_panoramas (
  id                  uuid primary key default uuid_generate_v4(),
  capture_id          text not null,
  session_id          uuid not null references public.sessions(id) on delete cascade,
  class_id            uuid not null references public.classes(id) on delete cascade,
  faculty_id          uuid not null references public.profiles(id) on delete cascade,
  source_paths        text[] not null,
  panorama_path       text,
  annotated_path      text,
  status              text not null check (status in ('processing', 'completed', 'review_required', 'failed')),
  occupancy_count    integer check (occupancy_count is null or occupancy_count >= 0),
  quality_results     jsonb,
  detection_results   jsonb,
  context_analysis    jsonb,
  warnings            jsonb not null default '[]'::jsonb,
  error_message       text,
  captured_at         timestamptz not null default now(),
  processed_at        timestamptz,
  expires_at          timestamptz not null default (now() + interval '30 days'),
  unique (session_id, capture_id)
);

create index if not exists idx_classroom_panoramas_session_captured
  on public.classroom_panoramas(session_id, captured_at desc);

alter table public.classroom_panoramas enable row level security;

drop policy if exists "classroom_panoramas_teacher_read" on public.classroom_panoramas;
create policy "classroom_panoramas_teacher_read" on public.classroom_panoramas
  for select using (
    exists (
      select 1 from public.sessions s
      join public.classes c on c.id = s.class_id
      where s.id = session_id and c.teacher_id = auth.uid()
    )
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('private-classroom-panoramas', 'private-classroom-panoramas', false, 41943040, array['image/jpeg', 'image/png'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;