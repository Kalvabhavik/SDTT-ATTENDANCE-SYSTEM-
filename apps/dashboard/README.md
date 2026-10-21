# Rollcall dashboard

Responsive React + TypeScript + Vite client for the classroom attendance API described in `../../docs/API_CONTRACT.md`.

## Run locally

```bash
cp .env.example .env
npm install
npm run dev
```

The REST base is configurable with `VITE_API_BASE_URL` and defaults to `http://localhost:8000/api`. The client obtains a one-time WebSocket ticket through `POST /auth/ws-ticket`, then connects to `/ws?ticket=...` using `ws`/`wss` derived from the API origin. WebSocket events are informational and trigger resource refreshes.

Demo accounts:

- Teacher: `teacher@demo.edu` / `teach123`
- Student: `student1@demo.edu` / `student123`
- Student: `student2@demo.edu` / `student123`

If the API is not running, the UI offers a local demo fallback after entering one of the demo credentials. Local fallback data is clearly marked and is not sent anywhere. Capture suggestions are synthetic; no image is persisted and this app does not perform facial recognition. It includes no email, SMS, or real FCM push integration.
