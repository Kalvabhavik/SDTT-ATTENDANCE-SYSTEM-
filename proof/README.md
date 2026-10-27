# Attendrix Verification & Test Evidence Index
**Platform:** Attendrix Computer-Vision Assisted Attendance System  
**Audit & Engineering Lead:** Senior Biometric Security, Full-Stack & QA Lead  
**Audit Date:** 2026-10-27  
**Branch:** `feat/attendrix-audit`  

---

## 1. Directory Structure

The `proof/` directory houses all verifiable evidence, reports, benchmarks, logs, and audit documentation:

```
proof/
├── README.md                      # Entry point and review navigation guide (this file)
├── AUDIT.md                       # Comprehensive system architecture & security audit
├── TEST_CASES.md                  # Detailed test specifications across Categories A–G
├── TEST_RESULTS.md                # Execution results, pass rates, and commands
├── SECURITY_FINDINGS.md           # Security vulnerabilities, CVSS scores, remediation & retests
├── PERFORMANCE_RESULTS.md         # Empirical latency benchmarks and resource utilization
├── ACCURACY_AND_LIMITATIONS.md    # Model accuracy disclosure, PAD boundaries & residual risks
├── environment.txt                # Evaluated host system, packages, hardware & peripherals
├── reports/
│   ├── junit/
│   │   └── results.xml            # Full Pytest JUnit XML test report (36 tests)
│   └── coverage/                  # Coverage logs
├── logs/
│   ├── backend/                   # FastAPI backend execution logs
│   ├── flutter/                   # Flutter test output
│   ├── test_runner/
│   │   ├── test_run.log           # Pytest execution console log
│   │   └── flutter_test.log       # Flutter test console log
│   └── security/                  # Cryptographic and PAD test logs
├── screenshots/                   # Actual UI and test execution screen evidence
│   ├── 01_baseline/
│   ├── 02_successful_attendance/
│   ├── 03_image_quality_failures/
│   ├── 04_liveness_and_spoofing/
│   ├── 05_api_security/
│   ├── 06_mobile_edge_cases/
│   ├── 07_dashboard_and_database/
│   └── 08_final_regression/
└── defects/
    └── defect_register.md         # Tracked defects (DEF-SEC-001 through DEF-SEC-008)
```

---

## 2. Quick Reproduction Instructions

### Run the Full Backend Regression & Security Test Suite
```bash
# Activate Python 3.14 virtual environment
source backend/.venv/bin/activate

# Execute all 36 automated unit, security, and integration tests
backend/.venv/bin/pytest backend/tests/ -v --junitxml=proof/reports/junit/results.xml
```

### Run Dedicated Anti-Spoofing & Liveness Test Suite
```bash
backend/.venv/bin/pytest backend/tests/test_liveness_and_spoofing.py -v
```

### Run Mobile Application Verification
```bash
# Flutter static code analysis
/home/lucky/development/flutter/bin/flutter analyze lib/

# Flutter widget and unit test execution
/home/lucky/development/flutter/bin/flutter test
```

### Build Web Frontends
```bash
# Dashboard Web Application (Vite + React)
npm --prefix apps/dashboard run build

# Presentation Application (Next.js 16)
npm --prefix presentation/attendrix run build
```

---

## 3. How to Read the Reports

1. **[`AUDIT.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/AUDIT.md):** Detailed architectural audit identifying implemented components vs. mock fallbacks, vulnerabilities, and hardware boundaries.
2. **[`TEST_CASES.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/TEST_CASES.md):** 20 structured test specifications covering functional flows, image edge cases, spoof attacks, API security, and mobile UI with unique IDs (`TC-FUNC-*`, `TC-EDGE-*`, `TC-SPOOF-*`, `TC-API-*`, `TC-MOB-*`, `TC-PERF-*`, `TC-ACC-*`).
3. **[`TEST_RESULTS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/TEST_RESULTS.md):** Summary of all test executions, category breakdown, defect fixes, and links to JUnit reports and console logs.
4. **[`SECURITY_FINDINGS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/SECURITY_FINDINGS.md):** Detailed security findings (`SEC-001` through `SEC-007`) with CVSS ratings, reproduction steps, remediations, and retest evidence.
5. **[`PERFORMANCE_RESULTS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/PERFORMANCE_RESULTS.md):** Empirical latency metrics for YuNet detection (~18.4ms), SFace extraction (~12.2ms), active liveness (~24.8ms), and API response (~48.6ms).
6. **[`ACCURACY_AND_LIMITATIONS.md`](file:///home/lucky/Downloads/mess-manager/SDTT-ATTENDANCE-SYSTEM-/proof/ACCURACY_AND_LIMITATIONS.md):** Transparent disclosure of presentation-attack detection boundaries, monocular RGB sensor constraints, and ethical dataset demographic disclosures.
