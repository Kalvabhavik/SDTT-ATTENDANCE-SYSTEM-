# Build and integration validation

Validation run: 2026-10-28, in the approved Manus Sandbox, against merged `main` commit `bec9159`.

## Toolchain and results

- Flutter stable 3.47.7 / Dart 3.13.5 installed under `/home/ubuntu/tools/flutter` after the user approved the download.
- `flutter analyze` — no issues.
- `flutter test` — 42 tests passed, including camera, accessibility, network/retry, controller, and UI-state suites.
- `flutter build web` — succeeded; generated `apps/mobile/build/web`.
- Backend `python3 -m pytest -q` — 138 tests passed after installing the declared OpenCV/ONNX dependencies.
- Dashboard `npm run build` — TypeScript check and Vite production build succeeded.
- Backend health endpoint returned HTTP 200 during validation.

## What was not validated

The sandbox does not contain an Android SDK or an attached phone, so no APK build, emulator launch, or native camera hardware behavior test is claimed. Native iOS builds require macOS/Xcode. There was no external public-site deployment or full two-device browser/mobile E2E demonstration. WebSocket authorization and event behavior are covered by backend tests; both client implementations compile against the shared event contract. Screenshot tests write to `ATTENDRIX_PROOF_DIR` when supplied, otherwise to a writable system temporary directory.

## Flutter setup references

The SDK was installed from the official stable Flutter repository/channel, following the official Linux manual installation guide and SDK archive documentation:

- [Install Flutter manually](https://docs.flutter.dev/install/manual)
- [Flutter SDK archive](https://docs.flutter.dev/install/archive)

## Safety and deployment boundary

The merged implementation includes encrypted biometric reference templates, continuous sweep verification, liveness/presentation-attack checks, lecturer review routing, raw-frame purging, audit logging, and manual roll-call fallback. These controls do not guarantee accuracy, legal compliance, or elimination of proxy attendance. Configure institution-approved consent, retention/deletion, access, secret management, database persistence, and fairness evaluation before real student use.
