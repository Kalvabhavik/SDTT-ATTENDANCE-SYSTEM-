# Classroom Attendance — implementation plan

## Product scope

Deliver a working prototype in this order: (1) Flutter mobile app with teacher/student flows, (2) responsive web dashboard, then (3) both clients connected to the same API/database and WebSocket event stream. The app supports classes, sessions, camera capture, confidence-tagged review suggestions, manual corrections, finalization, personal attendance history, app-only notifications, CSV/PDF-friendly reports, session history, and an audit trail. No email or SMS channel is included.

## Architecture

- `apps/mobile/`: Flutter/Dart application with role-aware screens, camera capture, REST client, WebSocket refresh, and app notification feed.
- `apps/dashboard/`: responsive React + TypeScript web dashboard, reusing the same auth, REST routes, records, and WebSocket events.
- `backend/`: FastAPI API, Supabase Auth/PostgreSQL persistence, role-based authorization, session/attendance workflows, audit log, in-app notification records, and authenticated WebSocket events.
- `docs/`: API contract and privacy/deployment notes.

Synthetic accounts and suggestions are for local demonstration only. Supabase PostgreSQL identifiers are UUID strings. No face embeddings or raw class photos are retained. “Recognition” is an explicitly simulated suggestion workflow; a teacher must review and commit every status. Manual roll call remains available. Production use would require lawful notice/consent, opt-out process, security/privacy and fairness review, deployment-grade identity/authentication, backups, retention/deletion policies, and a separately configured push provider.

## Realtime contract

Both clients use the same backend URL. REST handles login, classes, session creation, capture review suggestions, attendance corrections/finalization, reports, audit, and notifications. WebSockets send `session.created`, `attendance.changed`, `session.finalized`, and `notification.created` events so connected views update without refresh. WebSocket access uses a short-lived one-time ticket rather than the long-lived API token in the URL.

## Design direction

Three low-probability alternatives considered: Minimalist Swiss campus ledger (0.06); soft playful classroom cards (0.04); high-contrast terminal dashboard (0.03). Chosen direction: **Quiet Signal**, a calm editorial campus utility. Core principles: prioritize the next teacher action; keep uncertainty visible; make corrections traceable; use accessible contrast and restrained surfaces. Color philosophy: ink/navy for dependable structure, cool teal for active/confirmed states, warm amber for review-needed states, and neutral paper backgrounds. Layout paradigm: teacher workflow as a left-to-right session journey, with roster and activity as practical side panels; student view leads with their own attendance summary. Signature elements: confidence chips with explicit “suggestion” labels; a timeline-style audit strip; clear present/absent/pending state markers. Interaction philosophy: immediate feedback and explicit confirmation for finalization; no automatic silent attendance. Motion: brief state transitions only, respect reduced-motion preferences. Typography: system sans-serif, large readable headings, consistent numeric treatment for percentages/counts. Brand essence: a review-first attendance tool for classrooms; calm, accountable, practical. Voice: clear and non-judgmental (“Review suggestions before saving.” / “Your attendance record is up to date.”). Wordmark: “Classroom” with a small three-mark attendance ledger motif. Signature color: deep teal.

## Build and environment status

The user approved installing the official Flutter stable SDK into the sandbox user's tools directory; Flutter 3.47.7 and Dart 3.13.5 are available at `/home/ubuntu/tools/flutter`. Flutter source analysis, widget smoke tests, and a Flutter Web build succeeded. The Android SDK and a mobile device are not available here, so Android APK/native camera behavior has not been built or device-verified. Dashboard TypeScript/Vite production build and backend tests passed.
