# Attendrix Test Case Specification & Matrix
**Project:** Attendrix Computer-Vision Biometric Attendance System  
**Version:** 2.4.0  
**Updated:** 2026-10-27  
**Test Harness:** Pytest 8.4.2 / Flutter Test / OpenCV YuNet & SFace ONNX  

---

## 1. Test ID Convention

- `TC-FUNC-XXX`: Category A — Core Functional Verification & Session Lifecycle
- `TC-EDGE-XXX`: Category B — Face & Image Quality Edge Cases
- `TC-SPOOF-XXX`: Category C — Presentation Attack Detection (PAD), Spoofing & Replay Resistance
- `TC-API-XXX`: Category D — API Security, Token Validation, Authentication & Concurrency
- `TC-MOB-XXX`: Category E — Flutter Mobile Application & Camera Hardware Edge Cases
- `TC-PERF-XXX`: Category F — Performance, CPU/Memory Benchmark & Concurrency
- `TC-ACC-XXX`: Category G — Biometric Accuracy, Fairness & Operational Limits

---

## Category A — Functional Testing

### TC-FUNC-001: Biometric Enrollment & Encryption
- **Category:** Category A — Functional Testing
- **Objective:** Verify that an unenrolled student can capture a reference selfie, extract a 512D biometric embedding, encrypt it via AES-GCM Fernet, and lock registration against future unauthorized updates.
- **Preconditions:** Student user exists in database with `registration_locked = False` and no existing template.
- **Inputs & Setup:** Student authentication bearer token, synthetic/real frontal face JPEG image (320x320), consent flag `consent=true`.
- **Execution Steps:**
  1. Authenticate as `student1@demo.edu`.
  2. Send `POST /api/auth/enroll` with multipart photo and `consent="true"`.
  3. Query `face_templates` table in database for `user_id`.
  4. Verify encryption ciphertext format and profile `registration_locked == True`.
- **Expected Result:** HTTP 200, status `'enrolled'`, database persists encrypted embedding ciphertext, registration locked.
- **Actual Result:** HTTP 200, status `'enrolled'`, encrypted embedding stored, subsequent enrollments rejected with HTTP 400.
- **Pass/Fail Criteria:** Pass if HTTP 200, template stored, encrypted with AES-GCM.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_func_001_biometric_enrollment_success), `proof/logs/test_runner/test_run.log`
- **Defect Reference:** N/A

---

### TC-FUNC-002: Dynamic Challenge Generation & Live Attendance Verification
- **Category:** Category A — Functional Testing
- **Objective:** Verify end-to-end attendance flow where student requests server-signed challenge token, performs active yaw/blink challenges, and verifies presence.
- **Preconditions:** Enrolled student, active open lecture session created by lecturer.
- **Inputs & Setup:** Active session ID `session_id`, student JWT, signed HMAC-SHA256 challenge token.
- **Execution Steps:**
  1. Teacher creates session via `POST /api/sessions`.
  2. Student calls `POST /api/sessions/{session_id}/liveness-challenge` to obtain signed single-use challenge token.
  3. Student submits `face_image`, `face_left`, `face_right`, `face_blink`, and `challenge_token` to `POST /api/sessions/{session_id}/verify-attendance`.
  4. Inspect response payload and database attendance record.
- **Expected Result:** HTTP 200, `liveness_passed = True`, `face_match = True`, attendance record status marked `present`.
- **Actual Result:** HTTP 200, attendance status recorded as `present`, audit log records `attendance.verified_live`.
- **Pass/Fail Criteria:** Pass if token is verified, active liveness challenges confirmed, and attendance marked `present`.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_func_002_live_student_attendance_with_challenge_pass), `proof/logs/test_runner/test_run.log`
- **Defect Reference:** DEF-SEC-001, DEF-SEC-004

---

### TC-FUNC-003: Empty Room Proxy Attendance Detection
- **Category:** Category A — Functional Testing
- **Objective:** Verify that a student submitting attendance with an empty room photo (0 faces in panorama) is flagged and NOT marked present.
- **Preconditions:** Open session, enrolled student.
- **Inputs & Setup:** Valid student selfie, empty room panorama (0 faces detected).
- **Execution Steps:**
  1. Student submits valid live face selfie with an empty hall photo.
  2. Backend runs `analyze_classroom_panorama` with strict no-fallback detector.
  3. Inspect verification response and audit log.
- **Expected Result:** Attendance status is set to `pending`, `is_empty_room = True`, audit log records `attendance.empty_room_proxy_detected`.
- **Actual Result:** HTTP 200, `status = "pending"`, `is_empty_room = True`, proxy blocked.
- **Pass/Fail Criteria:** Pass if student is NOT marked present and empty room proxy flag is raised.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_empty_room_proxy_attempt_is_blocked_and_flagged)
- **Defect Reference:** N/A

---

## Category B — Face and Image Quality Edge Cases

### TC-EDGE-001: No Face Detected in Scan Frame
- **Category:** Category B — Face and Image Edge Cases
- **Objective:** Verify that uniform surfaces, backgrounds, or textures without human faces are rejected cleanly.
- **Preconditions:** RealFaceEngine initialized with strict mode (`allow_fallback=False`).
- **Inputs & Setup:** Image of blank wall / desk texture (320x320 pixels, mean luminance 180).
- **Execution Steps:**
  1. Call `engine.detect_faces(empty_wall, allow_fallback=False)`.
  2. Call `engine.verify_active_liveness(empty_wall, allow_fallback=False)`.
- **Expected Result:** 0 faces detected, `liveness_passed = False`, `reason = "IMAGE_QUALITY_NO_FACE"`.
- **Actual Result:** 0 faces detected, rejected with `IMAGE_QUALITY_NO_FACE`.
- **Pass/Fail Criteria:** Pass if no false face detection occurs and response returns `IMAGE_QUALITY_NO_FACE`.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_edge_001_no_face_detected_in_strict_biometrics)
- **Defect Reference:** DEF-SEC-002

---

### TC-EDGE-002: Excessively Blurry Image Rejection
- **Category:** Category B — Face and Image Edge Cases
- **Objective:** Verify that out-of-focus or motion-blurred face captures fail image quality screening before biometric matching.
- **Preconditions:** Engine initialized.
- **Inputs & Setup:** Gaussian blurred frame (kernel 35x35), Laplacian variance < 35.0.
- **Execution Steps:**
  1. Pass blurred frame to `engine.check_image_quality(blurry_img, face_det)`.
- **Expected Result:** `passed = False`, `error_code = "IMAGE_QUALITY_BLURRY"`.
- **Actual Result:** `passed = False`, `error_code = "IMAGE_QUALITY_BLURRY"`, reported sharpness score < 35.0.
- **Pass/Fail Criteria:** Pass if blurred image fails with instructions to hold device steady.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_edge_002_image_quality_blur_rejected)
- **Defect Reference:** DEF-SEC-006

---

### TC-EDGE-003: Underexposed / Dark Frame Rejection
- **Category:** Category B — Face and Image Edge Cases
- **Objective:** Verify that poorly lit captures (mean luminance < 30.0) are rejected with guidance to move to a well-lit area.
- **Preconditions:** Engine initialized.
- **Inputs & Setup:** Dark frame with mean pixel luminance 12.0.
- **Execution Steps:**
  1. Pass dark frame to `engine.check_image_quality(dark_img, face_det)`.
- **Expected Result:** `passed = False`, `error_code = "IMAGE_QUALITY_UNDEREXPOSED"`.
- **Actual Result:** `passed = False`, `error_code = "IMAGE_QUALITY_UNDEREXPOSED"`.
- **Pass/Fail Criteria:** Pass if underexposed frame is rejected.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_edge_003_image_quality_underexposed_rejected)
- **Defect Reference:** DEF-SEC-006

---

### TC-EDGE-004: Insufficient Resolution (< 120x120) Rejection
- **Category:** Category B — Face and Image Edge Cases
- **Objective:** Verify that low-resolution images unable to support reliable feature extraction are rejected.
- **Preconditions:** Engine initialized.
- **Inputs & Setup:** Image of size 80x80 pixels.
- **Execution Steps:**
  1. Pass tiny image to `engine.check_image_quality(tiny_img)`.
- **Expected Result:** `passed = False`, `error_code = "IMAGE_QUALITY_TOO_SMALL"`.
- **Actual Result:** `passed = False`, `error_code = "IMAGE_QUALITY_TOO_SMALL"`.
- **Pass/Fail Criteria:** Pass if rejected with minimum resolution error.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_edge_004_image_quality_too_small)
- **Defect Reference:** DEF-SEC-006

---

### TC-EDGE-005: Empty Payload Rejection (EMPTY_IMAGE)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify 0-byte image upload is immediately rejected with HTTP 400 and `X-Error-Code: EMPTY_IMAGE`.
- **Preconditions:** Backend running.
- **Inputs & Setup:** 0-byte file payload submitted to `/api/auth/enroll`.
- **Execution Steps:**
  1. POST 0-byte multipart `photo` to `/api/auth/enroll`.
  2. Inspect response code, error payload, and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: EMPTY_IMAGE`.
- **Actual Result:** HTTP 400, `X-Error-Code: EMPTY_IMAGE`.
- **Pass/Fail Criteria:** Pass if 0-byte upload is rejected before model inference.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_empty_image_upload_rejected)

---

### TC-EDGE-006: Corrupted Payload Rejection (CORRUPTED_IMAGE)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify corrupted binary payloads with valid extensions fail payload validation.
- **Preconditions:** Backend running.
- **Inputs & Setup:** 512 bytes of random unparseable bytes with filename `corrupt.jpg`.
- **Execution Steps:**
  1. POST corrupted file to `/api/auth/enroll`.
  2. Inspect response code and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: CORRUPTED_IMAGE`.
- **Actual Result:** HTTP 400, `X-Error-Code: CORRUPTED_IMAGE`.
- **Pass/Fail Criteria:** Pass if corrupted image decoding fails safely.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_corrupted_image_upload_rejected)

---

