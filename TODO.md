# Delivery checklist and status

## Flutter teacher/student application — prototype implemented

- Teacher sign-in, class/session workflow, simulated image capture, pending roster review, manual present/absent corrections, explicit finalization, and audit visibility are implemented.
- Student sign-in, own attendance history and summary, and private in-app notification feed are implemented.
- Android, iOS, and Web project scaffolding is generated. Flutter analysis, widget smoke test, and Flutter Web build require a Flutter SDK; the current audit sandbox does not have one installed.
- **Not implemented:** facial recognition, actual student matching, demographic accuracy claims, and specific automated detection of poor lighting, occlusion, unidentified people, or duplicates. The capture endpoint returns synthetic suggestions only. The user/teacher must review and confirm attendance. An Android APK/device camera test remains unavailable because the sandbox has no Android SDK or mobile device.

## Shared API and audit trail — prototype implemented

- Flutter and React dashboard use the shared FastAPI REST API, Supabase Auth/PostgreSQL persistence, and WebSocket event stream. All cross-client identifiers are UUID strings.
- Session creation, simulated capture, changes, and finalization are auditable. Students can read only their own attendance and notifications; teacher-only roster/report/audit/write routes are enforced by the API.
- Captures are not persisted by the application; no face embeddings or biometric templates are generated or stored. In-app notifications only; no email, SMS, or push integration is configured.

## Responsive web dashboard and exports — prototype implemented

- Teacher dashboard supports classes, session start/review/finalize, history, audit, and session reports.
- Session CSV is exported from backend report data. The print-friendly HTML report can be printed/saved as PDF from a browser; the backend does not itself render PDF files.
- Student dashboard displays that signed-in student's own summary/history and notification feed. Offline/demo fallback data for the two student accounts is kept separate.

## Realtime app/dashboard synchronization — implemented in source

- Authenticated short-lived single-use WebSocket tickets are used. Attendance changes carry the authoritative persisted row and update active views incrementally; session/finalization/notification events reconcile affected data, including after reconnect.
- Backend WebSocket/API tests pass. Dashboard production build passes. No separate external production deployment, Flutter SDK run, real-network mobile device test, or public browser end-to-end session was performed in this sandbox.

## Privacy, security, and deployment — prototype limits documented

- A manual teacher-review path exists; biometric recognition/enrollment and production operation are out of scope. Do not use real student information or run this as a live school attendance system.
- Demo passwords, development secret/database defaults, and local CORS configuration are development-only. TLS/WSS, production authentication, encryption/key management, retention/deletion policy, backup/monitoring, legal/privacy/fairness review, and production hosting still require separate implementation and review.
- Requested accuracy/latency thresholds are evaluation targets only. No performance, accuracy, consent, or fairness evaluation is claimed.

## Checks completed

- `flutter analyze`, `flutter test`, and `flutter build web`: not run; Flutter SDK is unavailable in this audit sandbox.
- Backend `pytest -q`: 9 passed.
- Dashboard `npm run build`: succeeded after API/real-time integration changes.
- Android APK and iOS native builds are not claimed: Android SDK/device unavailable in this sandbox; iOS build requires macOS/Xcode.
