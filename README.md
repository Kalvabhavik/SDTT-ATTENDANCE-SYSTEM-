# Attendrix attendance system

This repository contains a Flutter mobile client, a Vite/React dashboard, and a FastAPI service backed by Supabase Auth and Postgres. The backend is the only authority that records verified attendance. DB roles remain student and teacher; the UI calls the latter “Lecturer”.

## Current implementation status

The code now has selected-role login checks, encrypted enrollment-template persistence, a configurable YuNet/ArcFace verification pipeline, multipart sweep submissions, review queue/evidence handling, server-timed sessions, manual lecturer roll call, WebSocket tickets, audit records, reports, and notifications. These are source-level implementations, not a claim of production readiness or classroom accuracy. Apply SQL migrations before running the service. Face model files and the encryption key must be provided through private deployment configuration; no model weights are committed. If these are absent, biometric endpoints return an unavailable/configuration error rather than synthesizing decisions.

Mobile has role selection, consent/enrollment screens, and a front-camera sweep implementation. A real-device sweep, iOS camera behavior, classroom optical performance, Supabase migration execution, and browser end-to-end attendance have not been verified here. See TODO.md for outstanding evidence and commands/results.

## Components

- apps/mobile/: Flutter Android-first client. Tokens use secure storage; camera captures are submitted as a single multipart attempt.
- apps/dashboard/: canonical React/Vite dashboard, connected to the service; no local demo account or fabricated attendance fallback.
- apps/dashboard-next/: retained duplicate Next.js dashboard pending explicit deletion approval; not the canonical app.
- backend/: FastAPI entrypoint app.main:app, Supabase Auth/Postgres and WebSocket service. app.main_supabase remains a compatibility import, not a separate implementation.
- backend/migrations/: SQL migrations; apply with the approved Supabase migration workflow.
- experiments/panorama_verification/: consented-volunteer manifest runner; no images are included.

## Local setup

1. Configure backend/.env from backend/.env.example with Supabase URL, anon/service keys, JWT secret, encryption key and private model paths. Keep .env and biometric models out of version control.
2. Apply backend/migrations/20261026_attendance_verification.sql to the Supabase project. Configure private storage and retention as documented in docs/PRIVACY_AND_DEPLOYMENT.md.
3. Install backend requirements and run uvicorn app.main:app --reload --port 8000 from backend/.
4. In apps/dashboard/, install dependencies, set VITE_API_BASE_URL, and run npm run dev.
5. In apps/mobile/, run flutter pub get, then run with the API base URL for the emulator/device. See apps/mobile/README.md.

The dashboard-next copy is not used by the application flow. We would remove apps/dashboard-next/ only after explicit approval. The duplicate backend shim is currently retained for import compatibility; consolidate deployment entrypoints to app.main:app before removing it.
