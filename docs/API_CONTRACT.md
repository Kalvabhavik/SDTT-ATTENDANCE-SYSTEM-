# Shared API contract

Base path: `/api`. JSON is UTF-8. Authenticated HTTP routes use `Authorization: Bearer <access_token>`. The active container runs `backend/app/main.py` with Supabase Auth and PostgreSQL; demo accounts and synthetic suggestions are development-only.

## Authentication and roles

- `POST /auth/login` — `{email,password}` → `{access_token,token_type,user:{id,name,email,role}}`.
- `GET /me` — current authenticated profile.
- `POST /auth/ws-ticket` — returns a short-lived single-use `{ticket}` for WebSocket authentication.
- Roles are `teacher` and `student`; students may read only their own attendance and notifications.

Demo accounts: `teacher@demo.edu / teach123`; `student1@demo.edu / student123`; `student2@demo.edu / student123`.

## Classroom and attendance

- `GET /classes` → teacher's classes (student sees only enrolled classes).
- `GET /classes/{class_id}/students` → roster; teacher only.
- Teacher roster and session attendance rows include `roll_number` when the enrollment has been assigned one. Existing installations must backfill `enrollments.roll_number`; session creation uses a deterministic temporary position for legacy null values and does not change the enrollment record.
- `GET /sessions?limit=100&offset=0` → teacher history/open sessions, or student's own relevant sessions. The server caps list pages at 500.
- `POST /sessions` — `{class_id}` creates an open session and pending roster records (teacher only).
- `GET /sessions/{session_id}` → session, roster, attendance statuses, and suggestions (role-limited).
- `POST /sessions/{session_id}/capture` — multipart field `photo`; processes the request-scoped upload without persisting it in application storage, and returns an explicitly simulated list of name/confidence suggestions. Suggestions remain pending until a teacher accepts/edits them.
- `PATCH /sessions/{session_id}/attendance/{student_id}` — `{status:"present"|"absent"|"pending",note?}`; teacher only, always audited.
- `POST /sessions/{session_id}/finalize` — `{mark_pending_absent:true}` explicitly finalizes; remaining pending students become absent and each change is audited. Creates private in-app notifications for enrolled students. Repeating a finalized request returns its authoritative summary without duplicating finalization notifications.
- `GET /students/me/attendance` → personal entries and summary totals/percentage.
- `GET /reports/sessions/{session_id}` → report data for CSV/PDF export (role-limited).
- `GET /audit?session_id=<id>` — teacher-only trace of session creation, capture, suggestion generation, changes, and finalization.
- `GET /notifications`, `POST /notifications/{id}/read` — current user's in-app notification feed/read state.

Session, class, student, attendance, notification, and audit identifiers are UUID strings. Payloads use `created_at`, and `attendance` rows contain `student_id`, `roll_number`, `name`, `status`, `note`, `updated_at`, and a correction indicator where available. Capture suggestions use `name`, `roll_number`, confidence, and the non-attendance label `suggestion`; only a teacher's explicit review writes `present`, `absent`, or `pending`. Student attendance returns `summary.total_finalized` and a nullable `percentage` when there are no finalized records. Reports return `rows`, CSV text, and print-friendly HTML (`pdf_html`); audit entries use `timestamp`, `note`, and `metadata`; notification read state is `read_at`.

## Realtime

After obtaining a single-use ticket, connect to `GET /ws?ticket=<ticket>` over WebSocket (use `wss` in production). Server events include `{event_id,event_type,event_version,session_id,occurred_at,server_timestamp,type,data,created_at}` and types `session.created`, `attendance.changed`, `session.finalized`, `notification.created`. `event_id` is unique, and `event_version` increases per session so clients can ignore duplicate or stale events. Session creation and finalization signals are sent to the teacher and enrolled students; notification-created signals are private to the relevant student. The ticket expires quickly and is consumed once. Clients keep bounded event-ID/version guards, apply only newer committed events, and re-fetch the affected resource after reconnecting.

## Safety and production gaps

The capture endpoint intentionally returns synthetic suggestions and stores neither photo nor face embedding. It is not facial recognition. The demo password set and local CORS defaults are development-only. Production must use approved authentication/MFA, secure/encrypt data at rest and in transit, configure deployment/backup/retention, apply school-appropriate privacy/legal review, and implement a real FCM-only push adapter if push delivery is required. No email or SMS adapter is included.
