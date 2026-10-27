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
| **TOTAL** | **26** | **26** | **0** | **0** | **0** | **100%** |