### TC-EDGE-007: Unsupported Image Format Rejection (UNSUPPORTED_FORMAT)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify non-standard image formats (e.g. GIF, PDF) fail magic byte verification.
- **Preconditions:** Backend running.
- **Inputs & Setup:** GIF payload (`GIF89a...`) submitted as profile selfie.
- **Execution Steps:**
  1. POST GIF file to `/api/auth/enroll`.
  2. Inspect response code and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: UNSUPPORTED_FORMAT`.
- **Actual Result:** HTTP 400, `X-Error-Code: UNSUPPORTED_FORMAT`.
- **Pass/Fail Criteria:** Pass if unsupported formats are rejected.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_unsupported_image_format_rejected)

---

### TC-EDGE-008: Oversized Upload Rejection (IMAGE_TOO_LARGE)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify image payloads exceeding 10MB threshold are blocked.
- **Preconditions:** Backend running.
- **Inputs & Setup:** 11MB byte payload.
- **Execution Steps:**
  1. Run `validate_image_payload` with 11MB byte array.
- **Expected Result:** `code == "IMAGE_TOO_LARGE"`, `valid == False`.
- **Actual Result:** Validation returns `IMAGE_TOO_LARGE`.
- **Pass/Fail Criteria:** Pass if payload over 10MB is rejected.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_oversized_upload_rejected)

---

### TC-EDGE-009: No Face Detected in Enrollment or Attendance (NO_FACE_DETECTED)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify frame with no human face detected returns `NO_FACE_DETECTED` with descriptive reticle guidance.
- **Preconditions:** Backend running, FakeFaceEngine with 0 preset detections.
- **Inputs & Setup:** Synthetic image with 0 detected faces.
- **Execution Steps:**
  1. Submit enrollment request with 0 faces.
  2. Submit verification request with 0 faces.
- **Expected Result:** HTTP 400, header `X-Error-Code: NO_FACE_DETECTED`.
- **Actual Result:** HTTP 400, `X-Error-Code: NO_FACE_DETECTED`.
- **Pass/Fail Criteria:** Pass if no-face condition is clearly identified.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_no_face_detected_rejected)

---

### TC-EDGE-010: Multiple Faces Rejected (MULTIPLE_FACES)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify frame containing 2 or more faces is rejected for individual verification.
- **Preconditions:** Backend running, FakeFaceEngine with 2 preset detections.
- **Inputs & Setup:** Frame with 2 detected faces.
- **Execution Steps:**
  1. POST dual-face image to `/api/auth/enroll`.
  2. Inspect response and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: MULTIPLE_FACES`.
- **Actual Result:** HTTP 400, `X-Error-Code: MULTIPLE_FACES`.
- **Pass/Fail Criteria:** Pass if multiple faces are rejected for solo check-in.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_multiple_faces_rejected)

---

### TC-EDGE-011: Face Too Small Ratio Rejection (FACE_TOO_SMALL)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify face occupying under 3.5% of total frame area is rejected with proximity guidance.
- **Preconditions:** Backend running.
- **Inputs & Setup:** 400x300 image (120,000 px), face detection 40x50 px (2,000 px = 1.67%).
- **Execution Steps:**
  1. Run `assess_image_quality` with small face bbox.
- **Expected Result:** `passed == False`, `code == "FACE_TOO_SMALL"`.
- **Actual Result:** Quality check fails with `FACE_TOO_SMALL`.
- **Pass/Fail Criteria:** Pass if small face fails minimum 3.5% ratio.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_face_too_small_rejected)

---

### TC-EDGE-012: Face Partially Outside Frame (FACE_OUT_OF_BOUNDS)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify face clipping frame boundary (margin < 12px) is rejected with centering advice.
- **Preconditions:** Backend running.
- **Inputs & Setup:** 400x300 image, face detection starting at x=2, y=5.
- **Execution Steps:**
  1. Run `assess_image_quality` with boundary clipping bbox.
- **Expected Result:** `passed == False`, `code == "FACE_OUT_OF_BOUNDS"`.
- **Actual Result:** Quality check fails with `FACE_OUT_OF_BOUNDS`.
- **Pass/Fail Criteria:** Pass if clipped face is rejected.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_face_partially_outside_frame_rejected)

---

### TC-EDGE-013: Blur Detection Threshold (IMAGE_BLURRY)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify frame with Laplacian variance < 35.0 is rejected with stability guidance.
- **Preconditions:** Backend running.
- **Inputs & Setup:** Synthetic blurred frame with Laplacian variance ~0.15.
- **Execution Steps:**
  1. POST blurred frame to `/api/auth/enroll`.
  2. Inspect response and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: IMAGE_BLURRY`.
- **Actual Result:** HTTP 400, `X-Error-Code: IMAGE_BLURRY`.
- **Pass/Fail Criteria:** Pass if blurry image is rejected.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_blurry_image_rejected)

---

### TC-EDGE-014: Poor Lighting Rejection (POOR_LIGHTING)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify underexposed dark frame (mean luminance < 35.0) is rejected.
- **Preconditions:** Backend running.
- **Inputs & Setup:** Dark frame with mean luminance ~15.
- **Execution Steps:**
  1. POST dark frame to `/api/auth/enroll`.
  2. Inspect response and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: POOR_LIGHTING`.
- **Actual Result:** HTTP 400, `X-Error-Code: POOR_LIGHTING`.
- **Pass/Fail Criteria:** Pass if dark frame is rejected.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_poor_lighting_rejected)

---

### TC-EDGE-015: Excessive Exposure Rejection (EXCESSIVE_EXPOSURE)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify overexposed / washed out frame (mean luminance > 225.0) is rejected.
- **Preconditions:** Backend running.
- **Inputs & Setup:** Overexposed frame with mean luminance ~240.
- **Execution Steps:**
  1. POST washed out frame to `/api/auth/enroll`.
  2. Inspect response and `X-Error-Code` header.
- **Expected Result:** HTTP 400, header `X-Error-Code: EXCESSIVE_EXPOSURE`.
- **Actual Result:** HTTP 400, `X-Error-Code: EXCESSIVE_EXPOSURE`.
- **Pass/Fail Criteria:** Pass if washed out frame is rejected.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_excessive_exposure_rejected)

---

### TC-EDGE-016: Backlighting Detection Rejection (BACKLIGHTING_DETECTED)
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify severe background backlight relative to dark face silhouette is detected and rejected.
- **Preconditions:** Backend running.
- **Inputs & Setup:** Frame with bright background (lum 240) and dark face region (lum 45).
- **Execution Steps:**
  1. Run `assess_image_quality` with backlit frame.
- **Expected Result:** `passed == False`, `code == "BACKLIGHTING_DETECTED"`.
- **Actual Result:** Quality check fails with `BACKLIGHTING_DETECTED`.
- **Pass/Fail Criteria:** Pass if backlighting contrast ratio triggers rejection.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_backlighting_detected_rejected)

---

### TC-EDGE-017: Quality Failures Never Grant Attendance Success
- **Category:** Category B — Face and Image Quality Edge Cases
- **Objective:** Verify quality failures return HTTP 400 and NEVER insert a successful attendance checkin record.
- **Preconditions:** Enrolled student, open session.
- **Inputs & Setup:** Blurry face photo submitted to `/api/sessions/{session_id}/verify-attendance`.
- **Execution Steps:**
  1. Submit blurry image to attendance verification endpoint.
  2. Query attendance records table for session.
- **Expected Result:** HTTP 400, error code `IMAGE_BLURRY`, 0 attendance records inserted for student.
- **Actual Result:** HTTP 400, attendance records remain 0.
- **Pass/Fail Criteria:** Pass if unreadable or failed images never produce attendance present = true.
- **Status:** PASS
- **Evidence:** `backend/tests/test_camera_reliability.py` (test_failed_quality_never_marks_attendance_success)

---

## Category C — Liveness and Spoofing

### TC-SPOOF-001: Static Printed Photo Bypass Rejection
- **Category:** Category C — Liveness and Spoofing
- **Objective:** Verify that submitting a single static photo without active challenges cannot verify attendance.
- **Preconditions:** Engine initialized with active challenge requirements.
- **Inputs & Setup:** Single frontal image, `expected_challenges = ["turn_left", "blink"]`, challenge frames omitted.
- **Execution Steps:**
  1. Call `engine.verify_active_liveness(frontal_img, left_img=None, right_img=None, blink_img=None, expected_challenges=...)`.
- **Expected Result:** `liveness_passed = False`, failed challenges list contains missing frames.
- **Actual Result:** `liveness_passed = False`, `failed_challenges = ["turn_left (frame missing)", "blink (frame missing)"]`.
- **Pass/Fail Criteria:** Pass if static submission without challenges fails closed.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_spoof_001_static_photo_rejected_without_challenges)
- **Defect Reference:** DEF-SEC-001

---

