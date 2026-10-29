-- ==============================================================================
-- Attendrix / SDTT Attendance System – Migration 003
-- Purpose:
--   1. Support Unassigned Classes (allow nullable teacher_id on public.classes)
--   2. Add is_lab indicator to public.classes
--   3. Replace single-column code unique constraint with composite unique (code, section)
--   4. Update RLS policies for unassigned classes & controller access
--   5. Reviewable timetable mappings for CS262, CS263, CS264 with slot conflict advisory
--
-- Safety & Governance:
--   - This script is idempotent and wrapped in a transaction.
--   - DO NOT execute automatically on production without explicit human controller authorization.
-- ==============================================================================

BEGIN;

-- 1. Make teacher_id nullable on classes to support unassigned faculty workflow
ALTER TABLE public.classes ALTER COLUMN teacher_id DROP NOT NULL;

-- 2. Add is_lab flag to classes
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS is_lab boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_classes_is_lab ON public.classes(is_lab);

-- 3. Replace single-column unique constraint on code with composite unique (code, section)
-- This allows CS264 Section A and CS264 Section B to co-exist cleanly.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'classes_code_key' AND conrelid = 'public.classes'::regclass
  ) THEN
    ALTER TABLE public.classes DROP CONSTRAINT classes_code_key;
  END IF;
END $$;

ALTER TABLE public.classes DROP CONSTRAINT IF EXISTS classes_code_section_unique;
ALTER TABLE public.classes ADD CONSTRAINT classes_code_section_unique UNIQUE (code, section);

-- 4. Update Row-Level Security on classes
-- Controllers and Admins can view/edit all classes (including unassigned)
-- Teachers can view all classes or classes assigned to them
DROP POLICY IF EXISTS "classes_select" ON public.classes;
CREATE POLICY "classes_select" ON public.classes
  FOR SELECT USING (
    -- Any authenticated academic user (teacher, student, controller) can view the academic course catalog
    auth.role() = 'authenticated'
  );

DROP POLICY IF EXISTS "classes_controller_all" ON public.classes;
CREATE POLICY "classes_controller_all" ON public.classes
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('controller', 'admin')
    )
  );

DROP POLICY IF EXISTS "classes_teacher_manage" ON public.classes;
CREATE POLICY "classes_teacher_manage" ON public.classes
  FOR UPDATE USING (
    auth.uid() = teacher_id
  );

-- 5. Timetable Conflict Resolution & Provisional Insertion Script
-- Background:
--   Validation identified 6 pending course/section combinations:
--     1. CS262 (Data Structures & Algorithms Lab) - CSE-A
--     2. CS262 (Data Structures & Algorithms Lab) - CSE-B
--     3. CS263 (Database Management Systems)      - CSE-A
--     4. CS263 (Database Management Systems)      - CSE-B
--     5. CS264 (Operating Systems Core)           - CSE-A  [ADVISORY: Slot conflict between Slot A2 (Mon/Wed 10:00) vs Slot D2 (Tue/Thu 14:00)]
--     6. CS264 (Operating Systems Core)           - CSE-B
--
-- The following statements safely upsert the classes with explicit 'Unassigned' faculty (teacher_id = NULL).
-- Controllers can then assign verified faculty directly from the Controller UI.

INSERT INTO public.classes (name, code, section, room_number, capacity, hall_type, is_lab, teacher_id)
VALUES
  ('Data Structures & Algorithms Lab', 'CS262', 'CSE-A', 'Lab-201', 80, '80-Seater Seminar Hall', true, NULL),
  ('Data Structures & Algorithms Lab', 'CS262', 'CSE-B', 'Lab-202', 80, '80-Seater Seminar Hall', true, NULL),
  ('Database Management Systems',      'CS263', 'CSE-A', 'LH-120', 120, '120-Seater Lecture Theater', false, NULL),
  ('Database Management Systems',      'CS263', 'CSE-B', 'LH-120', 120, '120-Seater Lecture Theater', false, NULL),
  ('Operating Systems Core',           'CS264', 'CSE-A', 'LH-240', 240, '240-Seater Tiered Amphitheater', false, NULL),
  ('Operating Systems Core',           'CS264', 'CSE-B', 'LH-240', 240, '240-Seater Tiered Amphitheater', false, NULL)
ON CONFLICT (code, section) DO UPDATE
SET
  name = EXCLUDED.name,
  room_number = EXCLUDED.room_number,
  capacity = EXCLUDED.capacity,
  hall_type = EXCLUDED.hall_type,
  is_lab = EXCLUDED.is_lab;

-- Timetable Provisional Slots:
-- For CS264/CSE-A, Slot A2 (Mon 10:00-11:30) is provisionally scheduled.
-- If the Controller resolves in favor of Slot D2, it can be updated via the Timetable UI.
DO $$
DECLARE
  v_cs262_a uuid;
  v_cs263_a uuid;
  v_cs264_a uuid;
BEGIN
  SELECT id INTO v_cs262_a FROM public.classes WHERE code = 'CS262' AND section = 'CSE-A' LIMIT 1;
  SELECT id INTO v_cs263_a FROM public.classes WHERE code = 'CS263' AND section = 'CSE-A' LIMIT 1;
  SELECT id INTO v_cs264_a FROM public.classes WHERE code = 'CS264' AND section = 'CSE-A' LIMIT 1;

  IF v_cs262_a IS NOT NULL THEN
    INSERT INTO public.timetable (class_id, day_of_week, day_name, start_time, end_time, room_number, is_cancelled)
    SELECT v_cs262_a, 1, 'Tuesday', '14:00', '16:00', 'Lab-201', false
    WHERE NOT EXISTS (SELECT 1 FROM public.timetable WHERE class_id = v_cs262_a AND day_of_week = 1);
  END IF;

  IF v_cs263_a IS NOT NULL THEN
    INSERT INTO public.timetable (class_id, day_of_week, day_name, start_time, end_time, room_number, is_cancelled)
    SELECT v_cs263_a, 2, 'Wednesday', '11:00', '12:30', 'LH-120', false
    WHERE NOT EXISTS (SELECT 1 FROM public.timetable WHERE class_id = v_cs263_a AND day_of_week = 2);
  END IF;

  IF v_cs264_a IS NOT NULL THEN
    -- Slot A2 provisional assignment
    INSERT INTO public.timetable (class_id, day_of_week, day_name, start_time, end_time, room_number, is_cancelled)
    SELECT v_cs264_a, 0, 'Monday', '10:00', '11:30', 'LH-240', false
    WHERE NOT EXISTS (SELECT 1 FROM public.timetable WHERE class_id = v_cs264_a AND day_of_week = 0);
  END IF;
END $$;

COMMIT;
