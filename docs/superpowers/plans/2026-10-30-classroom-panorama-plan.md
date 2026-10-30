# Classroom Panorama Verification Implementation Plan

> **For agentic workers:** execute tasks in order, preserving the user's existing workspace changes.

**Goal:** Add an advisory faculty classroom panorama capture and analysis flow to the Flutter app and FastAPI backend.

**Architecture:** Flutter captures three to eight overlapping rear-camera views, uploads them to a faculty-owned active session, and polls a persisted processing record. The backend stores sources privately, stitches and analyzes them in a background task, and returns signed artifacts without touching attendance.

**Tech Stack:** Flutter `camera`, FastAPI, Supabase database/storage, OpenCV.

**Spec:** `docs/superpowers/specs/2026-10-30-classroom-panorama-design.md`

## Global Constraints
- Never modify dashboard frontend files.
- Never use panorama detections to identify students or authorize attendance.
- Require faculty role and active session ownership for upload.
- Validate image formats, dimensions, and per-frame/total size.
- Keep storage private and expose only short-lived signed URLs after authorization.

## Review Focus
- Repeated multipart frames must not collapse into one upload; cover with upload contract tests.
- Unauthorized or closed-session access must fail; cover with API tests.
- Stitch/detection failure must not fabricate occupancy; cover with processing failure tests.
- Retrying a request with the same capture ID must not create duplicates; cover with idempotency test.
- Camera denial/device lifecycle must leave a usable error/retake state; cover with analyzer and widget-level tests where hardware-independent.

---

### Task 1: Backend job and image processing

**Files:** `backend/app/main.py`, `backend/app/db.py`, `backend/migrations/004_classroom_panoramas.sql`, `backend/supabase_schema.sql`, `backend/tests/test_classroom_panorama_api.py`.

**Interfaces:** multipart `POST /api/sessions/{session_id}/panorama` with repeated `frames` and `capture_id`; `GET .../panorama/latest`; `GET .../panorama/{panorama_id}`; authorized `POST .../retry`.

- [x] Add failing API tests for auth, invalid image, active session, job/result, idempotency, and attendance isolation.
- [x] Add private persistence, bounded image processing, stitching, occupancy, quality/context, signed retrieval, and retry.
- [x] Run focused backend panorama tests.

### Task 2: Flutter capture and result workflow

**Files:** `apps/mobile/lib/screens/session_screen.dart`, `apps/mobile/lib/screens/classroom_panorama_screen.dart`, `apps/mobile/lib/services/api_client.dart`, `apps/mobile/test/classroom_panorama_test.dart`.

**Interfaces:** session screen launches camera flow with current session; API uploads image bytes and retrieves/retries the returned panorama job.

- [x] Add failing widget/API tests for the entry action and upload contract.
- [x] Implement rear-camera guided capture, preview/retake, upload state, polling, results, and retry.
- [x] Run mobile tests and `flutter analyze`.

### Task 3: End-to-end verification

**Files:** backend and mobile tests listed above.

- [x] Run panorama-focused tests, then existing backend tests and mobile tests/analyzer.
- [x] Report actual device limitation, async-worker limitation, and any unverified behavior.