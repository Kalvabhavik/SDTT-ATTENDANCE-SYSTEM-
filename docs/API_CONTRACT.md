# API contract

Base path: /api. Authenticated HTTP calls use Authorization: Bearer <Supabase access token>. The backend validates Supabase Auth identity and loads the authoritative profile role. selected_role on login must match that profile (teacher or student); “Lecturer” is display copy only. IDs are Supabase strings/UUIDs.

## Auth, realtime, enrollment

- POST /auth/login {email,password,selected_role} returns access token and user, or rejects role mismatch.
- GET /me returns the authenticated profile.
- POST /auth/ws-ticket returns a short-lived single-use ticket. Connect to /ws?ticket=...; never put the bearer token in the URL.
- GET /config returns max session duration and server time.
- GET /enrollment/status returns only enrollment status, model version and consent timestamp.
- POST /enrollment/face accepts explicit consent plus a JPEG/PNG camera photo. The service checks image quality and exactly one face, encrypts the embedding, and never returns it.

## Sessions and attendance

- GET /classes, GET /classes/{id}/students, GET /sessions, GET /sessions/{id} are role-limited reads. Read endpoints also lazily close expired sessions.
- POST /sessions {class_id,duration_minutes} creates a server-timed open session and pending roster entries. Maximum duration comes from /config.
- POST /sessions/{id}/capture is retired and returns HTTP 410. Use POST /sessions/{id}/submissions for camera sweeps.
- POST /sessions/{id}/submissions is multipart: attempt_id idempotency UUID, duration_seconds, frame_metadata JSON array (offset_seconds, heading_degrees), repeated frames JPEG/PNG parts. Outcomes are verified, flagged, or rejected; responses include rule results/reason codes. One verified result per student/session is enforced by the database.
- GET /sessions/{id}/review-queue returns flagged attempts and short-lived signed private evidence URLs. PATCH /sessions/{id}/submissions/{attempt_id}/review accepts decision accepted/rejected and a note, then audits the lecturer decision.
- PATCH /sessions/{id}/attendance/{student_id} allows lecturer manual present/absent/pending corrections with audit note. This is the opt-out route.
- Session lifecycle is open → closed → finalized. Server-side expiry runs in background and lazily on reads/submissions. A submission is accepted only before end time plus configured grace.
- POST /sessions/{id}/finalize {mark_pending_absent:true} finalizes a closed session and marks pending rows absent.

## Reporting and existing services

- GET /students/me/attendance returns only the caller’s history and summary.
- GET /reports/sessions/{id} returns CSV text and print-friendly HTML (pdf_html).
- GET /audit?session_id=..., GET /notifications, POST /notifications/{id}/read remain authenticated and access limited.
- WebSocket events include session.created, attendance.changed, session.closed, session.finalized, attendance.attempt, notification.created. Events are hints; clients re-fetch REST state.

See backend/app/verification_config.py for centralized thresholds and backend/migrations/ for schema changes. Contract implementation has not been integration-tested against a deployed Supabase project in this environment.
