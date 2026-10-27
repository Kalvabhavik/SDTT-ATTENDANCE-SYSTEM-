# Identity Verification and Anti-Proxy Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish rigorous server-enforced identity verification, anti-proxy protections, concurrency locking, and privacy-compliant biometric handling for student attendance check-ins.

**Architecture:** Enforce a strict multi-layer server-side identity validation pipeline: (1) Cryptographic JWT and student binding eliminating IDOR, (2) Biometric template integrity validation (Fernet AES-128-CBC + model version compatibility + expiration checks), (3) Calibrated decision thresholding distinguishing verified matches ($sim \ge 0.45$), ambiguous matches ($0.35 \le sim < 0.45$) flagged for lecturer review, and distinct live non-matching impostors ($sim < 0.35$), (4) Atomic per-student/session mutex locking and database constraint enforcement preventing duplicate check-in races, and (5) Strict log sanitization preventing leakage of raw embeddings or landmarks.

**Tech Stack:** Python 3.12, FastAPI, OpenCV (YuNet + SFace/ArcFace), Cryptography (Fernet/AES-128-CBC), NumPy, Pytest, Asyncio concurrency locks, Supabase/PostgreSQL schema constraints.

**Spec:** TASK 05 — Identity Verification and Anti-Proxy Integrity (`docs/PRIVACY_AND_DEPLOYMENT.md`, `docs/API_CONTRACT.md`)

## Global Constraints
- Server clock is authoritative; client assertions (`is_live`, `verified`, `confidence`) and client timestamps are untrusted.
- Verification applies strictly to the authenticated student (`user["id"]` from verified JWT) and active open sessions (`status == "open"`).
- Raw biometric vectors (embeddings, landmarks, image arrays) must NEVER be written to application logs or audit logs.
- Fail closed: any model failure, database transaction error, or missing template yields a safe rejection, never an unearned "present".
- Concurrency safety: simultaneous requests for the same student and session must serialize and prevent duplicate records.

## Review Focus
- High-concurrency race condition: simultaneous check-in requests for identical `(session_id, student_id)` bypassing duplicate detection.
- Malformed or tampered biometric ciphertext in `face_templates` triggering unhandled 500 error instead of clean 400 rejection.
- Client attempts to bypass identity verification by supplying another student's `student_id` in form or query parameters (IDOR).
- Low-confidence or borderline matches silently marked "present" rather than being flagged for human proctor/lecturer review.
- Database transaction errors during attendance write leaving phantom attendance records or returning 200 OK.

---

### Task 1: Biometric Enrollment Validation & Error Handling

**Files:**
- Modify: `backend/app/main.py:1880-1910`
- Modify: `backend/app/security.py`
- Test: `backend/tests/test_identity_integrity.py`

**Interfaces:**
- Consumes: `face_templates` table row (`encrypted_embedding`, `model_version`, `consent_timestamp`, `expires_at`).
- Produces: Decrypted embedding `np.ndarray` or raises clean `HTTPException(400, detail="...", headers={"X-Error-Code": "INVALID_ENROLLMENT_DATA"})`.

- [ ] **Step 1: Write tests for missing and invalid enrollment templates**
Test cases: missing template, malformed ciphertext, corrupted embedding dimension, incompatible model version, expired enrollment.

- [ ] **Step 2: Run test to verify it fails**
Run: `pytest backend/tests/test_identity_integrity.py::test_missing_and_invalid_enrollment -v`

- [ ] **Step 3: Implement enrollment template validation in `backend/app/main.py`**
Validate template presence, check `expires_at`, check `model_version` compatibility, handle `InvalidToken` / corrupted decryption gracefully with HTTP 400 `INVALID_ENROLLMENT_DATA`.

- [ ] **Step 4: Run test to verify it passes**
Run: `pytest backend/tests/test_identity_integrity.py::test_missing_and_invalid_enrollment -v`

- [ ] **Step 5: Commit**
```bash
git add backend/app/main.py backend/tests/test_identity_integrity.py
git commit -m "feat(security): validate biometric enrollment integrity and reject malformed templates"
```