### TC-SPOOF-002: Byte-Level Image Replay Attack Defense
- **Category:** Category C — Liveness and Spoofing
- **Objective:** Verify that an attacker intercepting and replaying identical image bytes is rejected by SHA-256 fingerprinting.
- **Preconditions:** Student 1 submitted image in session.
- **Inputs & Setup:** Identical JPEG bytes submitted by Student 2 in active session.
- **Execution Steps:**
  1. Student 1 verifies attendance with `face_bytes`.
  2. Student 2 submits the identical `face_bytes` to `POST /api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 400 Bad Request, detail indicates replay attack detected.
- **Actual Result:** HTTP 400 Bad Request, detail: `"Replay attack detected: Identical image capture has already been processed in this session."`.
- **Pass/Fail Criteria:** Pass if identical byte replay is blocked immediately.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_spoof_002_image_replay_sha256_blocked)
- **Defect Reference:** DEF-SEC-003

---

### TC-SPOOF-003: Perceptual Hash (pHash) Re-encoded Replay Defense
- **Category:** Category C — Liveness and Spoofing
- **Objective:** Verify that re-encoding or re-compressing a stolen photo to produce a different SHA-256 hash is caught by DCT perceptual hashing.
- **Preconditions:** Security cache active.
- **Inputs & Setup:** Image re-saved at JPEG quality 70 (different byte digest, Hamming distance 0 on pHash).
- **Execution Steps:**
  1. Record original image pHash in security cache.
  2. Submit re-compressed image bytes with identical pHash.
- **Expected Result:** Perceptual replay detected, `is_replay = True`.
- **Actual Result:** `is_replay = True`, reason: `"Perceptual image replay detected (pHash Hamming distance 0 <= 3)."`.
- **Pass/Fail Criteria:** Pass if perceptual collision blocks replay.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_spoof_003_perceptual_hash_replay_blocked)
- **Defect Reference:** DEF-SEC-003

---

### TC-SPOOF-004: Digital Screen Moiré Spectral Detection
- **Category:** Category C — Liveness and Spoofing
- **Objective:** Verify passive presentation attack detection identifies high-frequency grid frequencies indicative of screen playback.
- **Preconditions:** RealFaceEngine initialized.
- **Inputs & Setup:** Image with high-frequency sine grating simulating tablet/monitor LCD pixel pitch.
- **Execution Steps:**
  1. Pass image to `engine.detect_presentation_attack(img_moire, face_det)`.
  2. Inspect high-to-low FFT spectral energy ratio.
- **Expected Result:** Elevated high-frequency ratio (`freq_ratio > 0.40`) or `is_spoof = True`.
- **Actual Result:** High frequency ratio measured above threshold, passive spoof flag raised.
- **Pass/Fail Criteria:** Pass if screen frequency characteristics are detected.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_spoof_004_passive_screen_moire_detection)
- **Defect Reference:** DEF-SEC-005

---

## Category D — API Security and Concurrency

### TC-API-001: Missing Authentication Enforcement
- **Category:** Category D — API Security
- **Objective:** Verify protected endpoints reject unauthenticated HTTP requests.
- **Preconditions:** Backend running.
- **Inputs & Setup:** Request to `/api/sessions` without `Authorization` header.
- **Execution Steps:**
  1. Send `GET /api/sessions`.
- **Expected Result:** HTTP 401 Unauthorized, detail: `"Bearer access token required"`.
- **Actual Result:** HTTP 401 Unauthorized.
- **Pass/Fail Criteria:** Pass if request is rejected with 401.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_api_001_missing_authentication_rejected)
- **Defect Reference:** N/A

---

### TC-API-002: Role Authorization Enforcement (Student Forbidden from Teacher Routes)
- **Category:** Category D — API Security
- **Objective:** Verify student JWT cannot invoke lecturer operations such as creating an attendance session.
- **Preconditions:** Valid student JWT.
- **Inputs & Setup:** `POST /api/sessions` with student bearer token.
- **Execution Steps:**
  1. Authenticate as student.
  2. Send `POST /api/sessions` payload.
- **Expected Result:** HTTP 403 Forbidden, detail: `"Lecturer authorization required"`.
- **Actual Result:** HTTP 403 Forbidden.
- **Pass/Fail Criteria:** Pass if student cannot create sessions.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_api_002_student_forbidden_from_teacher_operations)
- **Defect Reference:** N/A

---

### TC-API-003: Challenge Token Subject Binding
- **Category:** Category D — API Security
- **Objective:** Verify challenge token issued for Student A cannot be submitted by Student B.
- **Preconditions:** Valid challenge token issued to `00000000-0000-0000-0000-000000000001`.
- **Inputs & Setup:** Student 2 submits token issued for Student 1.
- **Execution Steps:**
  1. Generate challenge token bound to student 1.
  2. Send verification request with Student 2's credentials and Student 1's token.
- **Expected Result:** HTTP 403 Forbidden, detail: `"Challenge token was issued for a different student."`.
- **Actual Result:** HTTP 403 Forbidden, token transfer blocked.
- **Pass/Fail Criteria:** Pass if student mismatch is rejected.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_api_003_challenge_token_student_binding)
- **Defect Reference:** DEF-SEC-004

---

### TC-API-004: Challenge Token Single-Use Enforcement (Nonce Replay Defense)
- **Category:** Category D — API Security
- **Objective:** Verify that a challenge token cannot be submitted a second time.
- **Preconditions:** Challenge token issued with unique nonce.
- **Inputs & Setup:** Submit token twice for verification.
- **Execution Steps:**
  1. Submit first verification with challenge token.
  2. Submit second verification with identical challenge token.
- **Expected Result:** First attempt consumes nonce; second attempt rejected with HTTP 400 `"Challenge token has already been used. Tokens are strictly single-use."`.
- **Actual Result:** HTTP 400 Bad Request, nonce reuse blocked.
- **Pass/Fail Criteria:** Pass if second submission fails closed.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_api_004_challenge_token_single_use_enforcement)
- **Defect Reference:** DEF-SEC-004

---

### TC-API-005: Duplicate Attendance Submission Prevention (Strict 1-Attempt Policy)
- **Category:** Category D — API Security
- **Objective:** Verify that a student who has already completed a check-in attempt cannot submit another attempt in the same session.
- **Preconditions:** Student has already submitted attendance in session.
- **Inputs & Setup:** Second verification attempt by same student for same session.
- **Execution Steps:**
  1. Complete initial attendance verification.
  2. Send second attendance verification request.
- **Expected Result:** HTTP 400 Bad Request, detail: `"Strictly 1 attempt allowed. You have already completed your live attendance attempt for this session."`.
- **Actual Result:** HTTP 400 Bad Request, duplicate check-in blocked, audit log records `attendance.retry_blocked`.
- **Pass/Fail Criteria:** Pass if repeat attempt is blocked.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_api_005_duplicate_attendance_strictly_blocked)
- **Defect Reference:** N/A

---

## Category E — Mobile Application Tests

### TC-MOB-001: Mobile Role Selection UI Rendering
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify Flutter role selection screen renders institutional cards for Student, Lecturer, and Controller.
- **Preconditions:** Flutter environment with Dart SDK 3.47.7.
- **Inputs & Setup:** `AttendanceApp` widget test.
- **Execution Steps:**
  1. Pump `AttendanceApp` in widget tester.
  2. Assert presence of `ATTENDRIX`, `Student Portal`, `Faculty / Lecturer`, and `Academic Controller`.
- **Expected Result:** All three role cards found and clickable.
- **Actual Result:** All 3 widgets found, widget test passes cleanly.
- **Pass/Fail Criteria:** Pass if role options render without overflow or missing text.
- **Status:** PASS
- **Evidence:** `proof/logs/test_runner/flutter_test.log`, `apps/mobile/test/widget_test.dart`
- **Defect Reference:** N/A

---

### TC-MOB-002: Model Serialization & Display Role Mapping
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `User` model properly maps database role `teacher` to UI display label `Lecturer`.
- **Preconditions:** Flutter test suite.
- **Inputs & Setup:** JSON user dictionary with `'role': 'teacher'`.
- **Execution Steps:**
  1. Instantiate `User.fromJson`.
  2. Assert `user.isTeacher == true` and `user.displayRole == 'Lecturer'`.
- **Expected Result:** Correct role boolean and string mapping.
- **Actual Result:** `user.isTeacher == true`, `user.displayRole == 'Lecturer'`.
- **Pass/Fail Criteria:** Pass if model logic agrees with institutional roles.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/widget_test.dart`
- **Defect Reference:** N/A

---

### TC-MOB-003: Loading State Widget Multi-Step Verification
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `LoadingStateView` renders institutional spinner, headline title, descriptive body, and sequential step indicators without layout clipping.
- **Preconditions:** Flutter test environment.
- **Inputs & Setup:** `LoadingStateView` with 3 verification step strings.
- **Execution Steps:**
  1. Pump `LoadingStateView` inside widget tester.
  2. Assert headline, message, step icons, and CircularProgressIndicator.
- **Expected Result:** All elements render with contrast and zero RenderFlex overflow.
- **Actual Result:** Passed cleanly with 0 layout overflow.
- **Pass/Fail Criteria:** Pass if all step indicators render and match expected text.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/ui_states_test.dart`, `proof/screenshots/02_ui_redesign/05_verification_loading_state.png`
- **Defect Reference:** N/A

---

### TC-MOB-004: Biometric Success State & Metrics Card
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `SuccessStateView` displays emerald verified badge, title, subtitle, metrics breakdown table, and executes primary action callback.
- **Preconditions:** Flutter test environment.
- **Inputs & Setup:** `SuccessStateView` with 5 metrics key-value pairs.
- **Execution Steps:**
  1. Pump `SuccessStateView` with onAction callback.
  2. Verify all metric entries render and action button tap triggers callback.
- **Expected Result:** All metrics render with high contrast and action fires on tap.
- **Actual Result:** Passed cleanly; metrics values use `Expanded` to prevent overflow on compact screens.
- **Pass/Fail Criteria:** Pass if metrics table renders without clipping and tap callback is registered.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/ui_states_test.dart`, `proof/screenshots/02_ui_redesign/06_verification_success_state.png`
- **Defect Reference:** N/A

---

### TC-MOB-005: Rejection State & Anti-Proxy Explanations
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `RejectionStateView` presents clear failure reason, retry action, and manual faculty override button.
- **Preconditions:** Flutter test environment.
- **Inputs & Setup:** Rejection reason string, onRetry callback, onManualOption callback.
- **Execution Steps:**
  1. Pump `RejectionStateView` in tester.
  2. Verify plain-language reason is visible and both buttons respond to tap.
- **Expected Result:** Plain-language security reason clearly explained; both callbacks executed.
- **Actual Result:** Rejection card renders rose accent container and dispatches tap events.
- **Pass/Fail Criteria:** Pass if rejection explanation is readable and retry triggers cleanly.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/ui_states_test.dart`, `proof/screenshots/02_ui_redesign/07_verification_rejection_state.png`
- **Defect Reference:** N/A

---

### TC-MOB-006: Diagnostic Retry State & Network Resilience
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `RetryStateCard` renders error/permission state with actionable recovery action.
- **Preconditions:** Flutter test environment.
- **Inputs & Setup:** `RetryStateCard` with network disconnect icon and onRetry callback.
- **Execution Steps:**
  1. Pump `RetryStateCard` in widget tester.
  2. Tap 'Retry Connection' button and verify callback invocation.
- **Expected Result:** Tap increments callback counter; card displays consistent bordered surface.
- **Actual Result:** Passed cleanly; retry action fired.
- **Pass/Fail Criteria:** Pass if actionable recovery prompt renders and triggers action.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/ui_states_test.dart`, `proof/screenshots/02_ui_redesign/08_error_and_empty_states.png`
- **Defect Reference:** N/A

---

### TC-MOB-007: Comprehensive Semantic Status Chip Coverage
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `StatusChip` renders all discrete system attendance states: `present`, `verified`, `absent`, `rejected`, `pending`, `flagged`, `finalized`, `open`.
- **Preconditions:** Flutter test environment.
- **Inputs & Setup:** StatusChip variants rendered inside a Column.
- **Execution Steps:**
  1. Pump all 8 status chip variants.
  2. Assert correct color coding, dot indicators, and capitalized uppercase status labels.
- **Expected Result:** All chips render with designated emerald, rose, amber, and slate color tokens.
- **Actual Result:** All 8 status variants rendered with high contrast and zero layout errors.
- **Pass/Fail Criteria:** Pass if all status chips render expected label and style tokens.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/ui_states_test.dart`
- **Defect Reference:** N/A

---

### TC-MOB-008: Anti-Double-Tap Debounced Button Guard
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify `AppDebouncedButton` enforces lock duration preventing rapid double taps and duplicate submission events.
- **Preconditions:** Flutter test environment.
- **Inputs & Setup:** `AppDebouncedButton` with 500ms debounce duration.
- **Execution Steps:**
  1. Rapidly tap button 3 times within 100ms.
  2. Advance clock past 500ms and tap once more.
- **Expected Result:** Exactly 1 invocation during initial burst, exactly 1 additional invocation after debounce window expires (total: 2).
- **Actual Result:** Invocation count was exactly 1 after burst, and exactly 2 after cooldown.
- **Pass/Fail Criteria:** Pass if rapid duplicate clicks are dropped.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/ui_states_test.dart`
- **Defect Reference:** N/A

---

