# Requirements review and implementation decisions

The active request expands the earlier prototype into a real Supabase-backed attendance workflow. Implementation has been extended in place; this file supersedes the earlier SQLite/synthetic-recognition description.

## Architecture and role behavior

- backend/app/main.py is the sole API implementation and deployment entrypoint. backend/app/main_supabase.py is retained as a compatibility import.
- apps/dashboard/ is the canonical React/Vite dashboard. apps/dashboard-next/ remains untouched pending explicit removal approval.
- The database role stays teacher; user-facing role selection and workspace copy say “Lecturer”.
- Login receives the selected role and compares it to the Supabase profile role. Only backend routes write attendance.

## Attendance, verification and review

- Sessions are timed by server timestamps, close in the lifespan background task and lazily on reads/submissions, and move open → closed → finalized.
- The old capture endpoint returns 410. The dashboard/mobile no longer present synthetic confidence suggestions. Lecturers can use audited manual roll call.
- Enrollment stores an encrypted embedding, model version and consent time. Sweep attempts carry frame timing and client gyroscope headings; these headings are untrusted supporting metadata.
- Verification code uses a FaceEngine boundary, configured YuNet detector and ArcFace ONNX embeddings. Uncertain attempts enter lecturer review with private filmstrip evidence. No liveness claim is made.
- The legacy suggestions table is no longer used but remains in the database migration path to avoid destructive deletion without approval.
- See docs/API_CONTRACT.md and docs/PRIVACY_AND_DEPLOYMENT.md for routes, data handling and model-license caveats.

## Evidence and limitations

Source code and tests have been changed, but pytest could not run because dependencies were not available and installation failed. Flutter analysis/tests could not run because Flutter is unavailable. Dashboard typecheck and Vite production build passed using the native config loader. No Supabase migration, real model, browser attendance flow, device camera sweep, or volunteer classroom evaluation was performed. No accuracy or fairness results are asserted. Exact commands are in docs/BUILD_VALIDATION.md and the final response.
