# Attendrix Comprehensive Security & Liveness Audit Report
**Execution Date:** 2026-10-27  
**Auditor:** Attendrix Senior Computer-Vision & Biometric Security Engineering Team  
**Scope:** Full-stack Biometric Attendance, Anti-Spoofing, Liveness Detection, API Contracts, and Session Security

---

## 1. Actual Project Structure

The Attendrix attendance platform is organized into three primary operational tiers:

```
SDTT-ATTENDANCE-SYSTEM-/
├── backend/                             # FastAPI Backend & Biometric Verification Engine
│   ├── app/
│   │   ├── main.py                      # FastAPI endpoints (Sessions, Auth, Verification, Controller)
│   │   ├── face_engine.py               # FaceEngine interface, RealFaceEngine (YuNet/SFace), FakeFaceEngine
│   │   ├── verification.py              # Continuous sweep verification pipeline (Rules 1–9)
│   │   ├── security.py                  # JWT Auth, AES-GCM-256 embedding encryption, rate limiting
│   │   ├── db.py                        # Supabase PostgREST client & InMemoryDatabase test harness
│   │   ├── config.py                    # Thresholds, timeouts, and environmental configuration
│   │   └── models/                      # Deep neural network weights
│   │       ├── face_detection_yunet.onnx      # OpenCV YuNet face detector with 5 landmarks
│   │       └── face_recognition_sface.onnx    # OpenCV SFace 128D deep feature extractor
│   ├── tests/                           # Pytest verification and security test suite
│   │   ├── test_api.py                  # Functional endpoints & auth test cases
│   │   ├── test_active_liveness.py      # Basic active liveness checks
│   │   ├── test_controller_and_reference.py # Controller tools & hall reference tests
│   │   ├── test_e2e_simulation.py       # End-to-end multi-role attendance simulations
│   │   ├── test_optical_feasibility.py  # Optical sensor & IPD feasibility tests
│   │   └── test_panorama_verification.py# Panorama room & crowd verification tests
│   └── requirements.txt                 # Python dependencies (fastapi, opencv-python, onnxruntime, etc.)
├── apps/
│   ├── mobile/                          # Flutter Mobile Client (Student, Teacher, Controller)
│   │   ├── lib/
│   │   │   ├── main.dart / app.dart     # Mobile app lifecycle, theme, and authentication routing
│   │   │   ├── screens/
│   │   │   │   ├── home_screen.dart     # Unified Student/Teacher/Controller college dashboard
│   │   │   │   ├── live_face_verification_screen.dart # Interactive camera scanning & liveness challenges
│   │   │   │   ├── sweep_capture_screen.dart # Sensor IMU-guided panoramic classroom capture
│   │   │   │   ├── enrollment_screen.dart    # Biometric reference face enrollment
│   │   │   │   └── controller_screen.dart    # Academic controller room & roster management
│   │   │   ├── state/app_state.dart     # Reactive app state management & HTTP API wrapper
│   │   │   └── services/api_client.dart # Multipart HTTP requests, timeouts, and token injection
│   │   └── pubspec.yaml                 # Flutter dependencies (flutter_floating_bottom_bar, percent_indicator, etc.)
│   └── dashboard/                       # React / Vite Web Dashboard
│       └── src/
│           ├── App.tsx                  # Controller & Teacher web portal
│           ├── api.ts                   # Backend client communication
│           └── styles.css               # College attendance interface styling
└── proof/                               # Evidence, logs, reports, and test verification suite
```

---

## 2. Existing Verification Flow

### A. Mobile Student Verification Flow (`live_face_verification_screen.dart`)
1. Student selects active session and opens `LiveFaceVerificationScreen`.
2. Camera initializes front sensor.
3. Client prompts student through hardcoded visual steps:
   - Step 1: Center Frontal face scan (`center`).
   - Step 2: Turn Head Left (`turnLeft`).
   - Step 3: Turn Head Right (`turnRight`).
   - Step 4: Blink Eyes (`blink`).
4. Client packages frames (`face_image`, `face_left`, `face_right`, `face_blink`) into multipart form data.
5. Client issues `POST /api/sessions/{session_id}/verify-attendance`.
6. UI displays verified status ("Present"), pending review, or error message.

