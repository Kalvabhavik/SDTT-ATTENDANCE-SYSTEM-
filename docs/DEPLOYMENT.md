# Deployment runbook

This repository currently ships a review-first attendance prototype with Supabase-backed persistence. It does **not** ship a biometric recognition model, evidence object storage, push provider, or institutional identity integration. Those capabilities must be completed and evaluated before live classroom use.

## Required services

- Supabase project with Auth and PostgreSQL.
- A private API runtime for `backend/Dockerfile`.
- A TLS-terminating reverse proxy or managed ingress in front of the API.
- A separately hosted dashboard built from `apps/dashboard`.

Do not expose the Supabase service-role key, PostgreSQL, or private storage directly to browsers or the public internet.

## Configuration

Copy `backend/.env.example` to a secret-managed environment. Production requires `ATTENDANCE_ENV=production`, real Supabase values, a JWT secret, and HTTPS-only `ATTENDANCE_CORS_ORIGINS`. Never commit `.env` files or place secrets in Vite variables. `SUPABASE_ANON_KEY` is not used by the API and should not be used as a substitute for the service-role key.

The API performs signature and audience validation on every bearer token. It fails closed when production configuration is missing. `/api/health` is a liveness check; `/api/ready` verifies database connectivity and should be used for readiness probes.

## Build and run

```bash
cp backend/.env.example backend/.env
# fill backend/.env using a secret manager

docker compose build api
docker compose up -d api
curl http://127.0.0.1:8000/api/health
curl http://127.0.0.1:8000/api/ready
```

Put the dashboard behind the same TLS-controlled deployment boundary and set `VITE_API_BASE_URL` to the public API `/api` origin. Keep `VITE_ENABLE_DEMO_MODE=false` outside local development. The API process runs as a non-root user, drops Linux capabilities, uses a read-only filesystem, and binds the local compose port to loopback. Adjust the ingress and port binding to match the institution's network design.

## Operations

Use structured platform logs with request IDs from `X-Request-ID`, alert on readiness failures, 5xx rates, login throttling, capture validation failures, and Supabase errors. Configure Supabase backups and test restoration before onboarding real data. The current API does not include a background evidence-deletion worker because it deliberately does not persist captures; adding retained classroom evidence requires a private object store, deletion queue, lifecycle verification, and a separate migration.

Rollback by deploying the previous immutable image tag and confirming `/api/ready`; do not roll back database migrations without a reviewed backward-compatibility plan.