### TC-MOB-009: Camera Permission Denied & Recovery State
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify mobile app displays high-contrast dark room HUD explaining camera requirement with retry button when permissions are denied or revoked.
- **Preconditions:** App launched, camera permission denied by user or platform.
- **Inputs & Setup:** `LiveFaceVerificationScreen(initialCameraPermissionDenied: true)`.
- **Execution Steps:**
  1. Mount `LiveFaceVerificationScreen` with denied permission state.
  2. Verify UI displays warning icon, explanatory copy, and recovery button.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Camera Permission Denied", icon `Icons.no_photography_rounded`, button "Grant Camera Access / Retry".
- **Actual Result:** View correctly rendered with security-themed explanatory copy and recovery action.
- **Pass/Fail Criteria:** Pass if permission denial is clearly explained and actionable.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/01_camera_permission_denied.png`
- **Defect Reference:** N/A

---

### TC-MOB-010: Camera Hardware Unavailable & Driver Failure Feed
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify mobile app handles hardware initialization failure or empty camera device list gracefully.
- **Preconditions:** Platform camera driver failure or camera bus in use.
- **Inputs & Setup:** `LiveFaceVerificationScreen(initialCameraUnavailable: true)`.
- **Execution Steps:**
  1. Mount verification screen with hardware unavailable condition.
  2. Verify amber diagnostic feed and re-initialization action.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Camera Hardware Unavailable", icon `Icons.videocam_off_rounded`, button "Retry Camera Initialization".
- **Actual Result:** Clean fallback feed rendered without crash or blank black screen.
- **Pass/Fail Criteria:** Pass if hardware failure is caught and user is given retry action.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/02_camera_hardware_unavailable.png`
- **Defect Reference:** N/A

---

### TC-MOB-011: Camera Stream Interrupted on Backgrounding
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify stream interruption during app lifecycle changes (phone call, notification swipe, backgrounding) is recovered safely.
- **Preconditions:** Active capture session in progress.
- **Inputs & Setup:** `LiveFaceVerificationScreen(initialCameraStreamInterrupted: true)`.
- **Execution Steps:**
  1. Mount verification screen in stream interrupted state.
  2. Verify standby pause state and stream resumption button.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Camera Stream Interrupted", icon `Icons.pause_circle_outline_rounded`, button "Resume Camera Stream".
- **Actual Result:** Interrupted stream prompts user to resume safely without dangling hardware locks.
- **Pass/Fail Criteria:** Pass if backgrounded state releases camera and prompts clean resume.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/03_camera_stream_interrupted.png`
- **Defect Reference:** N/A

---

### TC-MOB-012: No Face Detected Guidance & Viewfinder Reticle
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify user receives actionable guidance and reticle realignment prompts when no face is found in viewfinder.
- **Preconditions:** Attendance submission returned `X-Error-Code: NO_FACE_DETECTED`.
- **Inputs & Setup:** Result step with error code `NO_FACE_DETECTED`.
- **Execution Steps:**
  1. Render Result HUD with `NO_FACE_DETECTED`.
  2. Verify amber warning banner, error token, and centering remedy instructions.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Image Quality Check Failed", error code `NO_FACE_DETECTED`, remedy text "Center your face inside the viewfinder reticle".
- **Actual Result:** Exact quality remedy guidance displayed with retry button.
- **Pass/Fail Criteria:** Pass if failure clearly distinguishes quality error from biometric mismatch.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/04_no_face_detected_alert.png`
- **Defect Reference:** N/A

---

### TC-MOB-013: Multiple Faces Warning & Solo Verification Rule
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify user is informed that attendance verification requires a solo selfie when multiple faces are detected.
- **Preconditions:** Attendance submission returned `X-Error-Code: MULTIPLE_FACES`.
- **Inputs & Setup:** Result step with error code `MULTIPLE_FACES`.
- **Execution Steps:**
  1. Render Result HUD with `MULTIPLE_FACES`.
  2. Verify rejection warning explains individual solo requirement.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Image Quality Check Failed", error code `MULTIPLE_FACES`, remedy text "Only one individual student face is permitted".
- **Actual Result:** Distinct solo requirement displayed with amber quality styling.
- **Pass/Fail Criteria:** Pass if multiple face detection is rejected with clear remediation.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/05_multiple_faces_rejected.png`
- **Defect Reference:** N/A

---

### TC-MOB-014: Face Too Small Proximity Guidance
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify small face captures prompt user to bring device closer to satisfy the 3.5% minimum frame area ratio.
- **Preconditions:** Attendance submission returned `X-Error-Code: FACE_TOO_SMALL`.
- **Inputs & Setup:** Result step with error code `FACE_TOO_SMALL`.
- **Execution Steps:**
  1. Render Result HUD with `FACE_TOO_SMALL`.
  2. Verify distance advice and framing guidance.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Image Quality Check Failed", error code `FACE_TOO_SMALL`, remedy text "Move phone closer until your face fills 40% to 60% of the screen".
- **Actual Result:** Framing instructions guide student to move closer to camera.
- **Pass/Fail Criteria:** Pass if proximity remedy is presented.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/06_face_too_small_guidance.png`
- **Defect Reference:** N/A

---

### TC-MOB-015: Blur and Poor Lighting Remedy Action
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify motion blur and low illumination prompt user to stabilize device and face room lighting.
- **Preconditions:** Attendance submission returned `X-Error-Code: IMAGE_BLURRY`.
- **Inputs & Setup:** Result step with error code `IMAGE_BLURRY`.
- **Execution Steps:**
  1. Render Result HUD with `IMAGE_BLURRY`.
  2. Verify stability instructions ("Hold your phone steady with both hands").
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Image Quality Check Failed", error code `IMAGE_BLURRY`, stability advice.
- **Actual Result:** Stability remedy displayed with retry button.
- **Pass/Fail Criteria:** Pass if blur failure directs user to stabilize device.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/07_poor_lighting_and_blur_guidance.png`
- **Defect Reference:** N/A

---

### TC-MOB-016: Network Timeout, Disconnect & Retry Submission
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify network timeouts and transmission interruptions display dedicated sky-blue diagnostic HUD with instant retry action.
- **Preconditions:** Network timeout or socket drop during verification request.
- **Inputs & Setup:** Result step with error code `TIMEOUT`.
- **Execution Steps:**
  1. Render Result HUD with `TIMEOUT`.
  2. Verify network disconnect header and retry submission action.
  3. Capture retina mobile screenshot.
- **Expected Result:** Title "Network Timeout / Disconnected", icon `Icons.wifi_off_rounded`, button "Retry Verification Attempt".
- **Actual Result:** Network resilience card rendered with retry action.
- **Pass/Fail Criteria:** Pass if network timeout is distinguished from biometric rejection.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/08_network_timeout_and_retry.png`
- **Defect Reference:** N/A

---

### TC-MOB-017: Rapid Double-Tap Idempotency & Duplicate Submission Lock
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify repeated rapid taps on submission buttons are debounced and duplicate submissions are rejected under the 1-attempt policy.
- **Preconditions:** Session checkin already recorded.
- **Inputs & Setup:** Error message containing "Attendance checkin already recorded for this session. Strictly 1 attempt allowed."
- **Execution Steps:**
  1. Render Result HUD with duplicate checkin error.
  2. Verify "Attendance Already Recorded" view and 1-attempt policy lock.
- **Expected Result:** Title "Attendance Already Recorded", icon `Icons.fact_check_rounded`, footer "1-Attempt Policy • Attempt Recorded & Finalized".
- **Actual Result:** Duplicate attempt cleanly locked out with explanation.
- **Pass/Fail Criteria:** Pass if duplicate checkin is identified and idempotently blocked.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`
- **Defect Reference:** N/A

---

### TC-MOB-018: Quality Failure Strict Present=False Navigation Result
- **Category:** Category E — Mobile Application Tests
- **Objective:** Verify closing or popping a verification screen after quality or network failure strictly returns `present = false` to caller.
- **Preconditions:** Active verification flow failed due to blur (`IMAGE_BLURRY`).
- **Inputs & Setup:** Push `LiveFaceVerificationScreen` with `initialErrorCode: IMAGE_BLURRY`.
- **Execution Steps:**
  1. Tap "Close" button on result HUD.
  2. Inspect value popped back to parent Navigator route.
- **Expected Result:** Navigator pop returns `false` (never `true` or undefined).
- **Actual Result:** Returned `false`. Quality failure never grants attendance success.
- **Pass/Fail Criteria:** Pass if failure outcome is strictly false.
- **Status:** PASS
- **Evidence:** `apps/mobile/test/camera_reliability_test.dart`
- **Defect Reference:** N/A

---

## Category F — Performance & Concurrency

### TC-PERF-001: Face Detection, Embedding & Verification Latency
- **Category:** Category F — Performance & Concurrency
- **Objective:** Measure and record latency for YuNet face detection, SFace 128D embedding extraction, and active liveness verification on host CPU.
- **Preconditions:** 12th Gen Intel Core i5-12450HX, OpenCV 5.0.0, ONNX models loaded.
- **Inputs & Setup:** 320x320 test frame, 5 sequential iterations per stage.
- **Execution Steps:**
  1. Benchmark `detect_faces` execution time.
  2. Benchmark `extract_embedding` execution time.
  3. Benchmark `verify_active_liveness` execution time.
- **Expected Result:** All individual inference stages complete under 150ms on CPU.
- **Actual Result:**
  - Face Detection (YuNet): ~18.4 ms
  - Embedding Extraction (SFace): ~12.2 ms
  - Active Liveness Pipeline: ~24.8 ms
  - Total biometric inference: < 60 ms
- **Pass/Fail Criteria:** Pass if inference executes under 200ms per frame.
- **Status:** PASS
- **Evidence:** `proof/reports/junit/results.xml` (test_tc_perf_001_inference_latency_benchmark), `proof/PERFORMANCE_RESULTS.md`
- **Defect Reference:** N/A

---

## Category G — Accuracy and Limitations

### TC-ACC-001: Evaluation Data & Model Boundaries
- **Category:** Category G — Accuracy & Limitations
- **Objective:** Document measured biometric performance, dataset boundaries, and physical limitations of monocular RGB presentation attack detection.
- **Preconditions:** Mathematical review of passive RGB PAD and YuNet/SFace models.
- **Inputs & Setup:** See `proof/ACCURACY_AND_LIMITATIONS.md`.
- **Execution Steps:**
  1. Audit spectral analysis limits against high-resolution matte photo attacks.
  2. Record attack presentation classification capabilities.
- **Expected Result:** Clear technical disclosure distinguishing presentation-attack detection from identity matching.
- **Actual Result:** Complete disclosure documented in `proof/ACCURACY_AND_LIMITATIONS.md`.
- **Pass/Fail Criteria:** Pass if limitations are transparently stated without unsupported claims of 100% security.
- **Status:** PASS
- **Evidence:** `proof/ACCURACY_AND_LIMITATIONS.md`
- **Defect Reference:** N/A

---

## Category H — Adversarial Evaluation & Presentation-Attack Defense

### TC-ADV-001: Consenting Live Participant Verification
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify end-to-end attendance for a consenting live participant completing all randomized active challenges with biometric matching.
- **Preconditions:** Enrolled reference template for Student A, active open session.
- **Inputs & Setup:** Server-signed challenge token, live frontal capture, left turn (yaw deflection $\le -15^\circ$), right turn (yaw deflection $\ge +15^\circ$), eye blink capture (EAR $\le 0.12$).
- **Execution Steps:**
  1. Student requests challenge token via `POST /api/sessions/{session_id}/liveness-challenge`.
  2. Student submits matching frontal and completed challenge frames to `POST /api/sessions/{session_id}/verify-attendance`.
  3. Validate attendance status, liveness status, and biometric similarity.
- **Expected Result:** HTTP 200, `status = "present"`, `liveness_passed = True`, `face_match = True`, confidence $\ge 0.45$.
- **Actual Result:** HTTP 200, `status = "present"`, `liveness_passed = True`, `face_match = True`, confidence 1.0, latency 164.55ms.
- **Pass/Fail Criteria:** Pass if both liveness and biometric match pass and status is marked present.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/01_live_matching_challenge_flow.png`
- **Defect Reference:** N/A

