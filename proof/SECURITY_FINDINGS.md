# Attendrix Biometric & Application Security Findings
**System:** Attendrix Computer-Vision Attendance System  
**Audit Date:** 2026-10-27  
**Status:** All Critical and High findings Remediated and Verified  

---

## Vulnerability Overview Matrix

| Finding ID | Title | Severity | Affected Component | Status | Retest Reference |
| :--- | :--- | :---: | :--- | :---: | :--- |
| `SEC-001` | Static Photo Active Liveness Bypass | **CRITICAL** | `backend/app/face_engine.py` | **RESOLVED** | `TC-SPOOF-001` |
| `SEC-002` | Permissive Fallback Generates Fake Face on Empty Walls | **HIGH** | `backend/app/face_engine.py` | **RESOLVED** | `TC-EDGE-001` |
| `SEC-003` | Attendance Image Replay Attack Vulnerability | **HIGH** | `backend/app/main.py` & `security.py` | **RESOLVED** | `TC-SPOOF-002`, `TC-SPOOF-003` |
| `SEC-004` | Unsigned / Reusable Active Liveness Challenges | **HIGH** | `backend/app/main.py` & `security.py` | **RESOLVED** | `TC-API-003`, `TC-API-004` |
| `SEC-005` | Corrupted Face Embedding Model Causing Fallback Degradation | **HIGH** | `backend/app/models/face_recognition_sface.onnx` | **RESOLVED** | `TC-PERF-001` |
| `SEC-006` | Lack of Image Quality Screening (Blur/Darkness) | **MEDIUM** | `backend/app/face_engine.py` | **RESOLVED** | `TC-EDGE-002`, `TC-EDGE-003` |
| `SEC-007` | Student-Lecturer Endpoint Authorization Bypasses | **MEDIUM** | `backend/app/main.py` | **RESOLVED** | `TC-API-002` |
| `SEC-008` | Client-Supplied Verification Bypass Vulnerability | **CRITICAL** | `backend/app/main.py` | **RESOLVED** | `TC-ADV-011` |
| `SEC-009` | Static Inter-Frame Multi-Frame Challenge Replay | **HIGH** | `backend/app/face_engine.py` | **RESOLVED** | `TC-ADV-005` |
| `SEC-010` | Model Runtime Exception / Timeout Fail-Open Risk | **HIGH** | `backend/app/main.py` | **RESOLVED** | `TC-ADV-011` |
| `SEC-011` | Digital Screen Replay & Print Halftone Presentation Attacks | **HIGH** | `backend/app/face_engine.py` | **RESOLVED** | `TC-ADV-003`, `TC-ADV-004` |
| `SEC-012` | High-Concurrency Duplicate Attendance Race Condition | **HIGH** | `backend/app/main.py` | **RESOLVED** | `TC-ID-012` |
| `SEC-013` | Insecure Direct Object Reference (IDOR) on Student Check-in | **HIGH** | `backend/app/main.py` | **RESOLVED** | `TC-ID-014` |
| `SEC-014` | Unhandled 500 Crash on Corrupted / Incompatible Enrollment Biometrics | **MEDIUM** | `backend/app/main.py` | **RESOLVED** | `TC-ID-005`, `TC-ID-006` |
| `SEC-015` | Biometric Leakage and Database Fail-Open Vulnerability | **MEDIUM** | `backend/app/main.py` | **RESOLVED** | `TC-ID-013`, `TC-ID-015` |

---

## Detailed Findings & Remediation Records

