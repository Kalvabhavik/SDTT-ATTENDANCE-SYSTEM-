# Classroom Attendance Backend

FastAPI backend for the shared Flutter/web classroom attendance service. The merged implementation supports Supabase/PostgREST persistence when configured, an in-memory adapter for isolated tests, encrypted biometric reference enrollment, continuous sweep verification, lecturer review, controller roster management, audit logging, and authenticated realtime events.

## Run locally

```bash
cd backend
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # optional; load values in your shell or process manager
uvicorn app.main:app --env-file .env --reload --host 0.0.0.0 --port 8000
```

The API is under `/api`; WebSocket tickets connect to `/api/ws?ticket=...` (and `/ws?ticket=...` is also accepted for clients using the short route).

## Demo accounts (development only)

- `teacher@demo.edu` / `teach123`
- `student1@demo.edu` / `student123`
- `student2@demo.edu` / `student123`

Demo accounts and seed data are development-only. Do not use demo credentials or unconfigured fallback persistence for real student data.

## Key workflow

1. `POST /api/auth/login` to obtain a bearer token.
2. Teacher lists classes, creates a session, and receives a pending roster.
3. Students enroll a consented reference selfie and submit continuous sweep frames during an active session. The ordered backend rules validate time, idempotency, image quality, sweep evidence, self-match, neighbour presence, lecturer identification, fraud signals, and the final decision.
4. Flagged results enter the lecturer review queue; manual roll-call is available as an explicit fallback. Raw sweep frames are purged after processing according to the configured lifecycle.
5. The lecturer closes the session after review. Final counts, audit entries, notifications, and reports are persisted from authoritative attendance decisions.
6. Students can read only their own attendance and notifications. Lecturers can read assigned class rosters, reports, review queues, and audit entries. Controllers can manage authorized roster/reference data.
7. `POST /api/auth/ws-ticket` creates a short-lived, single-use ticket for `/api/ws?ticket=...`. Clients use the structured events and reconcile from the server after reconnecting.

## Configuration

See `.env.example`. Secrets are environment inputs; the fallback `ATTENDANCE_APP_SECRET` is development-only. Configure Supabase URL/service-role credentials, a strong application secret, CORS origins, token limits, biometric retention, and deployment observability before production use.

## Prototype boundaries

The verification pipeline is not a guarantee of accuracy or proxy-attendance elimination. Production requires privacy/legal review, consent and deletion controls, TLS, institution-approved authentication/MFA, encrypted storage, backup, monitoring, physical-device evaluation, and a separately reviewed push provider. `pdf_html` in the report endpoint is print-friendly report data, not a server PDF renderer.

## Tests

```bash
pytest -q
```

Tests use isolated fixtures/adapters and cover authentication, authorization, reference enrollment, sweep verification, liveness/anti-spoofing, controller flows, concurrency, retry behavior, performance/privacy, camera inputs, auditability, reports, and one-time WebSocket ticket behavior.
