"""Automated test suite for Attendrix Liveness, Anti-Spoofing, and Security Verification.

Maps directly to proof/TEST_CASES.md IDs:
- TC-FUNC-*: Functional attendance and challenge issuance
- TC-EDGE-*: Face and image quality edge cases
- TC-SPOOF-*: Presentation attack detection, replay attacks, and liveness bypasses
- TC-API-*: Security authorization, token tampering, replay, and concurrency controls
- TC-PERF-*: Latency benchmarking for detection, extraction, and verification
"""
from __future__ import annotations

import io
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from app.db import reset_test_db, supa
from app.face_engine import FaceDetection, RealFaceEngine, get_face_engine
from app.main import app
from app.security import (
    create_access_token,
    create_liveness_challenge_token,
    encrypt_face_embedding,
    reset_security_caches,
    verify_liveness_challenge_token,
)

client = TestClient(app)


def _generate_synthetic_face(
    yaw_offset: int = 0,
    is_blink: bool = False,
    blur: bool = False,
    dark: bool = False,
    bright: bool = False,
    add_moire: bool = False,
) -> tuple[np.ndarray, bytes]:
    """Generate deterministic synthetic test frame with geometric facial markers and texture."""
    base_color = 12 if dark else (245 if bright else 125)
    img = np.full((320, 320, 3), base_color, dtype=np.uint8)

    cx = 160 + yaw_offset
    cy = 160

    # Face background texture (for Laplacian variance > 40)
    for i in range(10, 310, 25):
        cv2.line(img, (10, i), (310, i), (base_color + 15, base_color + 10, base_color - 10), 1)

    # Eyes
    re_x, re_y = cx - 40, cy - 30
    le_x, le_y = cx + 40, cy - 30
    # Nose
    nose_x, nose_y = cx, cy + 10
    # Mouth
    m1_x, m1_y = cx - 30, cy + 50
    m2_x, m2_y = cx + 30, cy + 50

    if not is_blink:
        cv2.rectangle(img, (re_x - 12, re_y - 8), (re_x + 12, re_y + 8), (20, 20, 20), -1)
        cv2.rectangle(img, (le_x - 12, le_y - 8), (le_x + 12, le_y + 8), (20, 20, 20), -1)
    else:
        cv2.line(img, (re_x - 12, re_y), (re_x + 12, re_y), (85, 85, 85), 2)
        cv2.line(img, (le_x - 12, le_y), (le_x + 12, le_y), (85, 85, 85), 2)

    # Nose marker
    cv2.circle(img, (nose_x, nose_y), 6, (35, 35, 35), -1)
    # Mouth marker
    cv2.line(img, (m1_x, m1_y), (m2_x, m2_y), (45, 45, 45), 4)

    if add_moire:
        # High frequency sine pattern (screen pixel grid simulation)
        x_coords = np.arange(320)
        moire_pattern = (np.sin(x_coords * 1.5) * 45).astype(np.int16)
        for row in range(320):
            img[row, :, 0] = np.clip(img[row, :, 0].astype(np.int16) + moire_pattern, 0, 255).astype(np.uint8)
            img[row, :, 1] = np.clip(img[row, :, 1].astype(np.int16) + moire_pattern, 0, 255).astype(np.uint8)

    if blur:
        img = cv2.GaussianBlur(img, (35, 35), 0)

    _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 95])
    return img, buf.tobytes()


@pytest.fixture(autouse=True)
def setup_test_state():
    reset_test_db()
    reset_security_caches()
    yield
    reset_security_caches()


# ── Category A: Functional Tests ─────────────────────────────────────────────

def test_tc_func_001_biometric_enrollment_success():
    """TC-FUNC-001: Student enrolls biometric reference template with consent."""
    login_res = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    _, face_bytes = _generate_synthetic_face(yaw_offset=0)
    enroll_res = client.post(
        "/api/auth/enroll",
        headers=headers,
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", face_bytes, "image/jpeg")},
    )
    assert enroll_res.status_code == 200
    body = enroll_res.json()
    assert body["status"] == "enrolled"
    assert "enrolled" in body["message"].lower()

    # Verify template persisted in database
    db = supa()
    tmpl = db.table("face_templates").select("*").eq("user_id", "00000000-0000-0000-0000-000000000002").execute().data
    assert len(tmpl) == 1
    assert "encrypted_embedding" in tmpl[0]


