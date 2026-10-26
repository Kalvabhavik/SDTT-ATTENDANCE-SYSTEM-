# Attendrix Flutter mobile client

Flutter client for the shared Supabase-backed attendance API. The app uses server role checks and secure token storage. DB role remains teacher; the UI says Lecturer.

## Run

    flutter pub get
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

Use 127.0.0.1 for iOS Simulator or the development machine LAN IP for a physical device. Production requires HTTPS/WSS. Front-camera capture uses the camera stream; no gallery picker is used. The sweep attaches frame offsets and gyroscope heading metadata as supporting evidence. Device motion is not proof of presence or liveness.

## Current flow in source

Splash → role selection → selected-role login → consent/enrollment when required → role home. Enrollment checks a camera selfie with the backend. Student active-session card uses server_time offset; the mobile sweep sends one multipart attempt with attempt_id. Lecturer manual roll-call overrides remain available. No demo credentials are prefilled.

A real Android/iOS camera sweep has not been verified in this environment. Confirm native camera and motion permissions, orientation handling, frame encoding, network upload, backend model availability and accessibility on supported devices before a pilot. See the root TODO and privacy documents.