---

### TC-ADV-002: Live Non-Matching Participant (Biometric Mismatch)
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify that a live consenting participant who completes all liveness challenges but does not match the enrolled student reference is rejected. Proves liveness alone does not authorize attendance.
- **Preconditions:** Enrolled reference template for Student A, active open session.
- **Inputs & Setup:** Submitter is Person B (different live face performing valid yaw deflection and eye blinks).
- **Execution Steps:**
  1. Obtain challenge token for Student A.
  2. Person B performs live head turns and blinks, submitting to `POST /api/sessions/{session_id}/verify-attendance`.
  3. Inspect response decisions.
- **Expected Result:** HTTP 200, `status = "absent"`, `liveness_passed = True`, `face_match = False`.
- **Actual Result:** HTTP 200, `status = "absent"`, `liveness_passed = True`, `face_match = False`, similarity 0.048 (< 0.45 threshold), latency 73.67ms.
- **Pass/Fail Criteria:** Pass if liveness is confirmed but attendance is rejected due to biometric mismatch.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/02_live_non_matching_participant.png`
- **Defect Reference:** N/A

---

### TC-ADV-003: Printed Photograph Attack
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify presentation attack detection flags printed photos via desaturated chrominance variance and halftone analysis.
- **Preconditions:** RealFaceEngine initialized.
- **Inputs & Setup:** High-contrast printed photograph capture with low HSV color saturation and YCrCb chrominance variance.
- **Execution Steps:**
  1. Submit printed capture to `detect_presentation_attack`.
  2. Inspect spoof score and attack reasons.
- **Expected Result:** `is_spoof = True`, `attack_type` contains `PRINT_ATTACK_DETECTED` or spoof score $> 0.45$.
- **Actual Result:** `is_spoof = True`, reason: `Low chrominance variance indicative of grayscale or printed attack [PRINT_ATTACK_DETECTED]`, spoof score 0.65, latency 2.99ms.
- **Pass/Fail Criteria:** Pass if print attack is flagged and blocked.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/03_print_attack_chroma_analysis.png`
- **Defect Reference:** SEC-011

---

### TC-ADV-004: Photograph Displayed on Screen (Phone / Tablet / Monitor)
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify digital screen playback attacks are detected via 2D FFT spectral peak-to-mean ratio (SPMR) and high-frequency raster moiré.
- **Preconditions:** RealFaceEngine initialized.
- **Inputs & Setup:** Capture displaying face on digital LCD/OLED screen with periodic pixel grid raster.
- **Execution Steps:**
  1. Pass image to `detect_presentation_attack`.
  2. Compute 2D Fast Fourier Transform magnitude spectrum.
- **Expected Result:** `is_spoof = True`, SPMR $> 1.85$ or high-frequency ratio $> 0.85$, attack classified as `SCREEN_MOIRE_DETECTED`.
- **Actual Result:** `is_spoof = True`, `SCREEN_MOIRE_DETECTED` flagged, spoof score 1.0, latency 2.01ms.
- **Pass/Fail Criteria:** Pass if digital screen raster frequency spikes trigger spoof detection.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/04_screen_replay_moire_fft.png`
- **Defect Reference:** SEC-011

---

### TC-ADV-005: Prerecorded Video Replay Attack
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify prerecorded video replay is defeated by server-side dynamic randomized challenge sequences and inter-frame static motion analysis.
- **Preconditions:** Active challenge required by session.
- **Inputs & Setup:** Identical static video frame replayed across challenge slots when server demanded `turn_left` and `turn_right`.
- **Execution Steps:**
  1. Call `engine.verify_active_liveness` with identical frames across challenge slots.
- **Expected Result:** `liveness_passed = False`, `reason` is `STATIC_IMAGE_REPLAY_ACROSS_CHALLENGES` or `ACTION_MISMATCH`.
- **Actual Result:** `liveness_passed = False`, reason: `STATIC_IMAGE_REPLAY_ACROSS_CHALLENGES`, latency 10.73ms.
- **Pass/Fail Criteria:** Pass if zero-motion replay across challenge slots fails closed.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/05_static_replay_frame_differencing.png`
- **Defect Reference:** SEC-009

---

### TC-ADV-006: Previously Submitted Image Replay Defense
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify replay of previously submitted legitimate frames in subsequent sessions is blocked by SHA-256 byte deduplication and pHash perceptual collision.
- **Preconditions:** Image previously processed in session 1.
- **Inputs & Setup:** Submitting identical capture bytes in session 2.
- **Execution Steps:**
  1. Re-submit previously used image bytes to `POST /api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 400 Bad Request with `X-Error-Code: REPLAY_ATTACK_DETECTED`.
- **Actual Result:** HTTP 400 Bad Request, detail: `"Replay attack detected: Identical image capture has already been processed"`, latency 75.82ms.
- **Pass/Fail Criteria:** Pass if repeat image submissions are blocked immediately.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`
- **Defect Reference:** SEC-003

---

### TC-ADV-007: Low-Quality Capture Screening
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify low-quality captures (severe blur, underexposure, or tiny face area) are rejected by image quality screening before recognition.
- **Preconditions:** Quality thresholds configured.
- **Inputs & Setup:** Artificially blurred (Laplacian variance $< 40$), underexposed (luminance $< 30$), and small face ($< 4\%$ frame area) captures.
- **Execution Steps:**
  1. Evaluate each quality edge case with `engine.check_image_quality`.
- **Expected Result:** `passed = False`, error codes reflect failure reason (`IMAGE_QUALITY_BLURRY`, `IMAGE_QUALITY_UNDEREXPOSED`, `IMAGE_QUALITY_FACE_TOO_SMALL`).
- **Actual Result:** All 3 quality edge cases rejected cleanly, latency 3.97ms.
- **Pass/Fail Criteria:** Pass if degraded captures fail quality screening.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`
- **Defect Reference:** SEC-006

---

### TC-ADV-008: Multiple Faces Detected
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify captures with multiple faces in frame are rejected to prevent proctor intrusion or proxy collaboration.
- **Preconditions:** Composite frame containing 2 human faces.
- **Inputs & Setup:** Two detected face objects passed to `validate_single_face`.
- **Execution Steps:**
  1. Call `validate_single_face([face_1, face_2])`.
- **Expected Result:** `face_ok = False`, `error_code = "MULTIPLE_FACES"`.
- **Actual Result:** `face_ok = False`, `error_code = "MULTIPLE_FACES"`, detail: `"Multiple faces (2) detected. Please ensure only you are visible"`, latency 0.01ms.
- **Pass/Fail Criteria:** Pass if multiple faces are rejected immediately.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`
- **Defect Reference:** N/A

---

### TC-ADV-009: Expired and Reused Challenge Tokens
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify challenge tokens expire after 90 seconds and nonces can only be consumed exactly once.
- **Preconditions:** Challenge token issued with 90s TTL.
- **Inputs & Setup:** Expired token (negative TTL) and token nonce submitted twice.
- **Execution Steps:**
  1. Verify expired token -> Check exception.
  2. Consume active token nonce twice -> Check return values.
- **Expected Result:** Expired token throws signature/expiration error; second nonce consumption returns `False`.
- **Actual Result:** Expired token rejected; first nonce consumption returns `True`, second consumption returns `False`, latency 0.32ms.
- **Pass/Fail Criteria:** Pass if token expiration and single-use nonces are strictly enforced.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/06_challenge_token_security_lifecycle.png`
- **Defect Reference:** SEC-004

---

### TC-ADV-010: Incorrect Active-Challenge Responses
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify client providing incorrect head direction (e.g. turned right when server asked for left) fails liveness.
- **Preconditions:** Server challenge demands `turn_left` (yaw $\le -15^\circ$).
- **Inputs & Setup:** Client submits frame with yaw $+25^\circ$ (turned right).
- **Execution Steps:**
  1. Call `verify_active_liveness` with conflicting turn direction.
- **Expected Result:** `liveness_passed = False`, `left_turn_detected = False`.
- **Actual Result:** `liveness_passed = False`, `left_turn_detected = False`, latency 22.49ms.
- **Pass/Fail Criteria:** Pass if wrong action fails liveness check.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`
- **Defect Reference:** N/A

---

### TC-ADV-011: Model Timeout and Unavailable Model (Fail Closed)
- **Category:** Category H — Adversarial Evaluation
- **Objective:** Verify that model inference failure/timeout fails closed with HTTP 503, and client-supplied bypass assertions (`is_live`, `verified`, `confidence`) cannot independently authorize attendance.
- **Preconditions:** Enrolled student, active open session.
- **Inputs & Setup:** Client passes `is_live=True`, `verified=True`, `confidence=0.999`. Engine `detect_faces` throws `RuntimeError`.
- **Execution Steps:**
  1. Send request with client bypass parameters -> Verify server executes CV and ignores client flags.
  2. Simulate model runtime failure -> Verify HTTP 503 response.
- **Expected Result:** Client assertion parameters do not bypass CV; model runtime exception returns HTTP 503 `MODEL_UNAVAILABLE`, zero attendance granted.
- **Actual Result:** Client assertions disregarded; model runtime failure triggers HTTP 503 `MODEL_UNAVAILABLE` with audit log, latency 60.81ms.
- **Pass/Fail Criteria:** Pass if system fails closed on model unavailability and neutralizes client-side bypass fields.
- **Status:** PASS
- **Evidence:** `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/07_model_fail_closed_architecture.png`
- **Defect Reference:** SEC-008, SEC-010

---

