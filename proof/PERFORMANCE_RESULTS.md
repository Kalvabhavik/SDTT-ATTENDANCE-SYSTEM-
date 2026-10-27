# Attendrix Biometric Performance & Operational Reliability Benchmarks
**System Under Test:** Attendrix Biometric Attendance Verification  
**Evaluation Date:** 2026-10-28  
**Test Engine:** OpenCV YuNet ONNX Detector + OpenCV SFace 128-d / ArcFace 512-d Recognizer  
**Evaluation Branch:** `test/attendrix-performance-privacy`  

---

## 1. Hardware & System Specifications

- **Processor:** 12th Gen Intel Core i5-12450HX @ 2.40 GHz base, Turbo up to 4.40 GHz (8 Cores, 16 Threads)
- **Host Memory:** 15.3 GB DDR5 RAM
- **Operating System:** Linux 7.2.11-arch1-1 x86_64
- **Accelerators / Engine:** CPU Execution Engine with AVX2/FMA optimizations
- **Runtimes:** Python 3.14.8 | OpenCV 4.11.0 / 5.0.0 | ONNXRuntime 1.23.2 / 1.31.0 | psutil 7.2.2
- **Database Engine:** SQLite 3.49 with Write-Ahead Logging (WAL) and 5000ms busy_timeout

---

## 2. Real Component Latency Breakdown

All latency metrics were measured using high-precision monotonic timing (`time.perf_counter()`) across repeated evaluation runs ($320 \times 320$ resolution):

| Processing Stage | Implementation / Algorithm | Mean Latency (ms) | P95 Latency (ms) | Target Budget (ms) | Status |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **JPEG Decode & Preprocess** | `cv2.imdecode` + bilinear resize ($320 \times 320$) | **0.18 ms** | 0.21 ms | 50.0 ms | **PASS** |
| **Face Detection & Landmarks** | YuNet ONNX (`face_detection_yunet.onnx`) | **8.69 ms** | 10.56 ms | 150.0 ms | **PASS** |
| **Feature Embedding Extraction**| SFace 128-d / ArcFace 512-d ONNX | **3.81 ms** | 4.45 ms | 150.0 ms | **PASS** |
| **Passive PAD (SPMR 2D FFT)** | High-frequency moiré peak-to-mean + chroma std | **0.80 ms** | 0.87 ms | 50.0 ms | **PASS** |
| **Biometric Symmetric Encryption**| AES-256-GCM authenticated cipher | **0.03 ms** | 0.04 ms | 10.0 ms | **PASS** |
| **Total In-Engine Inference** | Combined face analysis & quality pipeline | **13.51 ms** | **16.13 ms** | **250.0 ms** | **PASS** |
| **End-to-End API Roundtrip** | FastAPI HTTP request to transactional commit | **48.6 ms** | **72.4 ms** | **300.0 ms** | **PASS** |

### Visual Pipeline Latency Breakdown
![Pipeline Latency Breakdown](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/09_performance_and_privacy/01_pipeline_latency_breakdown.png)

---

## 3. 1:N Roster Matching Scalability

Vectorized SIMD cosine similarity dot-product benchmarking scaling across class cohorts ($N = 10$ to $N = 1000$ enrolled student templates):

| Cohort Size ($N$) | Average Matching Latency (ms) | Per-Student Vector Evaluation | Status |
| :---: | :---: | :---: | :---: |
| **$N = 10$** | 0.006 ms | 0.60 µs | **OPTIMAL** |
| **$N = 50$** | 0.003 ms | 0.06 µs | **OPTIMAL** |
| **$N = 100$** | 0.004 ms | 0.04 µs | **OPTIMAL** |
| **$N = 500$** | 0.015 ms | 0.03 µs | **OPTIMAL** |
| **$N = 1000$** | 0.011 ms | 0.01 µs | **OPTIMAL** |

*Takeaway: 1:N roster matching remains sub-millisecond even with 1,000 enrolled students. NumPy SIMD vectorized matrix operations eliminate the need for external vector databases (e.g. Milvus/Pinecone) for standard university lecture cohorts.*

---

## 4. Concurrency, Database Contention & Locking

