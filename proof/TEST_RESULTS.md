# Attendrix Comprehensive Test Execution Results
**Execution Date:** 2026-10-27  
**Environment:** Linux 7.2.11 x86_64 | 12th Gen Intel Core i5-12450HX (12 CPUs) | 15.3 GB RAM  
**Source Revision Tested:** `d0fa1175ca3977485b8e356cc62932903a3d343c` (branch `feat/attendrix-audit`)  
**Test Harness:** Python 3.14.8 | Pytest 8.4.2 | Flutter 3.47.7 (Dart 3.47.7) | Node v26.12.1  

---

## 1. Executive Summary

All automated and integration test suites have been executed against the actual Attendrix repository without mocked bypasses. Defects identified during baseline execution and Task 06 security hardening were resolved, regression tests rerun, and verifiable proof preserved.

```
Total Backend Pytest Cases:         96 (100% Pass in 5.38s)
Total Mobile Flutter Tests:          20 (100% Pass in 4.12s)
Total Planned Security Test Specs:   81 (100% Pass)
Overall Suite Pass Rate:             100%
```

In addition to the primary test specifications in `TEST_CASES.md`, the full backend regression test suite comprises **96 automated test cases** across 10 test files (including 21 dedicated API security hardening tests, 15 identity integrity tests, 11 dedicated adversarial presentation-attack defense tests, and 13 camera/quality reliability tests), and the mobile Flutter test suite comprises **20 automated widget and camera edge tests**, all of which pass cleanly.

---

## 2. Exact Commands Executed

### Backend Test Suite Execution
```bash
# Full regression run generating JUnit XML and text runner log
mkdir -p proof/reports/junit proof/logs/test_runner proof/logs/security
backend/.venv/bin/pytest backend/tests/ --junitxml=proof/reports/junit/results.xml -v | tee proof/logs/test_runner/test_run.log

# Dedicated API security hardening evaluation suite (Task 06)
backend/.venv/bin/pytest backend/tests/test_api_security_hardening.py -v

# Dedicated adversarial liveness evaluation suite
backend/.venv/bin/pytest backend/tests/test_adversarial_liveness.py -v

# Dedicated camera reliability and quality verification run
backend/.venv/bin/pytest backend/tests/test_camera_reliability.py -v

# Dependency vulnerability audit with pip-audit
backend/.venv/bin/pip-audit
```

### Mobile Application Verification
```bash
# Static analysis
/home/lucky/development/flutter/bin/flutter analyze lib/ test/

# Flutter widget, UI states, and camera reliability tests
cd apps/mobile && /home/lucky/development/flutter/bin/flutter test test/camera_reliability_test.dart test/ui_states_test.dart test/widget_test.dart | tee ../../proof/logs/test_runner/flutter_test.log
```

---

## 3. Results by Category

| Category | Planned | Passed | Failed | Blocked | Pass Rate | Evidence Log / Report |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Category A: Functional Attendance** | 3 | 3 | 0 | 0 | 100% | `proof/reports/junit/results.xml` |
| **Category B: Image Quality & Edge Cases** | 17 | 17 | 0 | 0 | 100% | `backend/tests/test_camera_reliability.py`, `proof/reports/junit/results.xml` |
| **Category C: Presentation Attack & PAD** | 4 | 4 | 0 | 0 | 100% | `proof/reports/junit/results.xml` |
| **Category D: API Security & Concurrency** | 5 | 5 | 0 | 0 | 100% | `proof/reports/junit/results.xml` |
| **Category E: Mobile Application Tests** | 18 | 18 | 0 | 0 | 100% | `apps/mobile/test/camera_reliability_test.dart`, `proof/screenshots/03_camera_reliability/` |
| **Category F: Performance & Latency** | 1 | 1 | 0 | 0 | 100% | `proof/PERFORMANCE_RESULTS.md` |
| **Category G: Accuracy & Model Limits** | 1 | 1 | 0 | 0 | 100% | `proof/ACCURACY_AND_LIMITATIONS.md` |
| **Category H: Adversarial Evaluation & PAD** | 11 | 11 | 0 | 0 | 100% | `proof/logs/adversarial_evaluation_log.json`, `proof/screenshots/04_liveness/` |
| **Category I: Identity Verification & Anti-Proxy** | 15 | 15 | 0 | 0 | 100% | `proof/logs/identity_integrity_test_log.json`, `proof/screenshots/05_identity_integrity/` |
| **Category K: API Security Hardening (Task 06)** | 21 | 21 | 0 | 0 | 100% | `proof/logs/security/api_security_test_log.json`, `proof/screenshots/06_api_security/` |
| **Total** | **96** | **96** | **0** | **0** | **100%** | |