## Category I — Identity Verification and Anti-Proxy Integrity (Task 05)

### TC-ID-001: Correct Live Enrolled Student (Matching Identity)
- **Category:** Category I — Identity Integrity
- **Objective:** Verify authentic live enrolled student with valid dynamic challenges is marked present.
- **Preconditions:** Student enrolled with reference face template; lecture session is open.
- **Inputs & Setup:** Authentic live face matching enrolled template, matching challenge sequence (turn & blink).
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance` with matching face and challenge token.
- **Expected Result:** HTTP 200 OK, `status: "present"`, `face_match: True`, `liveness_passed: True`, `session_valid: True`.
- **Actual Result:** HTTP 200 OK, `status: "present"`, `face_match: True`, `face_confidence: 0.999`.
- **Pass/Fail Criteria:** Pass if marked present with matching identity.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/01_identity_matching_decision_matrix.png`
- **Defect Reference:** N/A

---

### TC-ID-002: Correct Student With Poor Quality Capture
- **Category:** Category I — Identity Integrity
- **Objective:** Verify that poor quality captures (heavily blurred or underexposed) are rejected before matching.
- **Preconditions:** Student enrolled; session is open.
- **Inputs & Setup:** Face image with Gaussian blur ($\sigma=25$) causing Laplacian variance $< 45.0$.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance` with blurred face capture.
- **Expected Result:** HTTP 400 Bad Request with `X-Error-Code: IMAGE_BLURRY` or `IMAGE_QUALITY_BLURRY`.
- **Actual Result:** HTTP 400 Bad Request, `X-Error-Code: IMAGE_BLURRY`, detail: "Capture is too blurry".
- **Pass/Fail Criteria:** Pass if low-quality capture is rejected before biometric matching.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`
- **Defect Reference:** SEC-006

---

### TC-ID-003: Live But Non-Matching Person (Impostor Detection)
- **Category:** Category I — Identity Integrity
- **Objective:** Verify live person passes liveness challenges but is marked absent on biometric identity mismatch.
- **Preconditions:** Enrolled template orthogonal to live candidate ($sim < 0.35$).
- **Inputs & Setup:** Live face 2 performing head turns and blinks against registered face 1.
- **Execution Steps:**
  1. Complete active challenges with face 2.
  2. POST `/api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 200 OK, `status: "absent"`, `face_match: False`, `liveness_passed: True`.
- **Actual Result:** HTTP 200 OK, `status: "absent"`, `face_match: False`, `liveness_passed: True`, `face_confidence: 0.048`.
- **Pass/Fail Criteria:** Pass if live impostor is marked absent despite authentic liveness.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/01_identity_matching_decision_matrix.png`
- **Defect Reference:** SEC-001

---

### TC-ID-004: Missing Enrollment Reference
- **Category:** Category I — Identity Integrity
- **Objective:** Verify student without registered template is rejected with clean HTTP 400.
- **Preconditions:** Student authenticated but no record in `face_templates`.
- **Inputs & Setup:** Live capture submitted without enrollment.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 400 Bad Request with `X-Error-Code: MISSING_ENROLLMENT_DATA`.
- **Actual Result:** HTTP 400 Bad Request, `X-Error-Code: MISSING_ENROLLMENT_DATA`, detail: "Biometrics not enrolled".
- **Pass/Fail Criteria:** Pass if missing enrollment is rejected before running pipeline.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/03_enrollment_integrity_rejection_flow.png`
- **Defect Reference:** SEC-014

---

### TC-ID-005: Invalid or Malformed Enrollment Data
- **Category:** Category I — Identity Integrity
- **Objective:** Verify corrupted Fernet ciphertext in `face_templates` fails closed cleanly with HTTP 400.
- **Preconditions:** Tampered / corrupted ciphertext string stored in `face_templates`.
- **Inputs & Setup:** Verification request against corrupted template.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 400 Bad Request with `X-Error-Code: INVALID_ENROLLMENT_DATA`.
- **Actual Result:** HTTP 400 Bad Request, `X-Error-Code: INVALID_ENROLLMENT_DATA`, detail: "Malformed or corrupted biometric enrollment data".
- **Pass/Fail Criteria:** Pass if decryption error fails closed with 400 without crashing server.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/03_enrollment_integrity_rejection_flow.png`
- **Defect Reference:** SEC-014

---

### TC-ID-006: Incompatible or Expired Enrollment Data
- **Category:** Category I — Identity Integrity
- **Objective:** Verify incompatible model version or expired template timestamps are rejected.
- **Preconditions:** Template with `model_version = "unsupported-legacy-model-v0"` or `expires_at` in past.
- **Inputs & Setup:** Verification attempts against incompatible and expired templates.
- **Execution Steps:**
  1. Submit against incompatible model -> Verify HTTP 400 `INVALID_ENROLLMENT_DATA`.
  2. Submit against expired template -> Verify HTTP 400 `EXPIRED_ENROLLMENT_DATA`.
- **Expected Result:** HTTP 400 with specific error code headers.
- **Actual Result:** Both subcases rejected with HTTP 400 and appropriate error codes.
- **Pass/Fail Criteria:** Pass if incompatible model and expired data are blocked cleanly.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/03_enrollment_integrity_rejection_flow.png`
- **Defect Reference:** SEC-014

---

### TC-ID-007: Ambiguous or Low-Confidence Match
- **Category:** Category I — Identity Integrity
- **Objective:** Verify borderline similarity scores ($0.35 \le sim < 0.45$) are held in pending review and NEVER auto-accepted.
- **Preconditions:** Enrolled template synthetic vector crafted to yield $sim = 0.40$.
- **Inputs & Setup:** Live face verification with similarity 0.40 in ambiguous window.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 200 OK, `status: "pending"`, `face_match: False`, audit action `attendance.ambiguous_match`.
- **Actual Result:** HTTP 200 OK, `status: "pending"`, `face_match: False`, note: "Ambiguous biometric match".
- **Pass/Fail Criteria:** Pass if uncertain result is routed to review queue instead of present.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/01_identity_matching_decision_matrix.png`
- **Defect Reference:** SEC-006

---

### TC-ID-008: Expired or Closed Lecture Session
- **Category:** Category I — Identity Integrity
- **Objective:** Verify attendance cannot be recorded against closed or expired lecture sessions.
- **Preconditions:** Session status set to `closed`.
- **Inputs & Setup:** Verification request submitted against closed session.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance`.
- **Expected Result:** HTTP 400 Bad Request, detail: "This attendance session is not open."
- **Actual Result:** HTTP 400 Bad Request, detail: "This attendance session is not open."
- **Pass/Fail Criteria:** Pass if closed session blocks submission.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`
- **Defect Reference:** N/A

---

### TC-ID-009: Replayed Capture Defense
- **Category:** Category I — Identity Integrity
- **Objective:** Verify previously submitted capture frame bytes cannot be reused in another session.
- **Preconditions:** Legitimate initial check-in completed.
- **Inputs & Setup:** Identical SHA-256 byte payload submitted to fresh session.
- **Execution Steps:**
  1. POST identical bytes to second session.
- **Expected Result:** HTTP 400 Bad Request with `X-Error-Code: REPLAY_ATTACK_DETECTED`.
- **Actual Result:** HTTP 400 Bad Request, `X-Error-Code: REPLAY_ATTACK_DETECTED`.
- **Pass/Fail Criteria:** Pass if byte deduplication blocks replayed images.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`
- **Defect Reference:** SEC-003

---

### TC-ID-010: Reused Challenge Token
- **Category:** Category I — Identity Integrity
- **Objective:** Verify consumed challenge token cannot be reused across requests.
- **Preconditions:** Challenge token consumed on first attendance verification.
- **Inputs & Setup:** Re-submitting consumed token with fresh face frame.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance` with consumed token.
- **Expected Result:** HTTP 400 Bad Request, detail: "Challenge token has already been used."
- **Actual Result:** HTTP 400 Bad Request, detail: "Challenge token has already been used. Tokens are strictly single-use."
- **Pass/Fail Criteria:** Pass if nonce consumption blocks reuse.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`
- **Defect Reference:** SEC-004

---

### TC-ID-011: Duplicate Attendance Submission
- **Category:** Category I — Identity Integrity
- **Objective:** Verify sequential repeat check-in attempts are rejected by 1-attempt policy.
- **Preconditions:** First attendance attempt recorded in database.
- **Inputs & Setup:** Repeat submission by same student on same session.
- **Execution Steps:**
  1. Send second verification request.
- **Expected Result:** HTTP 400 Bad Request with `X-Error-Code: ATTEMPT_LIMIT_REACHED`.
- **Actual Result:** HTTP 400 Bad Request, `X-Error-Code: ATTEMPT_LIMIT_REACHED`.
- **Pass/Fail Criteria:** Pass if duplicate check-in is rejected.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`
- **Defect Reference:** N/A

---

### TC-ID-012: Simultaneous Concurrent Check-In Requests (Race Condition)
- **Category:** Category I — Identity Integrity
- **Objective:** Verify that concurrent requests serialize atomically via in-memory mutex, resulting in exactly 1 attendance record.
- **Preconditions:** Enrolled student; active open session.
- **Inputs & Setup:** 5 parallel threads submitting verification requests at $T=0\text{ms}$.
- **Execution Steps:**
  1. Dispatch 5 simultaneous requests via `concurrent.futures.ThreadPoolExecutor`.
  2. Verify response codes and database record count.
- **Expected Result:** Exactly 1 request succeeds (HTTP 200); remaining 4 requests blocked with HTTP 400 `ATTEMPT_LIMIT_REACHED`. Exactly 1 row in `attendance` table.
- **Actual Result:** Exactly 1 success (200), 4 blocked (400 `ATTEMPT_LIMIT_REACHED`), exactly 1 DB row.
- **Pass/Fail Criteria:** Pass if race condition is eliminated and zero duplicate rows exist.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/02_concurrency_race_condition_timeline.png`
- **Defect Reference:** SEC-012

---

### TC-ID-013: Database Transaction Failure (Fail Closed)
- **Category:** Category I — Identity Integrity
- **Objective:** Verify that database write/persistence exceptions fail closed without phantom attendance.
- **Preconditions:** Enrolled student, active open session.
- **Inputs & Setup:** Database `insert`/`update` mocked to raise transaction failure exception.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance` during DB outage.
- **Expected Result:** HTTP 500/503 with `X-Error-Code: DATABASE_TRANSACTION_FAILED`, zero attendance records created.
- **Actual Result:** HTTP 500, `X-Error-Code: DATABASE_TRANSACTION_FAILED`, zero phantom records.
- **Pass/Fail Criteria:** Pass if database transaction error fails closed cleanly.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`
- **Defect Reference:** SEC-015

---

### TC-ID-014: Attempt to Submit Attendance for Another User (IDOR Defense)
- **Category:** Category I — Identity Integrity
- **Objective:** Verify that client cannot submit attendance for another student via form or query fields.
- **Preconditions:** Attacker authenticated as Student A. Victim is Student B.
- **Inputs & Setup:** Attacker passes `student_id: victim_uuid` in form body.
- **Execution Steps:**
  1. POST `/api/sessions/{session_id}/verify-attendance` with mismatched student ID.
- **Expected Result:** HTTP 403 Forbidden with `X-Error-Code: IDOR_ATTEMPT_BLOCKED`.
- **Actual Result:** HTTP 403 Forbidden, `X-Error-Code: IDOR_ATTEMPT_BLOCKED`, detail: "Unauthorized: Cannot submit attendance for another student".
- **Pass/Fail Criteria:** Pass if IDOR attempt is blocked with 403.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/04_anti_idor_and_log_privacy_architecture.png`
- **Defect Reference:** SEC-013

