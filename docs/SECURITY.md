# Security and privacy controls

## Implemented

- Supabase-issued bearer tokens are verified with the configured JWT secret, HS256 algorithm, expiry, and `authenticated` audience. Unverified claim decoding is not permitted.
- Role and resource checks are enforced server-side; client role values are never trusted for authorization.
- Login attempts are rate-limited per client address and normalized email within the API process. Production deployments should also apply distributed edge rate limiting because multiple workers do not share this in-memory counter.
- Capture uploads are bounded by bytes, MIME type, decoded dimensions, pixel count, and actual image parsing. Arbitrary bytes are rejected before processing.
- WebSocket authentication uses short-lived, single-use tickets instead of access tokens in the URL.
- API responses include request IDs and baseline browser security headers; production adds HSTS.
- Service containers run as non-root with no added capabilities and read-only storage in the supplied Compose baseline.
- The dashboard's synthetic local fallback is disabled unless `VITE_ENABLE_DEMO_MODE=true` is explicitly configured.
- Captured files and biometric templates are not persisted by the current prototype, and synthetic suggestions are visibly labeled as synthetic.

## Required before real institutional use

This code is not a legal compliance certification and does not establish recognition accuracy, fairness, fraud resistance, or suitability for minors. Before live use, complete institutional privacy/legal review, consent and withdrawal workflows, data-subject export/deletion procedures, MFA or an approved identity provider, formal threat modeling, security testing, backup/restore drills, and an incident response plan.

The current system does not implement actual face detection or enrolled-identity recognition, liveness, capture evidence retention/deletion, verification claims, admin role management, or a background job queue. Do not add those capabilities by returning fabricated matches. Introduce a versioned model interface, consented evaluation dataset, calibrated thresholds, ambiguous-match state, model governance, and private evidence lifecycle only after those controls are approved.

Never log passwords, bearer tokens, raw images, face crops, embeddings, signed private URLs, or full request bodies. Keep audit metadata minimal and access-controlled.
