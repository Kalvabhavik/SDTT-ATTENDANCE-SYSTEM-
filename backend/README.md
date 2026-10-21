# Classroom Attendance Backend

FastAPI + SQLite prototype for the shared Flutter/web classroom attendance service. This is a **synthetic, review-first demo**, not a biometric or production attendance system.

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

A single seeded class (`CS-101`) and two synthetic enrolled students are created on a new database. Do not use these credentials or the SQLite database for real student data.

## Key workflow

1. `POST /api/auth/login` to obtain a bearer token.
2. Teacher lists classes, creates a session, and receives a pending roster.
3. Teacher may upload `photo` to `/api/sessions/{id}/capture`. The capture is processed for this request and is not persisted by the application; the endpoint returns clearly labelled synthetic suggestions and writes a metadata audit entry. Multipart parsing can use temporary spooled storage for large uploads, which is handled by the framework for the request. No photo is kept in the application database or durable file storage, and no embedding is created.
4. Teacher reviews/edits each status through `PATCH /api/sessions/{id}/attendance/{student_id}`.
5. Teacher explicitly finalizes with `{ "mark_pending_absent": true }`. Remaining pending entries become absent, audit entries are written, and private in-app notifications are created for enrolled students.
6. Students can read only their own attendance and notifications. Teachers can read class rosters, reports, and audit entries.
7. `POST /api/auth/ws-ticket` creates a short-lived, single-use ticket for `/api/ws?ticket=...`. Events are informational; clients should refetch after reconnecting.

## Configuration

See `.env.example`. Secrets are environment inputs; the fallback `ATTENDANCE_APP_SECRET` is conspicuously development-only. Configure a strong secret, a private SQLite path, CORS origins, and token limits outside local demos.

## Prototype boundaries

No actual face recognition, biometric collection, embedding storage, email, SMS, real push adapter, or production security claim is included. `pdf_html` in the report endpoint is print-friendly report data, not a server PDF renderer. Production requires privacy/legal review, TLS, stronger identity/authentication, encrypted storage, retention/deletion controls, backup, monitoring, and a separately reviewed push provider.

## Tests

```bash
pytest -q
```

Tests use a temporary SQLite database and cover login/roles, teacher session flow, simulated capture privacy, finalization notifications, student isolation, audit entries, and one-time WebSocket ticket behavior.
