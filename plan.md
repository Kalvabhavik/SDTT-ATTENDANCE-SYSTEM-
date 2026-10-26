# Attendrix implementation plan

Extend the existing architecture in place: Flutter in apps/mobile, canonical Vite dashboard in apps/dashboard, and FastAPI/Supabase in backend. The DB role remains teacher, presented as “Lecturer”. apps/dashboard-next/ is a duplicate retained pending explicit deletion approval. backend/app/main_supabase.py is a compatibility import; app.main:app is the sole implementation entrypoint.

Attendance timing and decisions are server-authoritative. Sessions progress open → closed → finalized; a lecturer can use the manual roll-call route. A student sweep is submitted as one idempotent attempt. The pipeline records rule outcomes and reason codes, encrypts enrolled face templates, stores only flagged review filmstrips in private storage, and deletes flagged evidence according to the configured retention period. Missing real face models or encryption configuration fail closed.

Implementation source exists across backend verification, mobile capture, dashboard review/reporting, migrations, and documentation. Only commands reported as executed in the final report count as verification. No classroom recognition accuracy or liveness claim is made. See TODO.md for blockers and docs/PRIVACY_AND_DEPLOYMENT.md for deployment requirements.