---

### TC-ID-015: Biometric Log Sanitization & Privacy Compliance
- **Category:** Category I — Identity Integrity
- **Objective:** Verify that raw embeddings (128/512 float arrays), facial landmarks, and raw image buffers are NEVER leaked in application logs or audit records.
- **Preconditions:** Debug logging enabled (`caplog.at_level(DEBUG)`).
- **Inputs & Setup:** Execute full enrollment and live verification flow under log capture.
- **Execution Steps:**
  1. Execute enrollment and live verification.
  2. Inspect captured log records for `array([`, `dtype=float`, and landmark tuples.
- **Expected Result:** Zero floating point vector dumps or landmark tuples present in ordinary application logs.
- **Actual Result:** Passed: complete absence of float array vectors, raw landmarks, and image buffers in logs.
- **Pass/Fail Criteria:** Pass if no biometric data appears in log output.
- **Status:** PASS
- **Evidence:** `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/04_anti_idor_and_log_privacy_architecture.png`
- **Defect Reference:** SEC-015

---

## Category K: API Security Hardening (Task 06)

### TC-SEC-001: Missing Authentication Token Rejection
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that protected endpoints reject requests lacking an Authorization Bearer header.
- **Preconditions:** Server active with in-memory database.
- **Inputs & Setup:** Unauthenticated requests dispatched to 7 core protected routes: `/api/me`, `/api/sessions`, `/api/sessions/s1/verify-attendance`, `/api/sessions/s1/end`, `/api/controller/classes`, `/api/audit`, `/api/analytics`.
- **Execution Steps:**
  1. Dispatch HTTP GET/POST/PATCH requests to each endpoint without Authorization header.
- **Expected Result:** HTTP 401 Unauthorized with detail "Missing authorization credentials" or "Not authenticated".
- **Actual Result:** All 7 endpoints rejected unauthenticated requests with HTTP 401.
- **Pass/Fail Criteria:** Pass if all protected endpoints return 401.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png`
- **Defect Reference:** SEC-007

---

### TC-SEC-002: Malformed and Forged HMAC-SHA256 JWT Rejection
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that garbage strings and tokens signed with forged secrets are rejected with 401.
- **Preconditions:** SUPABASE_JWT_SECRET configured on backend.
- **Inputs & Setup:** (1) Random string `Bearer not-a-valid-jwt-token`; (2) Valid payload signed with attacker secret `completely_wrong_secret_key_12345678`.
- **Execution Steps:**
  1. GET `/api/me` with malformed token.
  2. GET `/api/me` with forged token.
- **Expected Result:** HTTP 401 Unauthorized with detail indicating invalid token.
- **Actual Result:** Both requests returned HTTP 401 with "Invalid token".
- **Pass/Fail Criteria:** Pass if signature verification prevents forged tokens from authenticating.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png`

---

### TC-SEC-003: Expired JWT Credentials Rejection
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure expired JWT tokens are rejected with 401 and an explicit expiration message.
- **Preconditions:** Server active.
- **Inputs & Setup:** JWT payload with `exp = current_time - 3600` (expired 1 hour ago) signed with legitimate secret.
- **Execution Steps:**
  1. GET `/api/me` with expired Bearer token.
- **Expected Result:** HTTP 401 Unauthorized with "Token has expired".
- **Actual Result:** HTTP 401 returned with detail "Token has expired".
- **Pass/Fail Criteria:** Pass if expired token is immediately rejected.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png`

---

### TC-SEC-004: Token Revocation Upon User Logout (JTI Blacklist)
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that after calling `POST /api/auth/logout`, the token is blacklisted and cannot be reused.
- **Preconditions:** Active student session with valid JWT.
- **Inputs & Setup:** Login as student1, obtain access token, call logout endpoint, then retry `/api/me`.
- **Execution Steps:**
  1. POST `/api/auth/login` to obtain token.
  2. GET `/api/me` with token (verify 200 OK).
  3. POST `/api/auth/logout` with Bearer token.
  4. GET `/api/me` with revoked token.
- **Expected Result:** Step 3 returns 200 with "credentials revoked"; Step 4 returns HTTP 401 `REVOKED_CREDENTIALS`.
- **Actual Result:** Step 4 rejected with HTTP 401, detail: "Token has been revoked. Please re-authenticate.", X-Error-Code: `REVOKED_CREDENTIALS`.
- **Pass/Fail Criteria:** Pass if revoked token is completely unusable.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png`
- **Defect Reference:** SEC-017

---

### TC-SEC-005: Account Deactivation Enforcement
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that deactivated accounts (`is_active = False`) are blocked on both login and API requests.
- **Preconditions:** Student account marked `is_active = False` in database.
- **Inputs & Setup:** Attempt login with valid credentials; attempt API request with previously issued token.
- **Execution Steps:**
  1. POST `/api/auth/login` with deactivated user credentials.
  2. GET `/api/me` with token for deactivated user.
- **Expected Result:** Both requests return HTTP 401 `ACCOUNT_DEACTIVATED`.
- **Actual Result:** Both requests returned HTTP 401 with detail "Account has been deactivated. Contact your institution administrator." and X-Error-Code: `ACCOUNT_DEACTIVATED`.
- **Pass/Fail Criteria:** Pass if inactive users cannot access the system.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png`

---

### TC-SEC-006: Student Privilege Boundaries (Forbidden from Teacher Endpoints)
- **Category:** Category K — API Security Hardening
- **Objective:** Verify role-based authorization prevents students from calling lecturer-only routes.
- **Preconditions:** Authenticated student token.
- **Inputs & Setup:** Student calls `POST /api/sessions`, `PATCH /api/sessions/s1/end`, `GET /api/audit`, `GET /api/analytics`.
- **Execution Steps:**
  1. Dispatch requests to teacher-restricted endpoints using student Bearer token.
- **Expected Result:** All endpoints return HTTP 403 Forbidden with `TEACHER_ONLY` or `ROLE_DENIED`.
- **Actual Result:** All 4 teacher operations returned HTTP 403.
- **Pass/Fail Criteria:** Pass if students are strictly prevented from managing sessions or reading audit logs.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/01_rbac_and_class_ownership.png`
- **Defect Reference:** SEC-007

---

### TC-SEC-007: Controller Privilege Isolation
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that students and teachers cannot access administrative controller endpoints.
- **Preconditions:** Authenticated student and teacher tokens.
- **Inputs & Setup:** Call `/api/controller/classes`, `/api/controller/classes/c1/capture-room`, `/api/controller/users/csv-import`.
- **Execution Steps:**
  1. Dispatch requests with student token.
  2. Dispatch requests with teacher token.
- **Expected Result:** All requests return HTTP 403 Forbidden with `CONTROLLER_ONLY`.
- **Actual Result:** All controller endpoints returned HTTP 403 for both non-admin roles.
- **Pass/Fail Criteria:** Pass if controller routes are strictly accessible only by controllers.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/01_rbac_and_class_ownership.png`

---

### TC-SEC-008: Cross-Teacher Class and Session Isolation (IDOR Defense)
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that Teacher A cannot create sessions or modify sessions belonging to Teacher B's classes.
- **Preconditions:** Teacher A and Teacher B provisioned with separate classes and sessions.
- **Inputs & Setup:** Teacher A attempts `POST /api/sessions` for Class B; Teacher A attempts `PATCH /api/sessions/{session_b}/end`.
- **Execution Steps:**
  1. Teacher A calls session creation referencing Class B.
  2. Teacher A calls session finalization referencing Session B.
- **Expected Result:** Both requests return HTTP 403 Forbidden ("You are not assigned to this class").
- **Actual Result:** Both requests returned HTTP 403 with `X-Error-Code: CLASS_ACCESS_DENIED`.
- **Pass/Fail Criteria:** Pass if teachers cannot access or manipulate other teachers' classes/sessions.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/01_rbac_and_class_ownership.png`
- **Defect Reference:** SEC-018

---

### TC-SEC-009: Teacher Audit Log Scoping (Horizontal Data Isolation)
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure Teacher A querying `/api/audit` receives only audit records for classes they teach.
- **Preconditions:** Audit log contains events from Session A (Teacher A) and Session B (Teacher B).
- **Inputs & Setup:** Teacher A queries `GET /api/audit`; Controller queries `GET /api/audit`.
- **Execution Steps:**
  1. Query audit log as Teacher A.
  2. Inspect returned records for presence of Session B IDs.
  3. Query audit log as Controller.
- **Expected Result:** Teacher A receives zero records from Session B; Controller receives institutional records from both.
- **Actual Result:** Teacher A received only Session A records (0% data leak); Controller received all sessions.
- **Pass/Fail Criteria:** Pass if horizontal audit log leakage is completely prevented.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/01_rbac_and_class_ownership.png`
- **Defect Reference:** SEC-018

---

### TC-SEC-010: Student Attendance Submission IDOR Defense
- **Category:** Category K — API Security Hardening
- **Objective:** Verify student cannot submit attendance on behalf of another student by manipulating form parameters.
- **Preconditions:** Authenticated as Student 1. Student 2 exists in database.
- **Inputs & Setup:** Student 1 submits `POST /api/sessions/s1/verify-attendance` with `student_id: student_2_uuid`.
- **Execution Steps:**
  1. Dispatch attendance check-in with mismatched student ID.
- **Expected Result:** HTTP 403 Forbidden with `X-Error-Code: IDOR_ATTEMPT_BLOCKED`.
- **Actual Result:** Request blocked with HTTP 403 and `X-Error-Code: IDOR_ATTEMPT_BLOCKED`.
- **Pass/Fail Criteria:** Pass if client-supplied identity assertions are rejected.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`
- **Defect Reference:** SEC-013

---

### TC-SEC-011: Unenrolled Student Attendance Rejection
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure a student not enrolled in the session's class cannot submit attendance.
- **Preconditions:** Student 3 is provisioned but not enrolled in Class 1.
- **Inputs & Setup:** Student 3 calls `POST /api/sessions/{session_1}/verify-attendance`.
- **Execution Steps:**
  1. Dispatch attendance verification with Student 3 token.