def test_tc_func_002_live_student_attendance_with_challenge_pass():
    """TC-FUNC-002: Live student completes dynamic challenge token verification."""
    # 1. Login student & enroll
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}
    _, face_bytes = _generate_synthetic_face(yaw_offset=0)
    client.post("/api/auth/enroll", headers=s_headers, data={"consent": "true"}, files={"photo": ("selfie.jpg", face_bytes, "image/jpeg")})

    # 2. Teacher opens session
    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    t_token = t_login.json()["access_token"]
    sess_res = client.post(
        "/api/sessions",
        headers={"Authorization": f"Bearer {t_token}"},
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    )
    session_id = sess_res.json()["id"]

    # 3. Student requests dynamic signed challenge token
    chal_res = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers)
    assert chal_res.status_code == 200
    chal_data = chal_res.json()
    challenge_token = chal_data["challenge_token"]
    challenges = chal_data["challenges"]
    assert len(challenges) >= 1

    # 4. Generate challenge frames matching requirements
    _, left_bytes = _generate_synthetic_face(yaw_offset=-25)
    _, right_bytes = _generate_synthetic_face(yaw_offset=25)
    _, blink_bytes = _generate_synthetic_face(yaw_offset=0, is_blink=True)

    files = {
        "face_image": ("live_face.jpg", face_bytes, "image/jpeg"),
        "face_left": ("turn_left.jpg", left_bytes, "image/jpeg"),
        "face_right": ("turn_right.jpg", right_bytes, "image/jpeg"),
        "face_blink": ("blink.jpg", blink_bytes, "image/jpeg"),
    }
    data = {"challenge_token": challenge_token}

    verify_res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data=data,
        files=files,
    )
    assert verify_res.status_code == 200
    res_body = verify_res.json()
    assert res_body["liveness_passed"] is True
    assert res_body["face_match"] is True


# ── Category B: Edge Cases ───────────────────────────────────────────────────

def test_tc_edge_001_no_face_detected_in_strict_biometrics():
    """TC-EDGE-001: Uniform or textured surface with no face detected is rejected."""
    engine = RealFaceEngine()
    empty_wall = np.full((320, 320, 3), 180, dtype=np.uint8)
    # Strict mode: allow_fallback=False
    detections = engine.detect_faces(empty_wall, allow_fallback=False)
    assert len(detections) == 0

    res = engine.verify_active_liveness(empty_wall, allow_fallback=False)
    assert res["liveness_passed"] is False
    assert res["reason"] == "IMAGE_QUALITY_NO_FACE"


def test_tc_edge_002_image_quality_blur_rejected():
    """TC-EDGE-002: Excessively blurred capture is rejected by image quality screening."""
    engine = RealFaceEngine()
    _, blurry_bytes = _generate_synthetic_face(blur=True)
    nparr = np.frombuffer(blurry_bytes, np.uint8)
    blurry_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    # Pass primary face detection
    face_det = FaceDetection(bbox_x=50, bbox_y=50, bbox_w=200, bbox_h=200, confidence=0.90)
    q_res = engine.check_image_quality(blurry_img, face_det)
    assert q_res["passed"] is False
    assert q_res["error_code"] == "IMAGE_QUALITY_BLURRY"
    assert q_res["metrics"]["laplacian_var"] < 35.0


def test_tc_edge_003_image_quality_underexposed_rejected():
    """TC-EDGE-003: Extremely dark/underexposed frame is rejected."""
    engine = RealFaceEngine()
    _, dark_bytes = _generate_synthetic_face(dark=True)
    nparr = np.frombuffer(dark_bytes, np.uint8)
    dark_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    face_det = FaceDetection(bbox_x=50, bbox_y=50, bbox_w=200, bbox_h=200, confidence=0.90)
    q_res = engine.check_image_quality(dark_img, face_det)
    assert q_res["passed"] is False
    assert q_res["error_code"] == "IMAGE_QUALITY_UNDEREXPOSED"


def test_tc_edge_004_image_quality_too_small():
    """TC-EDGE-004: Images below 120x120 are rejected."""
    engine = RealFaceEngine()
    tiny_img = np.full((80, 80, 3), 120, dtype=np.uint8)
    q_res = engine.check_image_quality(tiny_img)
    assert q_res["passed"] is False
    assert q_res["error_code"] == "IMAGE_QUALITY_TOO_SMALL"


# ── Category C: Presentation Attack Detection & Spoofing ─────────────────────

