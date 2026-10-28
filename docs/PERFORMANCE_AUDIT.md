# Performance audit

## Why the product felt slow

The application was doing more work than the user action required. The dominant cause was not one slow widget or CSS rule; it was a combination of repeated network round trips, whole-screen refetches, and a mobile identifier mismatch that could turn normal actions into failed requests.

1. **Realtime attendance edits triggered broad refetches.** A single attendance change caused the dashboard's live-session parent to reload both the class list and the session list, while the active workspace also reloaded the full roster and audit log. The mobile client reloaded the entire session after each edit. This multiplied latency and database work as the roster grew.
2. **Client startup loads were serial.** The Flutter home screen fetched classes, sessions, notifications, and student attendance one after another. The dashboard live-session screen fetched classes before sessions. These independent requests unnecessarily added their latencies together.
3. **Flutter parsed Supabase UUIDs as integers.** The backend schema uses UUID identifiers, but mobile model fields were `int`. UUID parsing fell back to `0`, so later URLs could address `/sessions/0`, `/attendance/0`, or `/classes/0`. This is a correctness defect that can present as slowness through repeated retries and manual refreshes.
4. **Finalization performed one audit insert per pending student.** A large roster therefore caused hundreds of sequential database calls. The finalization path also published one notification event per student.
5. **History queries were unbounded.** Sessions, student attendance, audit records, notifications, and suggestion payloads could grow indefinitely. The more a school used the app, the more every refresh had to transfer and parse.
6. **The dashboard waited on an external font import.** The stylesheet imported Google Fonts at render time. A blocked or slow third-party request could delay first paint even though the app did not need it to function.
7. **Failed edits could leave optimistic UI state behind.** When an attendance PATCH failed, the dashboard kept the changed status visible. Users could interpret the stale state as a successful save and retry manually, adding more traffic and confusion.

## Changes applied

- Attendance events now include the persisted attendance row and audit identifier. The dashboard and mobile client update the affected row incrementally; they only reconcile the full view for session-level events or reconnects.
- Independent dashboard and mobile loads use parallel requests. The initial mobile realtime connection no longer performs an immediate duplicate home reload.
- All mobile domain identifiers are UUID-safe `String` values. A regression test verifies that session, class, and student UUIDs survive JSON parsing.
- Finalization uses one conditional session transition, one batched audit insert, one batched notification insert, and one broadcast for student notification events. Repeating finalization returns the authoritative finalized summary without creating another notification batch.
- Session, audit, notification, and student attendance history reads have bounded defaults with server-side limits. Sessions support `limit` and `offset` query parameters.
- Database indexes cover teacher classes, student enrollments, session chronology, attendance status, suggestions, and audit chronology.
- The external font import was removed in favor of local system fonts.
- Dashboard attendance edits roll back to the previous row if the API write fails. API requests now have a 15-second timeout so a dead service cannot leave the UI spinning forever.
- The profile lookup uses a short, bounded cache to reduce repeated authentication queries while keeping role/profile changes short-lived in cache.
- Supabase RLS policy references were qualified explicitly, and the API contract/docs were corrected from the old SQLite/numeric-ID description to the active Supabase/UUID implementation.

## Remaining limits and operational notes

The capture endpoint intentionally generates synthetic suggestions and still writes one suggestion row per enrolled student per capture. It should be monitored for very large classes or repeated captures; a future migration could add a capture identifier and retention policy if capture history is required. The API still uses synchronous Supabase calls inside FastAPI sync routes, which FastAPI executes in its worker pool; production should size workers and connection limits together and add database/API tracing before setting an SLA.

The conditional finalization flow prevents concurrent retries from duplicating finalization audits or notification events. A database transaction/RPC would be the next hardening step if crash-consistency between the session transition, attendance updates, audits, and notifications becomes a requirement.

This audit was source-based and did not claim live latency measurements because no production Supabase connection or public deployment was available in the sandbox.

## Validation

- Backend: `python3 -m pytest -q` — 9 passed.
- Dashboard: `npm run build` — TypeScript and Vite build passed.
- Mobile: Flutter 3.47.8 `flutter analyze` — no issues; `flutter test` — 3 passed; `flutter build web` — succeeded.
- Repository: `git diff --check` passed.