### B. Backend Verification Flow (`main.py` -> `verify_student_live_attendance`)
1. **Authentication:** Validates Bearer token and ensures role is student.
2. **Session Gate:** Validates session exists and status is `open`.
3. **Enrollment Check:** Checks `face_templates` table for registered reference embedding.
4. **Single-Attempt Check:** Checks `attendance` table for existing record (`attempted == True`).
5. **Face Detection:** Calls `engine.detect_faces(img_face, allow_fallback=True)`.
6. **Dominant Face Extraction:** Picks largest face by bounding box area (`bbox_w * bbox_h`).
7. **Identity Matching (1:N):** Computes cosine similarity between live face embedding and all enrolled templates.
   - If candidate similarity > 0.45 and matches caller: Face verified.
   - If candidate similarity > 0.65 and matches another enrolled student: Proxy rejected.
8. **Classroom Panorama Verification:** Verifies classroom image if supplied (checks lecturer presence and peer crowd count).
9. **Active Liveness:** Calls `engine.verify_active_liveness(frontal_img, left_img, right_img, blink_img)`.
10. **Persistence & Audit:** Upserts into `attendance` table with `status` (`present`, `pending`, `absent`), writes audit log entry, and emits WebSocket event.

---

## 3. Components Implemented vs. Mocked

| Component | Status | Implementation Details |
| :--- | :--- | :--- |
| **Face Detection** | **Implemented** | OpenCV `FaceDetectorYN` (YuNet ONNX model, 5 landmarks: right/left eye, nose, mouth corners). |
| **Face Embedding** | **Implemented** | OpenCV SFace deep feature extractor (`face_recognition_sface.onnx`, 128D cosine-normalized). |
| **Head Yaw Estimation** | **Implemented** | Geometric landmark displacement ratio ($dx / IPD \times 90^\circ$). |
| **Eye Openness / Blink** | **Partially Implemented** | Vertical Sobel gradient energy around eye coordinates. (Defect: Fallback always returned `blink_ok = True`). |
| **Active Challenge Nonces** | **Mocked / Missing** | Mobile client uses fixed hardcoded sequence. Backend did not generate server-side signed challenge tokens. |
| **Replay Prevention** | **Missing** | Backend did not cache perceptual hashes (pHash) or SHA-256 digests; identical images could be submitted across sessions. |
| **Image Quality Screening** | **Partially Implemented** | Minimal luminance and blur checks in sweep verification, but completely bypassed in `verify-attendance`. |
| **Attendance Uniqueness** | **Implemented** | Checked in application code (`attempted == True`) and database `(session_id, student_id)` constraint. |
| **Proxy Shield** | **Implemented** | 1:N matching flags attendance if scanned face matches another enrolled peer rather than caller. |

---

## 4. Identified Vulnerabilities and Reliability Defects

### Vulnerability 1: Synthetic Face Fallback Bypasses No-Face Detection (CRITICAL)
- **File:** `backend/app/face_engine.py` (lines 452–470) & `backend/app/main.py` (line 1858)
- **Defect:** `detect_faces` had `allow_fallback=True` enabled during live student verification. When no face was detected by YuNet, if the image had mean luminance $\ge 4.0$ and Laplacian variance $\ge 0.5$ (e.g., a wall, desk, or blank object), a synthetic bounding box and landmarks were generated.
- **Impact:** An attacker could point the camera at a textured surface and bypass the "no face detected" gate.

### Vulnerability 2: Missing Challenges Defaulted to Passed (HIGH)
- **File:** `backend/app/face_engine.py` (lines 262–267) & `backend/app/main.py` (line 1965)
- **Defect:** In `verify_active_liveness`, `challenges_passed` was initialized to `True`. If `left_img`, `right_img`, and `blink_img` were omitted by an API caller, the liveness check returned `liveness_passed: True`.
- **Impact:** An attacker using a direct HTTP client could submit a single printed photograph or static image and pass verification without performing any active head movement or blink.