- **Expected Result:** HTTP 403 Forbidden ("You are not enrolled in this session's class").
- **Actual Result:** Returned HTTP 403 Forbidden with `CLASS_ACCESS_DENIED`.
- **Pass/Fail Criteria:** Pass if enrollment membership is strictly enforced.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`

---

### TC-SEC-012: Attendance Rejected on Closed or Expired Sessions
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure challenge creation and attendance verification fail closed on closed sessions.
- **Preconditions:** Session marked with `status = 'closed'`.
- **Inputs & Setup:** Student calls `/liveness-challenge` and `/verify-attendance` for closed session.
- **Execution Steps:**
  1. POST challenge request on closed session.
  2. POST verify-attendance request on closed session.
- **Expected Result:** Both requests return HTTP 400 Bad Request ("This attendance session is not open").
- **Actual Result:** Both requests returned HTTP 400 Bad Request.
- **Pass/Fail Criteria:** Pass if closed sessions reject attendance actions.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`

---

### TC-SEC-013: Client-Manipulated Verification Flags Strictly Disregarded
- **Category:** Category K — API Security Hardening
- **Objective:** Verify client cannot bypass biometric verification by asserting `is_live=True`, `verified=True`, or `confidence=0.999`.
- **Preconditions:** Enrolled student reference template.
- **Inputs & Setup:** Attacker submits non-matching face image while asserting full bypass flags in multipart form.
- **Execution Steps:**
  1. POST `/verify-attendance` with mismatched face and `is_live=True, verified=True, client_confidence=0.999`.
- **Expected Result:** Server disregards bypass flags, computes real CV embedding, flags mismatch, decides status `absent`.
- **Actual Result:** Status marked `absent` (`face_match=False`), server logs warning regarding client bypass assertions.
- **Pass/Fail Criteria:** Pass if client flags do not override server-side biometric inference.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`
- **Defect Reference:** SEC-008

---

### TC-SEC-014: Attendance Idempotency Key Handling & Retry Defense
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure retries with Idempotency-Key return previous decision idempotently; repeated non-idempotent check-ins are blocked.
- **Preconditions:** Enrolled student, open session.
- **Inputs & Setup:** Initial check-in with `Idempotency-Key: idemp-999`; second check-in with identical key; third check-in with different key.
- **Execution Steps:**
  1. Submit check-in with Idempotency-Key (Status 200 Present).
  2. Re-send identical request with same key.
  3. Submit check-in with different key.
- **Expected Result:** Step 2 returns 200 with `idempotent: True`; Step 3 returns 400 `ATTEMPT_LIMIT_REACHED`.
- **Actual Result:** Step 2 returned 200 Present idempotently; Step 3 blocked with 400 `ATTEMPT_LIMIT_REACHED`.
- **Pass/Fail Criteria:** Pass if identical retries replay safely and duplicate check-ins are blocked.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`
- **Defect Reference:** SEC-012

---

### TC-SEC-015: High-Concurrency Check-in Mutex Serialization
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure concurrent check-in requests for the same student/session are serialized transactionally without duplicates.
- **Preconditions:** Enrolled student, open session.
- **Inputs & Setup:** 5 concurrent worker threads in `ThreadPoolExecutor` simultaneously submitting check-ins at T=0.
- **Execution Steps:**
  1. Dispatch 5 concurrent check-in requests.
  2. Inspect HTTP status codes and database records.
- **Expected Result:** Exactly 1 request succeeds (200), remaining 4 rejected (400); exactly 1 attendance row in DB.
- **Actual Result:** Statuses: exactly one 200, four 400s; database contains exactly 1 attendance record.
- **Pass/Fail Criteria:** Pass if race conditions are eliminated by mutex serialization.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`
- **Defect Reference:** SEC-012

---

### TC-SEC-016: Schema Validation and Out-of-Range Parameters (HTTP 422)
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure Pydantic schemas reject out-of-range parameters and invalid enum values with HTTP 422.
- **Preconditions:** Authenticated teacher.
- **Inputs & Setup:** SessionCreate with `duration_minutes = 999` (>60); AttendanceUpdate with `status = "invalid_status_value"`.
- **Execution Steps:**
  1. POST `/api/sessions` with duration 999.
  2. PATCH `/api/sessions/s1/attendance/u1` with invalid status.
- **Expected Result:** Both requests return HTTP 422 Unprocessable Entity.
- **Actual Result:** Both requests returned HTTP 422 with detailed field validation errors.
- **Pass/Fail Criteria:** Pass if strict schema bounds reject invalid input.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/03_payload_limits_and_schema_validation.png`

---

### TC-SEC-017: Oversized Payload and Request Size Limits (HTTP 413)
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure requests exceeding maximum size limits return HTTP 413 PAYLOAD_TOO_LARGE at ASGI middleware and route levels.
- **Preconditions:** Server active.
- **Inputs & Setup:** (1) Request with `Content-Length: 20MB` (> 15MB limit); (2) File upload with 11MB image (> 10MB limit).
- **Execution Steps:**
  1. POST with Content-Length 20MB.
  2. POST verify-attendance with 11MB file upload.
- **Expected Result:** Both requests return HTTP 413.
- **Actual Result:** Request 1 returned 413 with `PAYLOAD_TOO_LARGE`; Request 2 returned 413 with `IMAGE_TOO_LARGE`.
- **Pass/Fail Criteria:** Pass if oversized payloads are rejected before memory exhaustion.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/03_payload_limits_and_schema_validation.png`
- **Defect Reference:** SEC-019

---

### TC-SEC-018: Corrupted and Unsupported Image Upload Rejection
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure zero-byte files and non-image files are rejected with appropriate error codes.
- **Preconditions:** Enrolled student, open session.
- **Inputs & Setup:** (1) 0-byte file upload; (2) HTML script file disguised as JPEG.
- **Execution Steps:**
  1. POST verify-attendance with empty byte file.
  2. POST verify-attendance with HTML script bytes.
- **Expected Result:** Empty file returns 400 `EMPTY_IMAGE`; non-image returns 415 `UNSUPPORTED_FORMAT`.
- **Actual Result:** Request 1 returned 400 `EMPTY_IMAGE`; Request 2 returned 415 `UNSUPPORTED_FORMAT`.
- **Pass/Fail Criteria:** Pass if invalid file payloads are rejected before processing.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/03_payload_limits_and_schema_validation.png`

---

### TC-SEC-019: Sliding-Window Rate Limiting Abuse Defense (HTTP 429)
- **Category:** Category K — API Security Hardening
- **Objective:** Ensure sliding-window rate limiter raises HTTP 429 when threshold is exceeded.
- **Preconditions:** Rate limiting active (`RATE_LIMIT_LOGIN_PER_MIN = 10`).
- **Inputs & Setup:** Client sends 12 rapid login requests within 60 seconds from same IP.
- **Execution Steps:**
  1. Dispatch 12 rapid login calls.
  2. Inspect response status codes.
- **Expected Result:** Requests 1-10 succeed or fail normally; requests 11-12 return HTTP 429 Too Many Requests.
- **Actual Result:** Request 11 returned HTTP 429 with detail "Rate limit exceeded. Try again in 60 seconds."
- **Pass/Fail Criteria:** Pass if burst traffic triggers rate limiting.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/03_payload_limits_and_schema_validation.png`

---

### TC-SEC-020: Global ASGI Exception Shield Sanitization (HTTP 500)
- **Category:** Category K — API Security Hardening
- **Objective:** Verify that unhandled server exceptions do not leak stack traces, database keys, or internal details to clients.
- **Preconditions:** Temporary test route `/api/test-shield-crash` configured to raise an unexpected internal exception containing a sensitive database key.
- **Inputs & Setup:** Send GET request triggering unhandled `KeyError("CRITICAL_INTERNAL_DATABASE_KEY_LEAK")`.
- **Execution Steps:**
  1. GET `/api/test-shield-crash`.
  2. Inspect response status and response body.
- **Expected Result:** HTTP 500 with generic JSON `{"detail": "Internal server error occurred. Please contact system administrator.", "error_code": "INTERNAL_SERVER_ERROR"}`; zero leakage of sensitive key string.
- **Actual Result:** HTTP 500 returned sanitized JSON; sensitive key string completely absent from response body.
- **Pass/Fail Criteria:** Pass if no internal exception details reach the client.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/05_sanitized_exception_shield.png`
- **Defect Reference:** SEC-020

---

### TC-SEC-021: Audit Log Redaction (Zero Credential & Biometric Leakage)
- **Category:** Category K — API Security Hardening
- **Objective:** Verify `_sanitize_audit_metadata` strips passwords, JWT tokens, and biometric embeddings from persisted audit entries.
- **Preconditions:** Server active.
- **Inputs & Setup:** Audit metadata payload containing `password`, `access_token`, `jwt`, `encrypted_embedding`, and 512-dim float array.
- **Execution Steps:**
  1. Dispatch `_audit()` with sensitive metadata dictionary.
  2. Retrieve persisted audit log record from database.
- **Expected Result:** Passwords and tokens masked to `[REDACTED]`; biometric vectors masked to `[BIOMETRIC_REDACTED]`.
- **Actual Result:** Sensitive fields scrubbed; zero raw credentials or vectors persisted in database.
- **Pass/Fail Criteria:** Pass if all sensitive fields are redacted.
- **Status:** PASS
- **Evidence:** `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/05_sanitized_exception_shield.png`
- **Defect Reference:** SEC-015

---

## Test Execution Summary Matrix

| Category | Planned Tests | Passed | Failed | Blocked | Not Run | Pass Rate |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| Category A: Functional Testing | 3 | 3 | 0 | 0 | 0 | 100% |
| Category B: Edge Cases | 4 | 4 | 0 | 0 | 0 | 100% |
| Category C: Liveness & Spoofing | 4 | 4 | 0 | 0 | 0 | 100% |
| Category D: API Security | 5 | 5 | 0 | 0 | 0 | 100% |
| Category E: Mobile Application | 8 | 8 | 0 | 0 | 0 | 100% |
| Category F: Performance & Latency | 1 | 1 | 0 | 0 | 0 | 100% |
| Category G: Accuracy & Limits | 1 | 1 | 0 | 0 | 0 | 100% |
| Category H: Adversarial Evaluation & PAD | 11 | 11 | 0 | 0 | 0 | 100% |
| Category I: Identity Verification & Anti-Proxy | 15 | 15 | 0 | 0 | 0 | 100% |
| Category K: API Security Hardening | 21 | 21 | 0 | 0 | 0 | 100% |
| **TOTAL** | **73** | **73** | **0** | **0** | **0** | **100%** |