### SEC-001: Static Photo Active Liveness Bypass
- **Finding ID:** `SEC-001`
- **Severity:** **CRITICAL** (CVSS 9.1: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** An attacker could submit a single static 2D photograph of an enrolled student without performing head turns or blinks. If optional challenge frames were omitted, the engine defaulted `challenges_passed = True`, marking proxy attendance.
- **Affected Component:** `backend/app/face_engine.py` (`verify_active_liveness`), `backend/app/main.py`.
- **Reproduction Steps:**
  1. Login as enrolled student.
  2. Send `POST /api/sessions/{session_id}/verify-attendance` with `face_image` containing static portrait and `face_left=None, face_right=None, face_blink=None`.
  3. Observe verification outcome.
- **Expected Behaviour:** System must reject the submission because active liveness was not demonstrated (`liveness_passed = False`).
- **Actual Behaviour (Pre-Fix):** Liveness returned `True`; attendance marked `present`.
- **Remediation:** Enforced dynamic challenge requirements. If challenges are required or active challenges are omitted, the engine returns `liveness_passed = False` with `NO_ACTIVE_CHALLENGES_PROVIDED`.
- **Retest Result:** **RESOLVED** — Verified via `TC-SPOOF-001`.

---

### SEC-002: Permissive Fallback Generates Fake Face on Non-Face Surfaces
- **Finding ID:** `SEC-002`
- **Severity:** **HIGH** (CVSS 7.5: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** A legacy fallback in `RealFaceEngine.detect_faces` generated synthetic face bounding boxes on any image with `mean_luminance >= 4.0` and `laplacian_var >= 0.5`. An attacker pointing the camera at a table or blank wall was treated as a human face.
- **Affected Component:** `backend/app/face_engine.py` (`detect_faces`).
- **Reproduction Steps:**
  1. Capture photo of textured blank wall or desk.
  2. Call `detect_faces` with strict biometrics.
  3. Observe detected face list.
- **Expected Behaviour:** 0 faces detected.
- **Actual Behaviour (Pre-Fix):** 1 face detected at center (70% width, 75% height) with confidence 0.85.
- **Remediation:** Restricted fallback strictly to mock testing environments where `allow_fallback=True` is explicitly passed; production and strict biometrics enforce real neural network inference with YuNet.
- **Retest Result:** **RESOLVED** — Verified via `TC-EDGE-001`.

---

### SEC-003: Attendance Image Replay Attack Vulnerability
- **Finding ID:** `SEC-003`
- **Severity:** **HIGH** (CVSS 7.5: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** Submitting intercepted capture frames repeatedly allowed an attacker to reuse legitimate check-in photos across different sessions or students.
- **Affected Component:** `backend/app/main.py` (`verify_student_live_attendance`), `backend/app/security.py`.
- **Reproduction Steps:**
  1. Capture network payload from legitimate student check-in.
  2. Re-send identical byte payload in second verification attempt.
- **Expected Behaviour:** System rejects the reused payload with HTTP 400.
- **Actual Behaviour (Pre-Fix):** Accepted repeatedly as fresh live captures.
- **Remediation:** Implemented two-tiered replay defense:
  1. Exact SHA-256 byte deduplication cache.
  2. DCT 64-bit Perceptual Hash (pHash) cache rejecting captures with Hamming distance $\le 3$.
- **Retest Result:** **RESOLVED** — Verified via `TC-SPOOF-002` and `TC-SPOOF-003`.

---

### SEC-004: Unsigned / Reusable Active Liveness Challenges
- **Finding ID:** `SEC-004`
- **Severity:** **HIGH** (CVSS 7.2: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** Challenges were not cryptographically bound to the session, student, or issuance timestamp. An attacker could pre-record a fixed sequence or replay tokens.
- **Affected Component:** `backend/app/main.py`, `backend/app/security.py`.
- **Reproduction Steps:**
  1. Obtain challenge token issued for Student A.
  2. Submit token using Student B's authentication credentials.
  3. Re-submit token a second time after consumption.
- **Expected Behaviour:** Student B rejected with HTTP 403; second submission rejected with HTTP 400 (nonce consumed).
- **Actual Behaviour (Pre-Fix):** No challenge signing or nonce tracking existed.
- **Remediation:** Added `POST /api/sessions/{session_id}/liveness-challenge` issuing HMAC-SHA256 tokens encoding `sub`, `session_id`, `nonce`, `challenges`, and `exp` (90s TTL). Added single-use nonce tracking in `consume_challenge_nonce`.
- **Retest Result:** **RESOLVED** — Verified via `TC-API-003` and `TC-API-004`.

---

### SEC-005: Corrupted SFace Recognition ONNX Model File
- **Finding ID:** `SEC-005`
- **Severity:** **HIGH** (CVSS 7.0: AV:L/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:H)
- **Rationale:** `backend/app/models/face_recognition_sface.onnx` was corrupt (invalid protobuf error on startup), causing the engine to fall back to heuristic embeddings.
- **Affected Component:** `backend/app/models/face_recognition_sface.onnx`, `face_engine.py`.
- **Reproduction Steps:**
  1. Run `cv2.FaceRecognizerSF.create(model="face_recognition_sface.onnx", config="")`.
- **Expected Behaviour:** Model initializes successfully.
- **Actual Behaviour (Pre-Fix):** Threw `cv2.error: OpenCV(5.0.0) ... INVALID_PROTOBUF`.
- **Remediation:** Installed official OpenCV Zoo `face_recognition_sface_2021dec.onnx` (36.9 MB) and verified 128D deep aligned embedding extraction.
- **Retest Result:** **RESOLVED** — Verified via `TC-PERF-001`.

---

### SEC-006: Lack of Image Quality Screening (Blur/Darkness)
- **Finding ID:** `SEC-006`
- **Severity:** **MEDIUM** (CVSS 5.3: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:L/A:N)
- **Rationale:** Very blurry, overexposed, or pitch-black images proceeded to deep feature matching, increasing biometric false rejection or unpredictable distance metrics.
- **Affected Component:** `backend/app/face_engine.py` (`check_image_quality`).
- **Reproduction Steps:**
  1. Submit blurred frame (Laplacian variance < 15.0).
- **Expected Behaviour:** Reject immediately with guidance to hold device steady.
- **Actual Behaviour (Pre-Fix):** Processed through recognizer.
- **Remediation:** Added `check_image_quality` screening:
  - Laplacian variance threshold $\ge 35.0$
  - Mean luminance $[30.0, 230.0]$
  - Contrast standard deviation $\ge 15.0$
  - Minimum face resolution $120 \times 120$
  - Boundary clipping check ($\ge 3$px margin)
- **Retest Result:** **RESOLVED** — Verified via `TC-EDGE-002`, `TC-EDGE-003`, and `TC-EDGE-004`.

---

### SEC-007: Student-Lecturer Endpoint Authorization Bypasses
- **Finding ID:** `SEC-007`
- **Severity:** **MEDIUM** (CVSS 6.5: AV:N/AC:L/PR:L/UI:N/S:U/C:L/I:L/A:N)
- **Rationale:** Students could invoke administrative teacher session APIs if authorization role checks were omitted.
- **Affected Component:** `backend/app/main.py`.
- **Reproduction Steps:**
  1. Authenticate with student credentials.
  2. Call `POST /api/sessions` or `POST /api/sessions/{id}/finalize`.
- **Expected Behaviour:** HTTP 403 Forbidden.
- **Actual Behaviour:** Enforced via `require_teacher` dependency guards.
- **Remediation:** Added strict `require_teacher`, `require_student`, and `require_controller` RBAC guards.
- **Retest Result:** **RESOLVED** — Verified via `TC-API-002`.

---

### SEC-008: Client-Supplied Verification Bypass Vulnerability
- **Finding ID:** `SEC-008`
- **Severity:** **CRITICAL** (CVSS 9.8: AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H)
- **Rationale:** A malicious client or proxy tool could pass untrusted assertion parameters (`is_live=True`, `verified=True`, `confidence=1.0`) in the multipart form payload, attempting to bypass server-side computer vision inference.
- **Affected Component:** `backend/app/main.py` (`verify_student_live_attendance`, `verify_student_liveness_only`).
- **Reproduction Steps:**
  1. Intercept verification request in mobile client or HTTP proxy.
  2. Inject form fields: `is_live=true`, `verified=true`, `confidence=0.999`.
  3. Observe server response.
- **Expected Behaviour:** Server strictly ignores all client-supplied authorization flags and authoritatively performs server-side CV pipeline execution on raw submitted image bytes.
- **Actual Behaviour (Post-Fix):** Server logs security warning: `"Client submitted bypass assertions... Disregarded per security policy: Only server-side CV inference authorizes attendance."` Real facial match and liveness inference executed.
- **Remediation:** Explicitly accepted untrusted client assertion parameters in endpoint signatures and strictly excluded them from decision logic. Server response calculates `liveness_passed` and `face_match` strictly from OpenCV DNN inference.
- **Retest Result:** **RESOLVED** — Verified via `TC-ADV-011`.

---

### SEC-009: Static Inter-Frame Multi-Frame Challenge Replay
- **Finding ID:** `SEC-009`
- **Severity:** **HIGH** (CVSS 7.5: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** While active challenge tokens required multi-frame submissions (`face_left`, `face_right`, `face_blink`), an attacker could submit the exact same static photo 4 times in one request and hope to bypass motion checks.
- **Affected Component:** `backend/app/face_engine.py` (`verify_active_liveness`).
- **Reproduction Steps:**
  1. Obtain active challenge token demanding `turn_left`.
  2. Send identical frontal photo in both `face_image` and `face_left`.
- **Expected Behaviour:** Engine detects zero inter-frame motion and rejects the duplicate frame submission.
- **Actual Behaviour (Pre-Fix):** If landmark estimation fell back, static duplicate frames were not explicitly compared.
- **Remediation:** Implemented L1 inter-frame pixel difference analysis between challenge frames and the anchor frontal image. If mean absolute pixel difference $< 0.25$, the submission is immediately rejected with `STATIC_IMAGE_REPLAY_ACROSS_CHALLENGES`.
- **Retest Result:** **RESOLVED** — Verified via `TC-ADV-005`.

---

### SEC-010: Model Runtime Exception / Timeout Fail-Open Risk
- **Finding ID:** `SEC-010`
- **Severity:** **HIGH** (CVSS 7.5: AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** If OpenCV DNN crashed, ran out of memory, or timed out during face detection or embedding extraction, an unhandled exception could cause undefined behavior or fail open if default statuses were improperly initialized.
- **Affected Component:** `backend/app/main.py` (`verify_student_live_attendance`).
- **Reproduction Steps:**
  1. Simulate engine failure by raising `RuntimeError` in `detect_faces`.
  2. Send verification request.
- **Expected Behaviour:** Fails closed with HTTP 503 `MODEL_UNAVAILABLE`, zero attendance granted, audit log recorded.
- **Actual Behaviour (Post-Fix):** Returns HTTP 503 `MODEL_UNAVAILABLE` with `X-Error-Code: MODEL_UNAVAILABLE` and logs `attendance.verification_error`.
- **Remediation:** Wrapped the computer vision pipeline in a fail-closed `try...except` circuit that catches all model exceptions/timeouts and raises HTTP 503 without creating any attendance record or granting proxy access.
- **Retest Result:** **RESOLVED** — Verified via `TC-ADV-011`.

---

### SEC-011: Digital Screen Replay & Print Halftone Presentation Attacks
- **Finding ID:** `SEC-011`
- **Severity:** **HIGH** (CVSS 7.2: AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N)
- **Rationale:** Single-frame face detection models do not differentiate between real human skin and high-resolution screen displays or paper printouts.
- **Affected Component:** `backend/app/face_engine.py` (`detect_presentation_attack`).
- **Reproduction Steps:**
  1. Display face photo on iPad/monitor with periodic subpixel raster grid.
  2. Present printed photograph with low saturation.
- **Expected Behaviour:** Passive presentation attack detection flags screen moiré or print halftone.
- **Actual Behaviour (Post-Fix):**
  - Screen moiré detected via 2D FFT spectral peak-to-mean ratio (`SPMR > 1.85`).
  - Print attack detected via HSV saturation mean ($< 8.0$) and YCrCb chrominance variance ($< 2.5$).
  - Planar glare detected via saturated specular reflection ratio ($> 0.08$).
- **Remediation:** Enhanced `detect_presentation_attack` with 2D FFT spectral analysis, HSV/YCrCb chrominance gamut analysis, and specular glare detection.
- **Retest Result:** **RESOLVED** — Verified via `TC-ADV-003` and `TC-ADV-004`.

---

### SEC-012: High-Concurrency Duplicate Attendance Race Condition
- **Finding ID:** `SEC-012`
- **Severity:** **HIGH** (CVSS 7.4: AV:N/AC:H/PR:L/UI:N/S:U/C:N/I:H/A:N, CWE-362)
- **Rationale:** If multiple check-in requests for the same student and session arrived simultaneously, both could read the `attendance` table before either wrote, bypassing the strict 1-attempt policy.
- **Affected Component:** `backend/app/main.py` (`verify_student_live_attendance`).
- **Reproduction Steps:**
  1. Dispatch 5 simultaneous threads submitting distinct valid frame captures for identical `(session_id, student_id)` at $T=0\text{ms}$.
- **Expected Behaviour:** Exactly 1 request succeeds; 4 requests are blocked; exactly 1 row persists in `attendance`.
- **Actual Behaviour (Pre-Fix):** Multiple concurrent requests passed verification and overwrote or created multiple check-in attempts.
- **Remediation:** Implemented per-`(session_id, student_id)` mutex locking registry (`_get_attendance_lock`). File bytes are read asynchronously before acquiring the mutex, and all verification and database read/write actions execute inside `with att_lock:`. Subsequent requests detect `attempted=True` and reject immediately with HTTP 400 `ATTEMPT_LIMIT_REACHED`.
- **Retest Result:** **RESOLVED** — Verified via `TC-ID-012`.

---

### SEC-013: Insecure Direct Object Reference (IDOR) on Student Check-in
- **Finding ID:** `SEC-013`
- **Severity:** **HIGH** (CVSS 7.5: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:H/A:N, CWE-639)
- **Rationale:** An attacker could attempt to submit attendance on behalf of another student by passing `student_id` or `user_id` form parameters, or by reusing a challenge token issued for another student.
- **Affected Component:** `backend/app/main.py` (`verify_student_live_attendance`).
- **Reproduction Steps:**
  1. Authenticate as Student A.
  2. Send `POST /api/sessions/{session_id}/verify-attendance` with `student_id: student_b_uuid`.
- **Expected Behaviour:** Request blocked with HTTP 403 Forbidden `IDOR_ATTEMPT_BLOCKED`.
- **Actual Behaviour (Pre-Fix):** Client-supplied student IDs were either silently disregarded or could permit IDOR impersonation.
- **Remediation:** Explicitly inspect incoming form parameters `student_id` and `user_id`. If supplied and not equal to `user["id"]` from the cryptographically verified JWT, raise HTTP 403 `IDOR_ATTEMPT_BLOCKED` and audit `security.idor_attempt_blocked`. Also verify `token_payload["sub"] == user["id"]`.
- **Retest Result:** **RESOLVED** — Verified via `TC-ID-014`.

---

### SEC-014: Unhandled 500 Crash on Corrupted / Incompatible Enrollment Biometrics
- **Finding ID:** `SEC-014`
- **Severity:** **MEDIUM** (CVSS 5.3: AV:N/AC:L/PR:L/UI:N/S:U/C:N/I:N/A:L, CWE-209 / CWE-755)
- **Rationale:** Corrupted Fernet ciphertext, invalid expiration timestamps, or model version incompatibilities (such as dimension mismatches between 512-dim ArcFace and 128-dim SFace) caused unhandled exceptions and internal server errors.
- **Affected Component:** `backend/app/main.py` (`verify_student_live_attendance`).
- **Reproduction Steps:**
  1. Insert corrupted ciphertext or incompatible model version (`unsupported-v0`) into `face_templates`.
  2. Submit attendance verification.
- **Expected Behaviour:** Fails closed with clean HTTP 400 and explicit error headers (`INVALID_ENROLLMENT_DATA` or `EXPIRED_ENROLLMENT_DATA`).
- **Actual Behaviour (Pre-Fix):** Server crashed with 500 Internal Server Error or unhandled `InvalidToken`.
- **Remediation:** Added comprehensive pre-inference enrollment template validation: checks record existence, validates `expires_at`, checks `model_version` against supported whitelist, catches decryption failures, and verifies vector dimensions before computing cosine similarity.
- **Retest Result:** **RESOLVED** — Verified via `TC-ID-004`, `TC-ID-005`, and `TC-ID-006`.

---

### SEC-015: Biometric Leakage and Database Fail-Open Vulnerability
- **Finding ID:** `SEC-015`
- **Severity:** **MEDIUM** (CVSS 5.3: AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N, CWE-532 / CWE-200)
- **Rationale:** Raw floating point vectors (128/512-dim embeddings), facial landmark tuples, or raw image buffers could potentially be written into ordinary application logs or audit metadata JSON. Furthermore, an unhandled database transaction failure could leave attendance status uncertain.
- **Affected Component:** `backend/app/main.py` (`_audit`, `verify_student_live_attendance`).
- **Reproduction Steps:**
  1. Audit application log statements during enrollment and verification.
  2. Simulate database transaction failure during `db.table("attendance").insert/update`.
- **Expected Behaviour:** Zero raw biometric vectors logged; database error fails closed with HTTP 500/503 and zero phantom records.
- **Actual Behaviour (Pre-Fix):** Audit metadata was not explicitly filtered for large float arrays; DB transaction failure crashed without structured fail-closed handling.
- **Remediation:** Implemented `_sanitize_audit_metadata` to automatically strip arrays > 20 floats and sensitive biometric keys. Wrapped database persistence in try-except block that audits `attendance.transaction_failed` and returns HTTP 500 `DATABASE_TRANSACTION_FAILED`. Verified log sanitization with automated log inspection test.
- **Retest Result:** **RESOLVED** — Verified via `TC-ID-013` and `TC-ID-015`.