---

### Task 2: Student Binding, Anti-IDOR & Session Integrity

**Files:**
- Modify: `backend/app/main.py:1840-1880`
- Test: `backend/tests/test_identity_integrity.py`

**Interfaces:**
- Consumes: Request form fields (`student_id`, `user_id`), challenge token `sub`, JWT `user["id"]`, session status.
- Produces: Strict rejection `HTTPException(403, detail="Unauthorized: Cannot submit attendance for another student [IDOR_ATTEMPT_BLOCKED]")` if client attempts IDOR.

- [ ] **Step 1: Write tests for IDOR, expired session, and replayed requests**
Test cases:
1. Submitting `student_id: other_uuid` in form data -> 403 `IDOR_ATTEMPT_BLOCKED`.
2. Submitting challenge token minted for another student -> 403.
3. Submitting attendance for session with `status == "closed"` or `status == "archived"` -> 400.
4. Replaying identical frame bytes -> 400 `REPLAY_ATTACK_DETECTED`.
5. Reusing challenge nonce -> 400 `Challenge token has already been used`.

- [ ] **Step 2: Run test to verify it fails**
Run: `pytest backend/tests/test_identity_integrity.py::test_student_binding_and_idor -v`

- [ ] **Step 3: Implement IDOR verification and strict session validation in `backend/app/main.py`**
Explicitly check client-supplied `student_id`/`user_id` against `user["id"]`. Reject with HTTP 403 if mismatched.

- [ ] **Step 4: Run test to verify it passes**
Run: `pytest backend/tests/test_identity_integrity.py::test_student_binding_and_idor -v`

- [ ] **Step 5: Commit**
```bash
git add backend/app/main.py backend/tests/test_identity_integrity.py
git commit -m "feat(security): enforce anti-IDOR check and strict session binding"
```

---

### Task 3: Calibrated Decision Thresholds & Ambiguous Match Handling

**Files:**
- Modify: `backend/app/main.py:2015-2045`, `backend/app/main.py:2120-2145`
- Test: `backend/tests/test_identity_integrity.py`

**Interfaces:**
- Consumes: Cosine similarity score $sim$.
- Produces: Multi-tier decision:
  - $sim \ge 0.45$: `face_matched = True`, `final_status = "present"`.
  - $0.35 \le sim < 0.45$: `face_matched = False`, `final_status = "pending"`, flagged for review (`AMBIGUOUS_BIOMETRIC_MATCH`).
  - $sim < 0.35$: `face_matched = False`, `final_status = "absent"`.
  - Poor image quality: HTTP 400 with `IMAGE_QUALITY_*`.

- [ ] **Step 1: Write tests for calibrated match thresholds and poor image quality**
Test cases:
1. Correct live enrolled student -> `present`, `face_match=True`.
2. Poor-quality capture (blurred / dark) -> HTTP 400 `IMAGE_QUALITY_BLURRY` or `IMAGE_QUALITY_LOW_LIGHT`.
3. Live non-matching person -> `absent`, `face_match=False`.
4. Ambiguous / low-confidence match ($0.38$) -> `pending`, `face_match=False`, flagged for lecturer review.

- [ ] **Step 2: Run test to verify it fails**
Run: `pytest backend/tests/test_identity_integrity.py::test_calibrated_match_thresholds -v`

- [ ] **Step 3: Implement calibrated threshold logic in `backend/app/main.py`**
Add ambiguous tier ($0.35 \le sim < 0.45$) routing to `"pending"` with review flag.

- [ ] **Step 4: Run test to verify it passes**
Run: `pytest backend/tests/test_identity_integrity.py::test_calibrated_match_thresholds -v`

- [ ] **Step 5: Commit**
```bash
git add backend/app/main.py backend/tests/test_identity_integrity.py
git commit -m "feat(security): calibrate verification thresholds with ambiguous match review tier"
```

---

### Task 4: Concurrency Locks & Database Transaction Integrity

