# Delivery checklist and verification status

## Implemented in source

- Supabase-backed FastAPI authentication requires the account profile role to match the role selected at login. The database value remains teacher, presented as “Lecturer”.
- Timed sessions carry server-generated start/end timestamps, lazy and background expiry closure, audit/notification events, and closed/finalized states.
- POST /sessions/{id}/capture is retired with HTTP 410; no upload-size confidence or synthetic suggestion path remains in the intended UI. Lecturer manual roll call remains available.
- Face enrollment encrypts templates with a configured Fernet key, returns only enrollment status, and records consent timestamp/model version. Sweep submission evaluates configured rules and persists verified, flagged or rejected outcomes. Flagged key frames use the private evidence bucket and retention worker.
- The mobile client has role selection, consent/enrollment, camera sweep, gyroscope metadata, practice mode, secure token storage, and server-relative countdown code.
- Vite dashboard is canonical and uses API data; apps/dashboard-next/ remains pending explicit deletion approval. backend/app/main_supabase.py remains a compatibility import.
- SQL bootstrap and migration source include session/evidence/template changes and sensitive-table RLS. Migrations have not been applied to a live Supabase project here.

## Not verified / known limitations

- No end-to-end test against a configured Supabase project, actual user accounts, storage bucket or production model files.
- No Android real-device camera sweep, iOS native camera run, real classroom, or volunteer-manifest execution. No accuracy or lecturer-visible rate is claimed.
- Lecturer detection currently relies on face detections; there is no independent person detector to prove a person is present when no face is detected.
- YuNet/ArcFace model paths and legal model provenance need deployment review. InsightFace ArcFace pretrained weights have non-commercial research-only terms; commercial use requires a separate license. See docs/PRIVACY_AND_DEPLOYMENT.md.
- The API keeps a retired capture URL returning 410 for compatibility. Dashboard and mobile UI do not expose synthetic capture suggestions.
- Python dependencies could not be installed in this environment because pip failed with permission errors under its temporary wheel directory; pytest was not run. Flutter SDK is unavailable; flutter analyze and flutter test were not run. See the final report for exact command results.

## Test cases awaiting configured CI/DB/device

Role mismatch, unauthorized lecturer routes, class membership, grace-window expiration, duplicate attempt ID, concurrent verified submissions, upload limits, image-quality/sweep/identity rules, and one-time session closure/counts have source tests or helper coverage. Database-dependent concurrency and full endpoint integration still need execution against the migration-backed Supabase test project. Do not treat source tests as passing until run.
