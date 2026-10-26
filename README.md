# Smart Classroom Attendance

A shared Flutter mobile app and React dashboard backed by a FastAPI service and Supabase Auth/Postgres/Storage. Students submit a classroom image during a server-timed attendance window. The backend checks image quality and classroom-scene evidence with a pretrained person detector; it does **not** identify people or compare faces. A passing scene check can mark the authenticated submitter present, while uncertain evidence remains pending for a professor to review. Manual roster correction and explicit session finalization remain available.

## Components

- `apps/mobile/` — Flutter student/professor workflows, timed attendance, mobile image selection, personal history, in-app notifications, and WebSocket refresh.
- `apps/dashboard/` — React/TypeScript role-aware dashboard for timed session scheduling, student panorama upload, professor image review/manual decisions, audit, history, and CSV/printable reports.
- `backend/` — FastAPI service with Supabase Auth token verification, Postgres-backed records, private Storage uploads, image verification, retention cleanup, audit, and short-lived WebSocket tickets.
- `backend/supabase_schema.sql` — complete fresh-project schema and attendance upgrade.
- `backend/migrations/20261026_smart_attendance.sql` — upgrade for an existing database created from the earlier schema.
- `docs/` — API, privacy, setup, and validation notes.

## Setup

1. Create a Supabase project. For a fresh database, run `backend/supabase_schema.sql` in SQL Editor. For a project using the earlier schema, run that original schema first and then `backend/migrations/20261026_smart_attendance.sql`.
2. In `backend/`, create a virtual environment, install `requirements.txt`, copy `.env.example` to `.env`, and set the Supabase URL, anon key, service-role key, JWT secret, allowed CORS origins, and image policy values. Never expose the service-role key or JWT secret in a client build or commit a real `.env` file.
3. Provision Auth users and administrator-controlled `profiles` roles/enrollments. The guarded synthetic-account helper is development-only: set `DEMO_TEACHER_PASSWORD` and `DEMO_STUDENT_PASSWORD`, then run `python scripts/seed_demo_accounts.py` from `backend/`.
4. Start the API with `uvicorn app.main:app --env-file .env --host 0.0.0.0 --port 8000` from `backend/`.
5. Start the dashboard with `cd apps/dashboard && npm ci && VITE_API_BASE_URL=http://localhost:8000/api npm run dev`. Use the API host reachable from the browser, not `localhost`, when these run on different machines.
6. For Flutter, run `cd apps/mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api` for an Android emulator, or provide the host's LAN URL for a physical device. Set the same API base URL for the web build as required.

## Attendance workflow

A professor creates a session with an opening time and duration, minimum visible-person threshold, and optional normalized stage region. The server, not the device clock, transitions it from scheduled to open and then closed. Students use their own registered ID/email account, capture a broad classroom panorama with the phone's camera app, and upload the saved image. The API enforces file type/size and image-quality requirements, and returns a scene-evidence result. `VERIFIED` is a scene-level result, not proof that the uploader's identity appears in the image. `NEEDS_REVIEW` and `REJECTED` are not treated as present; professors can inspect a signed, short-lived private image URL and make an audited decision. Rejected students may retry only when policy allows and no professor decision has been recorded. After closing the window, a professor can correct the roster and explicitly finalize; remaining pending students become absent.

## Privacy and limits

Images are re-encoded without embedded metadata, held in a private Supabase Storage bucket for review, and deleted by the backend retention worker after `ATTENDANCE_IMAGE_RETENTION_DAYS` (default 30; allowed range 1–3650). Submission metadata and attendance records remain after image deletion. No facial recognition, biometric embeddings, identity matching, email/SMS sender, or push provider is included. Notifications are in-app only. The person detector's scene evidence is fallible; manual attendance remains available. This is a prototype, not a certification of education/privacy law compliance or a production-ready school system. Before a real pilot, review consent/notice, opt-out/manual pathways, model and dependency licensing, security, image retention, fairness/accuracy, and institutional requirements.

## Validation

Current reproducible checks include `python -m pytest -q` under `backend/` and `npm run build` under `apps/dashboard/`. Flutter checks require the Flutter SDK: `flutter analyze`, `flutter test`, and optionally `flutter build web`. Android device camera behavior and iOS native builds require the relevant SDK/device and are not claimed unless tested. See [`docs/BUILD_VALIDATION.md`](docs/BUILD_VALIDATION.md) for the latest environment-specific results.
