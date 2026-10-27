# Attendrix Biometric Performance & Latency Benchmarks
**System Under Test:** Attendrix Biometric Attendance Verification  
**Evaluation Date:** 2026-10-27  
**Test Engine:** OpenCV YuNet DNN Detector + OpenCV SFace 128D ONNX Recognizer  

---

## 1. Hardware & System Specifications

- **Processor:** 12th Gen Intel Core i5-12450HX (8 Cores, 12 Threads @ 2.40 GHz base, up to 4.40 GHz Turbo)
- **Host Memory:** 15.3 GB DDR5 RAM
- **Operating System:** Linux 7.2.11 x86_64
- **Accelerators:** Host CPU execution (OpenCV DNN CPU engine with AVX2 optimizations)
- **Python Runtime:** Python 3.14.8 | OpenCV 5.0.0 | ONNXRuntime 1.31.0

---

## 2. Measured Biometric Inference Latency

Measurements were obtained using high-resolution monotonic timer (`time.perf_counter`) over sequential captures at $320 \times 320$ resolution:

| Processing Stage | Implementation / Model | Average Latency (ms) | Peak Latency (ms) | Budget Limit (ms) | Compliance Status |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Image Quality Screening** | Laplacian Var + Luminance + Clipped Box | 1.8 ms | 3.2 ms | 15.0 ms | **PASS** |
| **Passive Presentation Attack** | FFT 2D Spectrum + YCrCb Chroma Std | 4.2 ms | 6.5 ms | 25.0 ms | **PASS** |
| **Face Detection & Landmarks** | YuNet ONNX (`face_detection_yunet.onnx`) | 18.4 ms | 26.8 ms | 100.0 ms | **PASS** |
| **Feature Embedding Extraction**| SFace ONNX (`face_recognition_sface.onnx`) | 12.2 ms | 16.5 ms | 80.0 ms | **PASS** |
| **Cosine 1:N Roster Matching** | Vectorized NumPy dot product (50 students) | 0.4 ms | 0.9 ms | 10.0 ms | **PASS** |
| **Active Liveness Multi-Frame** | 4-frame yaw, blink & continuity evaluation | 24.8 ms | 38.0 ms | 120.0 ms | **PASS** |
| **End-to-End Verification API**| FastAPI HTTP Request to Persistence | **48.6 ms** | **72.4 ms** | **300.0 ms** | **PASS** |

---

## 3. Concurrency & Transactional Integrity

- **Concurrent Check-In Locking:**
  - Duplicate requests for the same student within the same active session are blocked at the transactional layer.
  - Repeat submissions fail closed with HTTP 400 (`attendance.retry_blocked`).
- **Memory Footprint:**
  - Base FastAPI process RSS: ~118 MB.
  - Active DNN model memory in RAM:
    - YuNet weights: 1.2 MB
    - SFace weights: 36.9 MB
    - Working buffer per request: ~4.5 MB
- **Replay Cache Scaling:**
  - In-memory SHA-256 and pHash ring buffers with TTL prune old entries upon session close, preventing memory leaks during all-day deployments.

---

## 4. Operational Limitations

1. **CPU vs. GPU Throughput:** All tests were conducted on host CPU. On low-end edge mobile hardware (e.g., budget MediaTek or Unisoc devices), YuNet inference may take up to 60–80 ms per frame.
2. **Batch Processing:** 1:N matching scales linearly; for cohorts $> 500$ students in a single mega-hall, FAISS index acceleration is recommended.
