# Attendrix classroom attendance

A review-first classroom attendance system with a Flutter mobile client, responsive web dashboard, and one shared real-time FastAPI API backed by Supabase Auth and PostgreSQL.

## Safety scope

The current implementation uses synthetic, clearly labeled review suggestions. It does **not** perform facial identity recognition, generate biometric templates, retain classroom photos, or make accuracy or compliance claims. Teacher review is required before a record becomes present/absent. Do not enter real student data or use this prototype in a live school setting.

## Components

- `apps/mobile/` — Flutter app for teacher/student use, with Android/iOS/Web scaffolding. The mobile client preserves the backend's UUID string identifiers. A Flutter SDK and Android SDK are not present in this audit sandbox, so native/mobile compilation was not verified here.
- `apps/dashboard/` — React/TypeScript responsive dashboard.
- `backend/` — FastAPI REST + WebSocket service with Supabase Auth/PostgreSQL persistence and role checks.
- `docs/API_CONTRACT.md` — shared endpoint and event details.
- `plan.md`, `TODO.md` — agreed scope and implementation status.

## Run locally

1. Start the API from `backend/`: create a Python virtual environment, install `requirements.txt`, copy `.env.example` to `.env`, then run `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`.
2. Start the dashboard: `cd apps/dashboard && npm install && VITE_API_BASE_URL=http://localhost:8000/api npm run dev`. Use the API's browser-reachable address instead of `localhost` if the dashboard and API run on different machines.
3. Open the Vite URL in a browser and sign in using the demo credentials listed in `docs/API_CONTRACT.md`.
4. For Flutter, run `cd apps/mobile && flutter pub get && flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api` for Android Emulator. For a physical phone, use the host computer's LAN IP and ensure it can reach port 8000. iOS Simulator can use `http://localhost:8000/api`.

Keep the backend, dashboard, and Flutter app pointed at the same API address to share changes in real time. Android emulator, iOS simulator, and physical-device networking may require different base URLs.

## Verification in this sandbox

Backend security and experiment tests pass (`9 passed`), and the dashboard TypeScript/Vite production build succeeds. Flutter analysis, widget tests, and Flutter Web build are pending because this sandbox has no Flutter SDK; native iOS builds require macOS/Xcode.

## Demo credentials

Teacher: `teacher@demo.edu` / `teach123`.

Students: `student1@demo.edu` or `student2@demo.edu` / `student123`.

These credentials and demo CORS configuration are development-only. Production requires approved authentication/MFA, HTTPS/WSS, backups and restore drills, retention and deletion controls, monitoring, access-control review, school-specific legal/privacy review, demographic fairness assessment, and a separately evaluated recognition service if recognition is ever introduced. The requested accuracy/latency figures are evaluation goals, not performance claims. See `docs/DEPLOYMENT.md` and `docs/SECURITY.md`.
