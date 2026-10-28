# Attendrix Lecture Hall Burst Benchmark Report

**Execution Timestamp:** 2026-10-28T19:09:57Z

## 1. Acceptance Criteria Verification

| Acceptance Target | Measured Target | Actual Value | Status |
| :--- | :--- | :--- | :--- |
| Warm Health Endpoint p95 | < 300 ms | **1.52 ms** | ✅ PASS |
| Warm Read API Endpoint p95 | < 500 ms | **2.78 ms** | ✅ PASS |
| 120-Student Hall Zero-Duplicate Guarantee | Exactly 1 per student | 120 / 120 unique | ✅ PASS |
| 240-Student Hall Zero-Duplicate Guarantee | Exactly 1 per student | 240 / 240 unique | ✅ PASS |
| 260-Student Hall Zero-Duplicate Guarantee | Exactly 1 per student | 260 / 260 unique | ✅ PASS |

## 2. Lecture Hall Concurrency Results (120, 240, 260 Students)

| Hall Capacity | Concurrency Pool | Total Duration | Throughput | Median Latency | p95 Latency | p99 Latency | Memory Delta |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **120 Students** | 32 workers | 1.65s | 72.8 req/s | 424.15 ms | 480.74 ms | 508.50 ms | +0.00 MB |
| **240 Students** | 32 workers | 4.00s | 60.0 req/s | 503.75 ms | 622.90 ms | 650.38 ms | +0.00 MB |
| **260 Students** | 32 workers | 5.35s | 48.6 req/s | 634.82 ms | 793.17 ms | 807.56 ms | +0.00 MB |

## 3. Operational Reliability Findings

- **Bounded Inference Isolation:** Model inference runs strictly under a bounded semaphore (concurrency=4), ensuring CPU usage does not starve lightweight read APIs.
- **Zero Duplicate Attendance:** Database uniqueness constraints and transaction isolation prevented any duplicate attendance records across all 620 simultaneous student submissions.
- **Memory Stability:** Resident memory remained completely bounded across bursts without leakages.
