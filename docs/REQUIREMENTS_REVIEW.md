# Requirements review and implementation decisions

## Requested product

The attached brief specifies an attendance system where a teacher opens a class session, captures a classroom photo, detects and recognizes enrolled students, reviews likely matches and confidence, makes manual corrections, and only then finalizes the record. It also asks for teacher class/session views and exports, a student history and percentage view, app notifications, audit history, a mobile app and web dashboard sharing a backend/database, and careful treatment of biometric and education data.

The final line narrows notifications to the app only: no email. The prototype implements a private in-app notification feed; actual FCM push delivery requires a Firebase project and server credentials, which are not present and will not be invented.

## Requirement-to-component mapping

- Teacher capture, class/session start, seeded roster review, manual attendance-status corrections, and finalization belong in the Flutter teacher flow and web teacher dashboard. This prototype does not include class enrollment or student roster creation/deletion.
- Student history, dates, totals, percentage, and notifications are restricted to the logged-in student's own profile in both clients.
- Session records, statuses, users/roles, audit entries, and notifications live in one Supabase Auth/PostgreSQL-backed FastAPI service for the prototype.
- Class, session, student, attendance, notification, and audit identifiers are UUID strings across both clients.
- A single REST API carries writes and reads; authenticated, short-lived WebSocket tickets and event messages keep the app and website views current.
- CSV export and print-to-PDF are available from teacher report views. Audit events record session creation, capture, simulated suggestions, edits, and finalization with actor and timestamps.
- Teacher confirmation is the only way to turn a suggestion into a final attendance status. Remaining pending students are explicitly marked absent by the teacher during finalization.

## Safety boundary for this prototype

The reference brief identifies facial data as sensitive, calls for appropriate notice and consent, an opt-out/manual route, minimal retention, protected templates, access controls, and fairness assessment. This implementation therefore uses fictional seed students and simulated match suggestions. It does not run face recognition, create face embeddings, retain uploaded photos, or silently decide who attended. The capture request returns a mock review list and does not persist the upload in application storage; multipart parsing may use request-scoped temporary storage. Keep real student data and photos out of the demo.

A future real-recognition pilot would need an approved model and license, lawful consent and age-appropriate governance, a deletion schedule, threat model, secure encrypted deployment, data-subject controls, liveness/anti-spoofing analysis if needed, and consented evaluation across lighting, pose, distance, occlusion, and demographic groups. The brief's ≥95% true-positive and latency values are target metrics to measure, not claims about this prototype.

## Delivery sequence

The implementation follows the user's sequence: first Flutter source and teacher/student workflows; second the responsive dashboard; third connect both to the same API and live event stream. Flutter was chosen over the managed Expo alternative. Native compilation and device-only camera/push behavior are reported only if actually verified. The current audit sandbox does not contain a Flutter SDK, so Dart analysis/build validation remains pending.

## Explicit out-of-scope items for this first prototype

Production hosting, real face recognition, production authentication/MFA, encrypted managed PostgreSQL, FCM credentials and actual push delivery, legal compliance certification, and accuracy/fairness claims are not configured. The data model and service boundaries should make these later phases possible without pretending they are already delivered.