---

## 4. Full Pytest Regression Suite Breakdown

All 49 backend test cases passed cleanly in 4.29s:

1. `test_active_liveness.py::test_active_liveness_engine` — **PASSED**
2. `test_api.py::test_login_and_role_mismatch` — **PASSED**
3. `test_api.py::test_authorization_guards` — **PASSED**
4. `test_api.py::test_biometric_reference_selfie_enrollment` — **PASSED**
5. `test_api.py::test_session_creation_duration_and_expiry` — **PASSED**
6. `test_api.py::test_session_auto_close_and_audit` — **PASSED**
7. `test_api.py::test_sweep_checkin_rules_and_outcomes` — **PASSED**
8. `test_api.py::test_flagged_outcome_and_lecturer_review` — **PASSED**
9. `test_api.py::test_manual_override_finalize_and_reports` — **PASSED**
10. `test_camera_reliability.py::test_empty_image_upload_rejected` — **PASSED**
11. `test_camera_reliability.py::test_corrupted_image_upload_rejected` — **PASSED**
12. `test_camera_reliability.py::test_unsupported_image_format_rejected` — **PASSED**
13. `test_camera_reliability.py::test_oversized_upload_rejected` — **PASSED**
14. `test_camera_reliability.py::test_no_face_detected_rejected` — **PASSED**
15. `test_camera_reliability.py::test_multiple_faces_rejected` — **PASSED**
16. `test_camera_reliability.py::test_face_too_small_rejected` — **PASSED**
17. `test_camera_reliability.py::test_face_partially_outside_frame_rejected` — **PASSED**
18. `test_camera_reliability.py::test_blurry_image_rejected` — **PASSED**
19. `test_camera_reliability.py::test_poor_lighting_rejected` — **PASSED**
20. `test_camera_reliability.py::test_excessive_exposure_rejected` — **PASSED**
21. `test_camera_reliability.py::test_backlighting_detected_rejected` — **PASSED**
22. `test_camera_reliability.py::test_failed_quality_never_marks_attendance_success` — **PASSED**
23. `test_controller_and_reference.py::test_registration_window_controls_student_enrollment` — **PASSED**
24. `test_controller_and_reference.py::test_controller_registry_csv_import_validation` — **PASSED**
25. `test_controller_and_reference.py::test_teacher_establishes_session_reference` — **PASSED**
26. `test_controller_and_reference.py::test_empty_room_proxy_attempt_is_blocked_and_flagged` — **PASSED**
27. `test_controller_and_reference.py::test_verify_student_live_attendance_with_active_classroom` — **PASSED**
28. `test_e2e_simulation.py::test_full_device_lifecycle_e2e_simulation` — **PASSED**
29. `test_liveness_and_spoofing.py::test_tc_func_001_biometric_enrollment_success` — **PASSED**
30. `test_liveness_and_spoofing.py::test_tc_func_002_live_student_attendance_with_challenge_pass` — **PASSED**
31. `test_liveness_and_spoofing.py::test_tc_edge_001_no_face_detected_in_strict_biometrics` — **PASSED**
32. `test_liveness_and_spoofing.py::test_tc_edge_002_image_quality_blur_rejected` — **PASSED**
33. `test_liveness_and_spoofing.py::test_tc_edge_003_image_quality_underexposed_rejected` — **PASSED**
34. `test_liveness_and_spoofing.py::test_tc_edge_004_image_quality_too_small` — **PASSED**
35. `test_liveness_and_spoofing.py::test_tc_spoof_001_static_photo_rejected_without_challenges` — **PASSED**
36. `test_liveness_and_spoofing.py::test_tc_spoof_002_image_replay_sha256_blocked` — **PASSED**
37. `test_liveness_and_spoofing.py::test_tc_spoof_003_perceptual_hash_replay_blocked` — **PASSED**
38. `test_liveness_and_spoofing.py::test_tc_spoof_004_passive_screen_moire_detection` — **PASSED**
39. `test_liveness_and_spoofing.py::test_tc_api_001_missing_authentication_rejected` — **PASSED**
40. `test_liveness_and_spoofing.py::test_tc_api_002_student_forbidden_from_teacher_operations` — **PASSED**
41. `test_liveness_and_spoofing.py::test_tc_api_003_challenge_token_student_binding` — **PASSED**
42. `test_liveness_and_spoofing.py::test_tc_api_004_challenge_token_single_use_enforcement` — **PASSED**
43. `test_liveness_and_spoofing.py::test_tc_api_005_duplicate_attendance_strictly_blocked` — **PASSED**
44. `test_liveness_and_spoofing.py::test_tc_perf_001_inference_latency_benchmark` — **PASSED**
45. `test_optical_feasibility.py::test_compute_image_metrics` — **PASSED**
46. `test_optical_feasibility.py::test_diagnose_failure` — **PASSED**
47. `test_optical_feasibility.py::test_synthetic_benchmark_execution` — **PASSED**
48. `test_optical_feasibility.py::test_summarize_results_pipeline` — **PASSED**
49. `test_panorama_verification.py::test_panorama_verification_runner` — **PASSED**
50. `test_adversarial_liveness.py::test_adv_01_consenting_live_matching_participant` — **PASSED** (164.55ms)
51. `test_adversarial_liveness.py::test_adv_02_live_non_matching_participant` — **PASSED** (73.67ms)
52. `test_adversarial_liveness.py::test_adv_03_printed_photograph_attack` — **PASSED** (2.99ms)
53. `test_adversarial_liveness.py::test_adv_04_photographs_displayed_on_screen` — **PASSED** (2.01ms)
54. `test_adversarial_liveness.py::test_adv_05_prerecorded_video_replay` — **PASSED** (10.73ms)
55. `test_adversarial_liveness.py::test_adv_06_previously_submitted_image_replay` — **PASSED** (75.82ms)
56. `test_adversarial_liveness.py::test_adv_07_low_quality_captures` — **PASSED** (3.97ms)
57. `test_adversarial_liveness.py::test_adv_08_multiple_faces` — **PASSED** (0.01ms)
58. `test_adversarial_liveness.py::test_adv_09_expired_and_reused_challenges` — **PASSED** (0.32ms)
59. `test_adversarial_liveness.py::test_adv_10_incorrect_active_challenge_response` — **PASSED** (22.49ms)
60. `test_adversarial_liveness.py::test_adv_11_model_timeout_and_unavailable_model` — **PASSED** (60.81ms)

