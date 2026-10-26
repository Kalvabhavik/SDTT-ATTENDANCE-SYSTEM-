# FastAPI attendance service

The backend uses FastAPI, Supabase Auth and Supabase Postgres. Deploy the single ASGI entrypoint app.main:app. app.main_supabase remains a compatibility import.

## Configure and run

Copy .env.example to .env and configure Supabase URL/keys, JWT secret, Fernet template-encryption key, and private YuNet/ArcFace model paths. Apply SQL through the Supabase migration workflow before launching. From this directory:

    pip install -r requirements.txt
    uvicorn app.main:app --reload --port 8000

Without a configured Supabase project, keys, private face models and encryption key, the service cannot perform production authentication/enrollment/verification. It deliberately has no mock identity or synthetic confidence fallback.

## Verification and privacy

- The service verifies the authenticated Supabase identity and profile role; selected login role must match.
- Session timing and attendance decisions use backend timestamps and state.
- Templates are encrypted; enrollment responses never expose embeddings. Flagged evidence is stored in a private bucket with configured expiration.
- The old capture route is retired with HTTP 410. Lecturer manual attendance remains available and audited.
- See ../docs/API_CONTRACT.md, ../docs/PRIVACY_AND_DEPLOYMENT.md, and ../TODO.md.

Test files are in tests/. Exact commands and environment results are documented in ../docs/BUILD_VALIDATION.md. The legacy suggestions table is unused and has not been destructively dropped.
