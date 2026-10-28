# Requirements review and implementation decisions

## Requested product

The attached brief specifies an attendance system where a teacher opens a class session, captures a classroom photo, detects and recognizes enrolled students, reviews likely matches and confidence, makes manual corrections, and only then finalizes the record. It also asks for teacher class/session views and exports, a student history and percentage view, app notifications, audit history, a mobile app and web dashboard sharing a backend/database, and careful treatment of biometric and education data.

The final line narrows notifications to the app only: no email. The prototype implements a private in-app notification feed; actual FCM push delivery requires a Firebase project and server credentials, which are not present and will not be invented.

## Requirement-to-component mapping

- Teacher session start, live roster review, manual attendance corrections, review-queue decisions, and finalization belong in the Flutter teacher flow and web lecturer dashboard. Controller flows now support student enrollment, roster import, and reference-template management.
- Student history, dates, totals, percentage, and notifications are restricted to the logged-in student's own profile in both clients.
- Session records, statuses, users/roles, audit entries, biometric reference metadata, and notifications are served by the FastAPI database adapter, using configured Supabase/PostgREST persistence in deployment and an in-memory adapter for isolated tests.
- A single REST API carries writes and reads; authenticated, short-lived WebSocket tickets and event messages keep the app and website views current.
- CSV, Excel-compatible, and print/report exports are available from authorized lecturer/controller views. Audit events record session creation, sweep submissions, verification decisions, review actions, manual corrections, and finalization with actor and timestamps.
- A verified decision is written only after the ordered backend rules complete. Flagged decisions enter the lecturer review queue; manual roll-call remains available as the explicit opt-out path.

## Safety boundary for this prototype

The reference brief identifies facial data as sensitive, calls for appropriate notice and consent, an opt-out/manual route, minimal retention, protected templates, access controls, and fairness assessment. The merged implementation performs reference-template enrollment and a nine-rule continuous sweep verification pipeline, stores encrypted reference templates, purges raw sweep frames after processing, and routes uncertain cases to lecturer review. This is an implementation feature, not a claim of perfect accuracy or proxy-attendance elimination. Production deployments still require institution-approved consent, retention, deletion, access, and fairness governance.

The verification pipeline uses liveness and presentation-attack defenses, but it still requires consented evaluation across lighting, pose, distance, occlusion, device type, and demographic groups. The brief's ≥95% true-positive and latency values are target metrics to measure, not claims about this implementation. Physical-device camera behavior and live lecture-hall deployment remain environment-dependent validation items.

## Delivery sequence

The implementation follows the user's sequence: first Flutter source and teacher/student workflows; second the responsive dashboard; third connect both to the same API and live event stream. Flutter was chosen over the managed Expo alternative. The sandbox initially had no Flutter or Dart; the user then explicitly approved installing the official stable Flutter SDK under `/home/ubuntu/tools/flutter`, without system-wide or sudo changes. Native compilation and device-only camera/push behavior are reported only if actually verified.

## Explicit out-of-scope items for this first prototype

Production hosting, institution-specific MFA, FCM credentials and actual push delivery, legal compliance certification, and accuracy/fairness guarantees are not configured. The implementation provides the security and data-lifecycle hooks, but deployment owners must configure secrets, database persistence, retention, and institutional policy before real student use.