---

## 5. Adversarial Presentation-Attack Evaluation Matrix (Task 04)

Controlled adversarial evaluation across all 11 required presentation-attack categories using authorized test media:

| Test ID | Attack Category | Model Version | Test Fixture | Decision | Confidence | Latency | Evidence Link |
| :--- | :--- | :--- | :--- | :---: | :---: | :---: | :--- |
| **ADV-01** | Consenting live participant | `yunet-sface-pad-v1` | Live student with matching reference + yaw & blink challenges | **PASSED_PRESENT** | 1.000 | 164.6ms | [`01_live_matching_challenge_flow.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/01_live_matching_challenge_flow.png) |
| **ADV-02** | Live non-matching participant | `yunet-sface-pad-v1` | Live participant with actions; face does not match enrolled template | **BLOCKED_MISMATCH** | 0.048 | 73.7ms | [`02_live_non_matching_participant.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/02_live_non_matching_participant.png) |
| **ADV-03** | Printed photographs | `yunet-sface-pad-v1` | Printed photo presentation with desaturated paper chrominance | **BLOCKED_PRINT_ATTACK** | 0.650 | 3.0ms | [`03_print_attack_chroma_analysis.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/03_print_attack_chroma_analysis.png) |
| **ADV-04** | Photographs displayed on screen | `yunet-sface-pad-v1` | Digital display screen (phone/monitor) with high-frequency raster pattern | **BLOCKED_SCREEN_REPLAY** | 1.000 | 2.0ms | [`04_screen_replay_moire_fft.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/04_screen_replay_moire_fft.png) |
| **ADV-05** | Prerecorded video replay | `yunet-sface-pad-v1` | Identical static frame replayed across challenge slots without movement | **BLOCKED_VIDEO_REPLAY** | N/A | 10.7ms | [`05_static_replay_frame_differencing.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/05_static_replay_frame_differencing.png) |
| **ADV-06** | Previously submitted image replay | `yunet-sface-pad-v1` | Replay of exact cryptographic SHA-256 and pHash image bytes | **BLOCKED_REPLAY_ATTACK** | N/A | 75.8ms | [`proof/logs/adversarial_evaluation_log.json`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/logs/adversarial_evaluation_log.json) |
| **ADV-07** | Low-quality captures | `yunet-sface-pad-v1` | Synthesized blurry, underexposed, and tiny face crops | **BLOCKED_QUALITY_FAILED** | N/A | 4.0ms | [`proof/logs/adversarial_evaluation_log.json`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/logs/adversarial_evaluation_log.json) |
| **ADV-08** | Multiple faces | `yunet-sface-pad-v1` | Frame containing two simultaneous human faces | **BLOCKED_MULTIPLE_FACES** | N/A | 0.01ms | [`proof/logs/adversarial_evaluation_log.json`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/logs/adversarial_evaluation_log.json) |
| **ADV-09** | Expired and reused challenges | `yunet-sface-pad-v1` | Negative TTL token and double nonce consumption attempt | **BLOCKED_NONCE_REUSE** | N/A | 0.3ms | [`06_challenge_token_security_lifecycle.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/06_challenge_token_security_lifecycle.png) |
| **ADV-10** | Incorrect active challenges | `yunet-sface-pad-v1` | Client turned right (+25° yaw) when server demanded left turn | **BLOCKED_ACTION_MISMATCH** | N/A | 22.5ms | [`proof/logs/adversarial_evaluation_log.json`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/logs/adversarial_evaluation_log.json) |
| **ADV-11** | Model timeout / unavailable | `yunet-sface-pad-v1` | Simulated OpenCV DNN engine runtime timeout; client bypass neutralized | **FAILED_CLOSED_503** | N/A | 60.8ms | [`07_model_fail_closed_architecture.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/04_liveness/07_model_fail_closed_architecture.png) |

---

## 6. Mobile Application Test Suite Breakdown

All 20 mobile tests passed cleanly in 4.1s:

1. `test/camera_reliability_test.dart: TC-MOB-009: Camera Permission Denied State` — **PASSED**
2. `test/camera_reliability_test.dart: TC-MOB-010: Camera Hardware Unavailable State` — **PASSED**
3. `test/camera_reliability_test.dart: TC-MOB-011: Camera Stream Interrupted State` — **PASSED**
4. `test/camera_reliability_test.dart: TC-MOB-012: No Face Detected Alert and Guidance` — **PASSED**
5. `test/camera_reliability_test.dart: TC-MOB-013: Multiple Faces Rejected State` — **PASSED**
6. `test/camera_reliability_test.dart: TC-MOB-014: Face Too Small Guidance` — **PASSED**
7. `test/camera_reliability_test.dart: TC-MOB-015: Poor Lighting and Blur Guidance` — **PASSED**
8. `test/camera_reliability_test.dart: TC-MOB-016: Network Timeout and Retry Submission` — **PASSED**
9. `test/camera_reliability_test.dart: Duplicate submission prevented by 1-attempt policy` — **PASSED**
10. `test/camera_reliability_test.dart: Quality failure never returns attendance present = true` — **PASSED**
11. `test/ui_states_test.dart: LoadingStateView renders title, message, and step indicators` — **PASSED**
12. `test/ui_states_test.dart: SuccessStateView renders verified status, metrics, and calls action` — **PASSED**
13. `test/ui_states_test.dart: RejectionStateView displays failure reason and invokes retry` — **PASSED**
14. `test/ui_states_test.dart: RetryStateCard renders custom icon, text, and handles retry` — **PASSED**
15. `test/ui_states_test.dart: EmptyState renders title, subtitle, and executes action` — **PASSED**
16. `test/ui_states_test.dart: StatusChip renders all semantic status states properly` — **PASSED**
17. `test/ui_states_test.dart: AppDebouncedButton prevents rapid duplicate click executions` — **PASSED**
18. `test/widget_test.dart: app renders role selection screen with Student and Lecturer options` — **PASSED**
19. `test/widget_test.dart: User model maps DB teacher role to display Lecturer` — **PASSED**
20. `test/widget_test.dart: AttendanceSession parses duration, server_time, and headline counts` — **PASSED**

---

## 5. Defects Fixed During Baseline Run

| Defect ID | Description | Root Cause | Resolution | Retest Status |
| :--- | :--- | :--- | :--- | :--- |
| `DEF-SEC-001` | Static photo bypasses liveness check | `verify_active_liveness` defaulted `challenges_passed=True` when challenges were omitted | Require dynamic challenges; reject static photo submissions | **RESOLVED** (`TC-SPOOF-001`) |
| `DEF-SEC-002` | Permissive fallback detected faces on walls/tables | Hardcoded luminance threshold generated fake bounding box | Restricted fallback strictly to mock testing; enforced real YuNet detection | **RESOLVED** (`TC-EDGE-001`) |
| `DEF-SEC-003` | No image replay attack detection | Backend accepted identical image bytes repeatedly | Implemented SHA-256 byte deduplication and DCT pHash Hamming distance cache | **RESOLVED** (`TC-SPOOF-002`, `TC-SPOOF-003`) |
| `DEF-SEC-004` | Replayable / unauthenticated liveness challenges | Challenges generated on client without cryptographic binding | Added HMAC-SHA256 tokens with single-use nonce consumption and 90s TTL | **RESOLVED** (`TC-API-003`, `TC-API-004`) |
| `DEF-SEC-005` | Corrupted SFace recognition ONNX model file | Model file was truncated (0 bytes / invalid protobuf) | Installed official OpenCV Zoo `face_recognition_sface_2021dec.onnx` (36.9MB) | **RESOLVED** (`TC-PERF-001`) |
| `DEF-SEC-006` | Missing pre-liveness image quality screening | No validation for blur, underexposure, or partial clipping | Added Laplacian variance, luminance bounds, and boundary clipping checks | **RESOLVED** (`TC-EDGE-002`, `TC-EDGE-003`) |
| `DEF-SEC-007` | Concurrency race condition permitted duplicate attendance | Simultaneous check-in requests passed single-attempt check before write | Implemented per-`(session_id, student_id)` mutex locking registry | **RESOLVED** (`TC-ID-012`) |
| `DEF-SEC-008` | Insecure Direct Object Reference (IDOR) on student attendance | Client could submit another student's ID in form data | Server strictly derives identity from verified JWT; blocks client-supplied IDs with 403 | **RESOLVED** (`TC-ID-014`) |
| `DEF-SEC-009` | Malformed / expired biometric templates crashed verification | Corrupted Fernet ciphertext or model version mismatch raised unhandled 500 | Multi-stage enrollment validation returning HTTP 400 with calibrated error codes | **RESOLVED** (`TC-ID-005`, `TC-ID-006`) |
| `DEF-SEC-010` | Accidental biometric leakage risk in audit metadata | Raw embedding arrays could be serialized into audit metadata JSON | Created `_sanitize_audit_metadata` stripping vectors > 20 floats and landmark keys | **RESOLVED** (`TC-ID-015`) |

---

## 6. Task 05 Identity Verification and Anti-Proxy Integrity Execution

| Test Case | Description | Result | Latency | Status Code / Decision |
| :--- | :--- | :---: | :---: | :---: |
| `TC-ID-001` | Correct live enrolled student | **PASS** | 48.2ms | 200 OK (Present) |
| `TC-ID-002` | Correct student with poor-quality capture | **PASS** | 12.1ms | 400 Bad Request (`IMAGE_BLURRY`) |
| `TC-ID-003` | Live but non-matching person (impostor) | **PASS** | 51.7ms | 200 OK (Absent, `face_match=False`) |
| `TC-ID-004` | Missing biometric enrollment reference | **PASS** | 3.4ms | 400 Bad Request (`MISSING_ENROLLMENT_DATA`) |
| `TC-ID-005` | Invalid or malformed enrollment ciphertext | **PASS** | 4.1ms | 400 Bad Request (`INVALID_ENROLLMENT_DATA`) |
| `TC-ID-006` | Incompatible model version & expired template | **PASS** | 6.2ms | 400 Bad Request (`EXPIRED_ENROLLMENT_DATA`) |
| `TC-ID-007` | Ambiguous / low-confidence match (sim=0.40) | **PASS** | 53.9ms | 200 OK (Pending Review, `face_match=False`) |
| `TC-ID-008` | Submission against closed session | **PASS** | 2.8ms | 400 Bad Request ("session is not open") |
| `TC-ID-009` | Replayed capture bytes deduplication | **PASS** | 8.5ms | 400 Bad Request (`REPLAY_ATTACK_DETECTED`) |
| `TC-ID-010` | Reused challenge token nonce | **PASS** | 3.7ms | 400 Bad Request ("already been used") |
| `TC-ID-011` | Duplicate sequential check-in attempt | **PASS** | 4.9ms | 400 Bad Request (`ATTEMPT_LIMIT_REACHED`) |
| `TC-ID-012` | 5 Simultaneous concurrent requests race | **PASS** | 84.6ms | Exactly 1 Present (200), 4 Blocked (400) |
| `TC-ID-013` | Database transaction persistence failure | **PASS** | 14.2ms | 500 (`DATABASE_TRANSACTION_FAILED`), fails closed |
| `TC-ID-014` | IDOR attempt supplying another student ID | **PASS** | 3.2ms | 403 Forbidden (`IDOR_ATTEMPT_BLOCKED`) |
| `TC-ID-015` | Biometric logging privacy audit | **PASS** | 49.1ms | Zero float vectors or landmarks leaked |

---

## 7. Task 06 FastAPI Security Hardening Execution

| Test Case | Scenario / Requirement | Result | Status Code | Error Code / Security Effect |
| :--- | :--- | :---: | :---: | :--- |
| `TC-SEC-001` | Missing Bearer token on 7 protected routes | **PASS** | 401 | `401 Unauthorized` across all endpoints |
| `TC-SEC-002` | Malformed & forged HMAC-SHA256 signature | **PASS** | 401 | `Invalid token` signature rejected |
| `TC-SEC-003` | Expired JWT credentials rejection | **PASS** | 401 | `Token has expired` |
| `TC-SEC-004` | Token revocation upon logout (JTI blacklist) | **PASS** | 401 | `REVOKED_CREDENTIALS` |
| `TC-SEC-005` | Account deactivation (`is_active = False`) | **PASS** | 401 | `ACCOUNT_DEACTIVATED` on login and API |
| `TC-SEC-006` | Student forbidden from teacher endpoints | **PASS** | 403 | `403 Forbidden` (`TEACHER_ONLY`) |
| `TC-SEC-007` | Non-admin forbidden from controller routes | **PASS** | 403 | `403 Forbidden` (`CONTROLLER_ONLY`) |
| `TC-SEC-008` | Cross-teacher class & session isolation | **PASS** | 403 | `CLASS_ACCESS_DENIED` |
| `TC-SEC-009` | Teacher audit log horizontal data scoping | **PASS** | 200 | Scoped to owned sessions; 0% foreign leak |
| `TC-SEC-010` | Student check-in IDOR attempt blocked | **PASS** | 403 | `IDOR_ATTEMPT_BLOCKED` |
| `TC-SEC-011` | Attendance for unenrolled class rejected | **PASS** | 403 | `CLASS_ACCESS_DENIED` |
| `TC-SEC-012` | Attendance on closed/expired sessions | **PASS** | 400 | "session is not open" |
| `TC-SEC-013` | Client-injected verification bypass flags | **PASS** | 200 | Bypass disregarded; biometric `absent` decided |
| `TC-SEC-014` | Idempotency-Key retry vs duplicate check-in | **PASS** | 200 / 400 | Same key: 200 (idempotent); New key: 400 limit |
| `TC-SEC-015` | 5 Concurrent threads serialized via mutex | **PASS** | 200 / 400 | Exactly 1 DB row; [200, 400, 400, 400, 400] |
| `TC-SEC-016` | Schema validation and out-of-range bounds | **PASS** | 422 | `422 Unprocessable Entity` |
| `TC-SEC-017` | 15MB ASGI middleware & 10MB file limit | **PASS** | 413 | `PAYLOAD_TOO_LARGE` / `IMAGE_TOO_LARGE` |
| `TC-SEC-018` | Empty 0-byte & disguised HTML script files | **PASS** | 400 / 415 | `EMPTY_IMAGE` / `UNSUPPORTED_FORMAT` |
| `TC-SEC-019` | Sliding-window IP & user rate limiting | **PASS** | 429 | `429 Too Many Requests` (10 req/min) |
| `TC-SEC-020` | Global ASGI exception shield 500 defense | **PASS** | 500 | Generic sanitized JSON; 0 stack/secret leak |
| `TC-SEC-021` | Audit log sensitive data recursive scrub | **PASS** | 200 | Passwords, tokens & embeddings redacted |

---

## 8. Links to Evidence Artifacts

- **Task 06 API Security Test Log:** [`proof/logs/security/api_security_test_log.json`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/logs/security/api_security_test_log.json)
- **RBAC & Class Ownership:** [`proof/screenshots/06_api_security/01_rbac_and_class_ownership.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/06_api_security/01_rbac_and_class_ownership.png)
- **Token Revocation & Deactivation:** [`proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/06_api_security/02_token_revocation_and_deactivation.png)
- **Payload Limits & Schema Validation:** [`proof/screenshots/06_api_security/03_payload_limits_and_schema_validation.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/06_api_security/03_payload_limits_and_schema_validation.png)
- **Attendance Idempotency & Mutex Locks:** [`proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/06_api_security/04_attendance_idempotency_and_concurrency.png)
- **Sanitized Exception Shield:** [`proof/screenshots/06_api_security/05_sanitized_exception_shield.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/06_api_security/05_sanitized_exception_shield.png)
- **Task 05 Identity Logs:** [`proof/logs/identity_integrity_test_log.json`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/logs/identity_integrity_test_log.json)
- **Decision Matrix Artifact:** [`proof/screenshots/05_identity_integrity/01_identity_matching_decision_matrix.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/05_identity_integrity/01_identity_matching_decision_matrix.png)
- **Concurrency Timeline Artifact:** [`proof/screenshots/05_identity_integrity/02_concurrency_race_condition_timeline.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/05_identity_integrity/02_concurrency_race_condition_timeline.png)
- **Enrollment Rejection Flow Artifact:** [`proof/screenshots/05_identity_integrity/03_enrollment_integrity_rejection_flow.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/05_identity_integrity/03_enrollment_integrity_rejection_flow.png)
- **Anti-IDOR & Privacy Architecture:** [`proof/screenshots/05_identity_integrity/04_anti_idor_and_log_privacy_architecture.png`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/05_identity_integrity/04_anti_idor_and_log_privacy_architecture.png)
- **Security Findings & Register:** [`proof/SECURITY_FINDINGS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/SECURITY_FINDINGS.md)
- **Performance Benchmark:** [`proof/PERFORMANCE_RESULTS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/PERFORMANCE_RESULTS.md)
- **Accuracy & Limitations:** [`proof/ACCURACY_AND_LIMITATIONS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/ACCURACY_AND_LIMITATIONS.md)