**Files:**
- Modify: `backend/app/main.py`
- Modify: `backend/app/db.py`
- Test: `backend/tests/test_identity_integrity.py`

**Interfaces:**
- Consumes: `session_id`, `student_id`.
- Produces: Atomic serialization via per-key `asyncio.Lock` and database transactional handling.

- [ ] **Step 1: Write tests for concurrency race conditions and database transaction errors**
Test cases:
1. Duplicate sequential attendance submission -> HTTP 400 `ATTEMPT_LIMIT_REACHED`.
2. Simultaneous requests (5 parallel requests for same student/session) -> exactly 1 succeeds, others receive HTTP 400 `ATTEMPT_LIMIT_REACHED`.
3. Database transaction failure during write -> fails closed, HTTP 500/503, audit logged, no phantom attendance record.

- [ ] **Step 2: Run test to verify it fails**
Run: `pytest backend/tests/test_identity_integrity.py::test_concurrency_and_transaction_failure -v`

- [ ] **Step 3: Implement atomic lock manager and transactional exception handling**
Create `_attendance_locks: dict[tuple[str, str], asyncio.Lock]` and acquire lock during `verify_student_live_attendance`. Wrap DB write in transaction error handler that fails closed.

- [ ] **Step 4: Run test to verify it passes**
Run: `pytest backend/tests/test_identity_integrity.py::test_concurrency_and_transaction_failure -v`

- [ ] **Step 5: Commit**
```bash
git add backend/app/main.py backend/app/db.py backend/tests/test_identity_integrity.py
git commit -m "feat(security): implement concurrency locking and transactional fail-closed handling"
```

---

### Task 5: Biometric Privacy Compliance & Ordinary Log Sanitization

**Files:**
- Modify: `backend/app/main.py`
- Modify: `backend/app/face_engine.py`
- Modify: `backend/app/verification.py`
- Test: `backend/tests/test_identity_integrity.py`

**Interfaces:**
- Consumes: Log records across application.
- Produces: Verified absence of raw embedding vectors, landmark arrays, or image buffers from ordinary logs.

- [ ] **Step 1: Write test auditing log messages for biometric data leakage**
Test captures log output during enrollment and verification and asserts no raw embedding vectors or landmark tuples exist in log text.

- [ ] **Step 2: Run test to verify it passes or flags any existing leakage**
Run: `pytest backend/tests/test_identity_integrity.py::test_biometric_log_sanitization -v`

- [ ] **Step 3: Sanitize all logging and metadata**
Ensure embeddings and landmark coordinates are never converted to string or included in log calls or audit metadata.

- [ ] **Step 4: Run test to verify it passes**
Run: `pytest backend/tests/test_identity_integrity.py::test_biometric_log_sanitization -v`

- [ ] **Step 5: Commit**
```bash
git add backend/app/main.py backend/app/face_engine.py backend/tests/test_identity_integrity.py
git commit -m "feat(privacy): sanitize application and audit logs to prevent biometric data leakage"
```

---

### Task 6: Visual Evidence Generation & Documentation Update

**Files:**
- Create: `proof/scripts/generate_identity_integrity_evidence.py`
- Create: `proof/screenshots/05_identity_integrity/` (generated artifacts)
- Modify: `proof/TEST_CASES.md`
- Modify: `proof/TEST_RESULTS.md`
- Modify: `proof/SECURITY_FINDINGS.md`

- [ ] **Step 1: Generate visual evidence artifacts**
Run python script to produce diagram cards in `proof/screenshots/05_identity_integrity/`.

- [ ] **Step 2: Update documentation**
Document test cases TC-ID-001 through TC-ID-013, test results, security findings SEC-012 through SEC-015.

- [ ] **Step 3: Run entire backend and mobile test suites to confirm zero regressions**
Run: `pytest backend/tests/ -v`
Run: `flutter test test/camera_reliability_test.dart test/ui_states_test.dart test/widget_test.dart`

- [ ] **Step 4: Commit and push branch `feat/attendrix-identity-integrity`**
Commit all changes and push to origin.