### Vulnerability 3: Lack of Server-Side Dynamic Challenge Tokens (HIGH)
- **Defect:** The system lacked an active challenge issuance mechanism. Challenges were statically expected in the order: Center $\to$ Left $\to$ Right $\to$ Blink.
- **Impact:** Predictable sequence allowed replay of pre-recorded videos captured from previous sessions.

### Vulnerability 4: Absence of Replay Attack Cache (HIGH)
- **Defect:** `verify-attendance` did not check if the submitted image bytes or perceptual hash (pHash) matched any previously recorded verification attempt.
- **Impact:** An attacker who intercepted a legitimate student's verification payload could replay the identical image bytes in a future session.

### Vulnerability 5: Permissive Image Quality Gates (MEDIUM)
- **Defect:** `verify-attendance` lacked explicit pre-screening for severe blur (Laplacian variance $< 40$), underexposure ($< 35$), overexposure ($> 225$), face too small ($< 8\%$ frame area), and multiple faces.
- **Impact:** Low-quality or ambiguous captures caused unpredictable false matches or silent failures.

### Vulnerability 6: SFace Model Disconnect (HIGH)
- **Defect:** `face_engine.py` searched only for `arcface_path` with onnxruntime, while `face_recognition_sface.onnx` existed in `models/` but was not loaded by `cv2.FaceRecognizerSF`.
- **Impact:** Fallback spatial gradient feature extractor was used instead of true deep learning facial embeddings.

---

## 5. Changes Required and Remediation Plan

1. **Disable Synthetic Fallback in Security-Critical Paths:**
   - Remove `allow_fallback=True` from `verify_student_live_attendance` and `detect_head_pose_and_liveness`. Return strict `IMAGE_QUALITY_NO_FACE` when YuNet detects 0 faces.
2. **Implement Server-Side Cryptographic Challenge Tokens:**
   - Add endpoint `POST /api/sessions/{session_id}/liveness-challenge`.
   - Generates HMAC-SHA256 signed token containing `session_id`, `user_id`, timestamp, and a randomized sequence of challenges (e.g., `["turn_right", "blink"]` or `["turn_left", "turn_right"]`).
   - Token expires in 90 seconds and can be used strictly once (single-use nonce cache).
3. **Enforce Mandatory Liveness Challenge Verification:**
   - Require `challenge_token` in `verify-attendance`. Validate signature, expiry, and single-use status.
   - Verify that all challenge frames specified in the token are provided and meet the exact action criteria.
4. **Implement Image Replay Detection (SHA-256 + pHash Cache):**
   - Compute 64-bit DCT perceptual hash (pHash) and SHA-256 digest on submitted frontal face frames.
   - Compare against historical submissions: reject identical images (Hamming distance $\le 4$ or SHA-256 match).
5. **Implement Pre-Verification Image Quality Screening:**
   - Check Laplacian blur variance ($< 40 \implies \text{rejected}$).
   - Check mean luminance ($< 35 \lor > 225 \implies \text{rejected}$).
   - Check face count: exactly 1 face permitted in frontal scan. If $\ge 2$, reject with `IMAGE_QUALITY_MULTIPLE_FACES`.
   - Check face size ($IPD \ge 45\text{px}$ and bounding box $\ge 7\%$ frame area).
   - Check boundary clearance (face not clipped off-screen).
6. **Connect Official SFace Deep Recognition Engine:**
   - Configure `cv2.FaceRecognizerSF.create` to load `face_recognition_sface.onnx` for 128D aligned embeddings.

---

## 6. Environment and Hardware Limitations

1. **Physical Headless Server vs. Camera Input:**
   - The primary test runner runs in a Linux container/host with `/dev/video0` and `/dev/video1` accessible, and an Android hardware device attached via ADB (`RZCY2279EPE`).
   - For automated backend regression testing, deterministic synthetic images and realistic photographic test fixtures (consenting / synthetic faces) are utilized to validate biometric pass/fail boundaries.
2. **Single Camera Stream:**
   - Passive RGB capture cannot natively measure 3D time-of-flight depth. True defense against high-grade 3D silicon masks requires hardware-assisted depth cameras or structured light sensors; this physical boundary is explicitly documented.
