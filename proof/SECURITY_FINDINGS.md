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