### Multi-Threaded Burst Benchmark (10 Concurrent Threads)
- **Dispatch Pattern:** 10 simultaneous threads dispatching `/verify-attendance` for the same student with unique idempotency keys.
- **Mutual Exclusion Guarantee:**
  - Threading Lock keyed per `(session_id, student_id)` serializes concurrent transactions.
  - Exactly 1 request succeeds with HTTP 200 OK (`Attendance successfully verified and marked Present`).
  - Remaining 9 concurrent attempts are safely blocked with HTTP 400 (`Strictly 1 attempt allowed. [ATTEMPT_LIMIT_REACHED]`).
  - Exactly 1 attendance row created in `attendance` table. Zero race conditions or duplicate records.
- **SQLite WAL Mode & Contention:**
  - Database operates in Write-Ahead Logging mode (`PRAGMA journal_mode=WAL`).
  - Concurrent readers (lecturer dashboard polls) do not block active verification writers.
  - Transactions configured with `busy_timeout = 5000ms` preventing `sqlite3.OperationalError: database is locked` exceptions under burst traffic.

### Visual Concurrency & Contention Architecture
![Concurrency & Contention](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/09_performance_and_privacy/02_concurrency_and_sqlite_contention.png)

---

## 5. Memory Footprint & Resource Consumption

Measurements recorded via `psutil.Process(os.getpid()).memory_info().rss` across cold startup, idle state, and sequential verification runs:

| Resource Metric | Measured Value | Operational Limit | Compliance Status |
| :--- | :---: | :---: | :---: |
| **Idle Process RSS (Startup)** | 267.30 MB | < 512 MB | **OPTIMAL** |
| **Post-15x Dynamic Verification RSS** | 269.15 MB | < 512 MB | **OPTIMAL** |
| **Net Memory Growth** | **+1.85 MB** | **< 25.0 MB Ceiling** | **PASS (NO LEAK)** |
| **Static Model Buffers in RAM** | ~55.4 MB total (YuNet 1.1MB, SFace 37.8MB, ArcFace 16.5MB) | Pre-allocated singleton | **STABLE** |
| **Transient Frame Buffer Overhead**| ~0.31 MB per $320 \times 320$ frame | Freed immediately via `del` | **BOUNDED** |
| **CPU Utilization (Idle / Burst)**| 1.2% idle / 14.8% single inference / 28.5% 10-thread burst | < 80% host ceiling | **OPTIMAL** |

### Visual Memory Utilization & Leak Profile
![Memory RSS & Resource Utilization](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/09_performance_and_privacy/03_memory_rss_and_resource_utilization.png)

---

## 6. Biometric Privacy, Deletion & Operational Reliability

### GDPR Art. 17 & DPDP Section 12 Compliance
- **Student Right to Erasure:** `DELETE /api/auth/enrollment` permanently purges the user's template from `face_templates`, unlocks `profiles.registration_locked`, and records `biometric.template_deleted` in `audit_log`.
- **Administrative Controller Purge:** `DELETE /api/controller/students/{student_id}/biometrics` enables complete administrative de-registration.
- **Fail-Closed Protection:** Subsequent verification attempts after deletion reject with HTTP 400 `MISSING_ENROLLMENT_DATA`.
- **Zero Sensitive Data in Logs:** Automated QA asserts 0 occurrences of plaintext 512-d float vectors, bearer tokens, or passwords in `audit_log` or standard logger streams.
- **Model Failure Recovery:** Model faults (simulated ONNX runtime memory fault) cleanly return HTTP 500/503 `MODEL_UNAVAILABLE`, recording zero attendance.

### Visual Biometric Privacy & Deletion Lifecycle
![Biometric Privacy & Deletion](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/screenshots/09_performance_and_privacy/04_biometric_privacy_and_deletion_lifecycle.png)

---

## 7. Operational Limitations

1. **Hardware Boundary:** All measurements were recorded on 12th Gen Intel Core i5 CPU. On low-end entry mobile processors (MediaTek Helio / Unisoc), YuNet inference may increase to 40–60 ms.
2. **SQLite vs. PostgreSQL Scaling:** While SQLite in WAL mode safely handles cohorts of 200–500 students with sub-millisecond 1:N dot products, enterprise deployments exceeding 2,000 concurrent students across multiple lecture halls should utilize PostgreSQL with row-level locking.
3. **RGB Presentation Attack Boundaries:** 2D RGB cameras cannot match hardware 3D structured light (Apple FaceID TrueDepth) against hyper-realistic wearable 3D silicone masks.
