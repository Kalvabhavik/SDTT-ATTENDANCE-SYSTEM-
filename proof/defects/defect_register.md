# Attendrix Security & Reliability Defect Register
**Updated:** 2026-10-27  
**Status:** All 8 Tracked Defects Successfully Remediated and Verified  

| Defect ID | Severity | Component | Summary | Status | Remediation | Retest Result |
| :--- | :--- | :--- | :--- | :---: | :--- | :--- |
| **DEF-SEC-001** | **CRITICAL** | `backend/app/face_engine.py` | Synthetic face fallback generates false face on textured non-faces when `allow_fallback=True`. | **RESOLVED** | Restricted fallback strictly to mock testing; enforced real YuNet face detection for all live verification. | **PASS** (`TC-EDGE-001`) |
| **DEF-SEC-002** | **HIGH** | `backend/app/face_engine.py` | Missing challenge frames (left/right/blink) defaulted to `liveness_passed = True`, allowing single static photo bypass. | **RESOLVED** | Require active challenges; default to `False` if challenge frames are omitted. | **PASS** (`TC-SPOOF-001`) |
| **DEF-SEC-003** | **HIGH** | `backend/app/main.py` | No server-side dynamic active liveness challenge tokens (fixed challenge sequence allowed replay). | **RESOLVED** | Added `/api/sessions/{session_id}/liveness-challenge` with HMAC-signed token, 90s TTL, and single-use nonce. | **PASS** (`TC-API-003`, `TC-API-004`) |
| **DEF-SEC-004** | **HIGH** | `backend/app/main.py` | No replay detection for submitted face frames (attacker could resubmit identical image). | **RESOLVED** | Implemented SHA-256 and pHash image digest cache to reject replayed captures. | **PASS** (`TC-SPOOF-002`, `TC-SPOOF-003`) |
| **DEF-SEC-005** | **MEDIUM** | `backend/app/main.py` | Multiple faces in frontal capture were not rejected; largest face was picked silently. | **RESOLVED** | Enforced strict single-face constraint for frontal selfie: reject with HTTP 400 if `len(faces) > 1`. | **PASS** (`TC-FUNC-002`) |
| **DEF-SEC-006** | **MEDIUM** | `backend/app/main.py` | Missing image quality gates for blur, underexposure, overexposure, and face size in live verification. | **RESOLVED** | Added pre-screening checks for Laplacian blur (<35), luminance (<30 or >230), and boundary clipping. | **PASS** (`TC-EDGE-002`, `TC-EDGE-003`) |
| **DEF-SEC-007** | **HIGH** | `backend/app/face_engine.py` | SFace ONNX recognition model was corrupt, falling back to spatial gradient features. | **RESOLVED** | Installed official OpenCV Zoo `face_recognition_sface_2021dec.onnx` (36.9MB) and integrated SFace. | **PASS** (`TC-PERF-001`) |
| **DEF-SEC-008** | **MEDIUM** | `backend/app/face_engine.py` | Eye blink check in `verify_active_liveness` always returned `blink_ok = True` even when eyes remained open. | **RESOLVED** | Enforced true vertical Sobel gradient energy drop between frontal and blink frames. | **PASS** (`TC-FUNC-002`) |