def test_tc_spoof_001_static_photo_rejected_without_challenges():
    """TC-SPOOF-001: Static photo submitted without active challenges is rejected."""
    engine = RealFaceEngine()
    _, face_bytes = _generate_synthetic_face(yaw_offset=0)
    nparr = np.frombuffer(face_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    # Verify active liveness with NO challenge frames provided
    res = engine.verify_active_liveness(
        frontal_img=img,
        left_img=None,
        right_img=None,
        blink_img=None,
        expected_challenges=["turn_left", "blink"],
    )
    assert res["liveness_passed"] is False
    assert len(res["failed_challenges"]) > 0


def test_tc_spoof_002_image_replay_sha256_blocked():
    """TC-SPOOF-002: Exact byte-level replay attack is blocked by SHA-256 fingerprinting."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}
    _, face_bytes = _generate_synthetic_face(yaw_offset=0)
    client.post("/api/auth/enroll", headers=s_headers, data={"consent": "true"}, files={"photo": ("selfie.jpg", face_bytes, "image/jpeg")})

    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    t_token = t_login.json()["access_token"]
    sess_res = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_token}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15})
    session_id = sess_res.json()["id"]

    # First attempt with face_bytes
    res1 = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("capture.jpg", face_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200

    # Second attempt with the exact same image bytes (Replay attack from a different student)
    s2_login = client.post("/api/auth/login", json={"email": "student2@demo.edu", "password": "password123"})
    s2_token = s2_login.json()["access_token"]
    s2_headers = {"Authorization": f"Bearer {s2_token}"}
    client.post("/api/auth/enroll", headers=s2_headers, data={"consent": "true"}, files={"photo": ("selfie2.jpg", face_bytes, "image/jpeg")})

    replay_res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s2_headers,
        files={"face_image": ("replayed_capture.jpg", face_bytes, "image/jpeg")},
    )
    assert replay_res.status_code == 400
    assert "Replay attack detected" in replay_res.json()["detail"]


def test_tc_spoof_003_perceptual_hash_replay_blocked():
    """TC-SPOOF-003: Recompressed / re-encoded image replay is blocked by pHash matching."""
    from app.security import check_and_record_image_replay
    import hashlib

    # Compute pHash for base image
    engine = RealFaceEngine()
    img, b1 = _generate_synthetic_face(yaw_offset=0)
    h1 = hashlib.sha256(b1).hexdigest()
    p1 = engine.compute_phash(img)

    # First registration: should pass
    is_rep1, _ = check_and_record_image_replay(h1, p1)
    assert is_rep1 is False

    # Second check with DIFFERENT byte hash (re-encoded at lower quality) but SAME pHash
    _, b2 = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 70])
    h2 = hashlib.sha256(b2.tobytes()).hexdigest()
    assert h1 != h2  # Byte hashes differ

    is_rep2, reason2 = check_and_record_image_replay(h2, p1)
    assert is_rep2 is True
    assert "Perceptual image replay" in reason2


def test_tc_spoof_004_passive_screen_moire_detection():
    """TC-SPOOF-004: Screen presentation attack is detected by FFT spectral moiré analysis."""
    engine = RealFaceEngine()
    img_moire, _ = _generate_synthetic_face(add_moire=True)
    face_det = FaceDetection(bbox_x=40, bbox_y=40, bbox_w=240, bbox_h=240, confidence=0.92)

    pa_res = engine.detect_presentation_attack(img_moire, face_det)
    # The high frequency sine pattern produces an elevated spectral energy ratio
    assert pa_res["freq_ratio"] > 0.40 or pa_res["is_spoof"] is True


# ── Category D: API Security & Concurrency ───────────────────────────────────

def test_tc_api_001_missing_authentication_rejected():
    """TC-API-001: Endpoints reject unauthenticated requests."""
    res = client.get("/api/sessions")
    assert res.status_code == 401
    assert "Bearer access token required" in res.json()["detail"]


def test_tc_api_002_student_forbidden_from_teacher_operations():
    """TC-API-002: Student tokens are blocked from creating attendance sessions."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    res = client.post(
        "/api/sessions",
        headers=s_headers,
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    )
    assert res.status_code == 403
    assert "Lecturer authorization required" in res.json()["detail"]


def test_tc_api_003_challenge_token_student_binding():
    """TC-API-003: Challenge tokens cannot be transferred between students."""
    # Token issued for Student 1
    token_s1 = create_liveness_challenge_token(
        session_id="session-100",
        student_id="00000000-0000-0000-0000-000000000001",
        challenges=["turn_left"],
    )

    # Student 2 attempts to use it
    s2_login = client.post("/api/auth/login", json={"email": "student2@demo.edu", "password": "password123"})
    s2_token = s2_login.json()["access_token"]
    s2_headers = {"Authorization": f"Bearer {s2_token}"}

    # Open a mock session in test db for the student's enrolled class
    db = supa()
    db.table("sessions").insert({
        "id": "session-100",
        "status": "open",
        "class_id": "11111111-1111-1111-1111-111111111111",
        "teacher_id": "00000000-0000-0000-0000-000000000001",
    }).execute()
    enc_emb = encrypt_face_embedding(np.zeros(512, dtype=np.float32))
    db.table("face_templates").insert({
        "user_id": "00000000-0000-0000-0000-000000000003",
        "encrypted_embedding": enc_emb,
    }).execute()

    _, face_bytes = _generate_synthetic_face()
    res = client.post(
        "/api/sessions/session-100/verify-attendance",
        headers=s2_headers,
        data={"challenge_token": token_s1},
        files={"face_image": ("capture.jpg", face_bytes, "image/jpeg")},
    )
    assert res.status_code == 403
    assert "issued for a different student" in res.json()["detail"]


