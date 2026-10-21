# Build and integration validation

Validation run: 2026-10-20, in the approved Manus Sandbox.

## Toolchain and results

- Flutter stable 3.47.7 / Dart 3.13.5 installed under `/home/ubuntu/tools/flutter` after the user approved the download.
- `flutter analyze` — no issues.
- `flutter test` — widget login/privacy smoke test passed.
- `flutter build web` — succeeded; generated `apps/mobile/build/web`.
- Backend `.venv/bin/pytest -q` — 4 passed. The test runner emitted a Starlette/httpx deprecation warning from the test-client dependency; tests passed.
- Dashboard `npm run build` — TypeScript check and Vite production build succeeded.
- Backend health endpoint returned HTTP 200 during validation.

## What was not validated

The sandbox does not contain an Android SDK or an attached phone, so no APK build, emulator launch, or native camera behavior test is claimed. Native iOS builds require macOS/Xcode. There was no external public-site deployment or full two-device browser/mobile E2E demonstration. WebSocket authorization and event behavior are covered by backend tests; both client implementations compile against the shared event contract.

## Flutter setup references

The SDK was installed from the official stable Flutter repository/channel, following the official Linux manual installation guide and SDK archive documentation:

- [Install Flutter manually](https://docs.flutter.dev/install/manual)
- [Flutter SDK archive](https://docs.flutter.dev/install/archive)

## Prototype safety boundary

Capture is a simulated suggestion workflow, not face recognition. The API never creates or stores face embeddings and does not persist uploaded images in application storage. Multipart parsing may spool large uploads to request-scoped temporary storage before the request finishes. Teachers must review suggestions and explicitly finalize the session. Do not use real student information or treat this prototype as production school attendance software.
