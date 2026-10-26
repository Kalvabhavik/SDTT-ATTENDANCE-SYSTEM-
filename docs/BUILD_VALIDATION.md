# Build and integration validation

Environment: Windows PowerShell, Python 3.14.7, Node/npm available. Flutter SDK is not on PATH. No configured Supabase test project or real model files are available.

## Commands run

- py -3 -m py_compile app\main.py app\verification.py app\verification_config.py app\face_engine.py app\verification_pipeline.py tests\test_api.py tests\test_verification_pipeline.py ..\experiments\panorama_verification\run_manifest.py from backend/ — exit 0; Python syntax compilation passed.
- py -3 -m pytest -q from backend/ — exit 1; No module named pytest.
- py -3 -m pip install --target .vendor -r requirements.txt from backend/ — failed with permission denied while reading wheel metadata in the Python temporary directory.
- npx tsc -b --pretty false from apps/dashboard/ — exit 0.
- npm run build -- --configLoader native from apps/dashboard/ — exit 0; TypeScript project build and Vite production build succeeded (1,930 modules transformed).
- npm run build from apps/dashboard/ — TypeScript passed, normal Vite config bundling failed with Windows spawn EPERM. Native config loader succeeds.
- flutter analyze from apps/mobile/ — not run; command not found.
- flutter test from apps/mobile/ — not run; command not found.

## Not run

No browser end-to-end flow, Supabase migration application, Postgres concurrency test, camera emulator/device sweep, iOS build, volunteer-manifest run, classroom evaluation, or real-model verification was possible in this environment. No accuracy, fairness, latency or lecturer-flag rate is claimed.

This file records this environment's check results only. Source implementation and unit test files are not equivalent to passing tests.