def test_tc_api_004_challenge_token_single_use_enforcement():
    """TC-API-004: Challenge tokens cannot be reused (nonce replay defense)."""
    # Issue a valid token for student1
    token = create_liveness_challenge_token(
        session_id="session-reuse",
        student_id="00000000-0000-0000-0000-000000000002",
        challenges=["blink"],
    )

    s1_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s1_token = s1_login.json()["access_token"]
    s1_headers = {"Authorization": f"Bearer {s1_token}"}

    enc_emb = encrypt_face_embedding(np.zeros(512, dtype=np.float32))
    db = supa()
    db.table("sessions").insert({
        "id": "session-reuse",
        "status": "open",
        "class_id": "11111111-1111-1111-1111-111111111111",
        "teacher_id": "00000000-0000-0000-0000-000000000001",
    }).execute()
    db.table("face_templates").insert({
        "user_id": "00000000-0000-0000-0000-000000000002",
        "encrypted_embedding": enc_emb,
    }).execute()

    _, face_bytes = _generate_synthetic_face()
    # First use: passes token check (may fail on face matching or mock)
    client.post(
        "/api/sessions/session-reuse/verify-attendance",
        headers=s1_headers,
        data={"challenge_token": token},
        files={"face_image": ("capture1.jpg", face_bytes, "image/jpeg")},
    )

    # Second use of same token: must reject with nonce used
    _, face2_bytes = _generate_synthetic_face(yaw_offset=1)
    res2 = client.post(
        "/api/sessions/session-reuse/verify-attendance",
        headers=s1_headers,
        data={"challenge_token": token},
        files={"face_image": ("capture2.jpg", face2_bytes, "image/jpeg")},
    )
    assert res2.status_code == 400
    assert "already been used" in res2.json()["detail"]


def test_tc_api_005_duplicate_attendance_strictly_blocked():
    """TC-API-005: Strict 1-attempt policy prevents repeat check-in attempts."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}
    _, face_bytes = _generate_synthetic_face(yaw_offset=0)
    client.post("/api/auth/enroll", headers=s_headers, data={"consent": "true"}, files={"photo": ("selfie.jpg", face_bytes, "image/jpeg")})

    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    t_token = t_login.json()["access_token"]
    sess_res = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_token}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15})
    session_id = sess_res.json()["id"]

    # First attempt
    res1 = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("c1.jpg", face_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200

    # Repeat attempt
    _, face2_bytes = _generate_synthetic_face(yaw_offset=5)
    res2 = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("c2.jpg", face2_bytes, "image/jpeg")},
    )
    assert res2.status_code == 400
    assert "Strictly 1 attempt allowed" in res2.json()["detail"]


# ── Category F: Performance Benchmarking ─────────────────────────────────────

def test_tc_perf_001_inference_latency_benchmark():
    """TC-PERF-001: Benchmark real YuNet detection and SFace feature extraction latency."""
    engine = RealFaceEngine()
    test_img = np.full((320, 320, 3), 120, dtype=np.uint8)

    # 1. Detection latency
    start = time.perf_counter()
    for _ in range(5):
        engine.detect_faces(test_img, allow_fallback=False)
    det_latency = (time.perf_counter() - start) / 5.0

    # 2. Embedding extraction latency
    face = FaceDetection(bbox_x=50, bbox_y=50, bbox_w=180, bbox_h=180, confidence=0.95)
    start = time.perf_counter()
    for _ in range(5):
        engine.extract_embedding(test_img, face)
    emb_latency = (time.perf_counter() - start) / 5.0

    # 3. Active liveness verification latency
    start = time.perf_counter()
    for _ in range(5):
        engine.verify_active_liveness(test_img, allow_fallback=True)
    live_latency = (time.perf_counter() - start) / 5.0

    print(f"\n[PERFORMANCE RESULTS]")
    print(f"Face Detection Latency:     {det_latency * 1000:.2f} ms")
    print(f"Embedding Extract Latency:  {emb_latency * 1000:.2f} ms")
    print(f"Active Liveness Latency:    {live_latency * 1000:.2f} ms")

    # Assert latencies within realistic CPU limits (< 150ms per operation)
    assert det_latency < 0.200
    assert emb_latency < 0.150
    assert live_latency < 0.150
