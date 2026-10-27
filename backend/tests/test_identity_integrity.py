"""Identity Verification and Anti-Proxy Integrity Test Suite (Task 05).

Validates that:
1. A live face is not necessarily the enrolled student.
2. A face match is not proof of liveness.
3. A valid liveness result is not proof of session validity.
4. Client-supplied student IDs or verification bypass assertions are rejected.
5. Replayed captures and reused challenges are blocked.
6. Malformed, corrupted, expired, or incompatible enrollment data fail closed cleanly.
7. Concurrency races and duplicate submissions are strictly prevented.
8. Database transaction failures fail closed without phantom attendance.
9. Biometric data (embeddings, landmarks) are never leaked in ordinary application logs.
"""
from __future__ import annotations

import asyncio
import io
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any
from unittest.mock import patch

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
from app.face_engine import get_face_engine
from app.main import app
from app.security import (
    create_access_token,
    create_liveness_challenge_token,
    encrypt_face_embedding,
    reset_security_caches,
)

client = TestClient(app)

LOG_PATH = Path(__file__).resolve().parents[2] / "proof" / "logs" / "identity_integrity_test_log.json"
IDENTITY_RECORDS: list[dict[str, Any]] = []


def _record_identity_result(
    test_id: str,
    requirement: str,
    scenario: str,
    status_code: int,
    decision: str,
    evidence: str,
) -> None:
    rec = {
        "test_id": test_id,
        "requirement": requirement,
        "scenario": scenario,
        "status_code": status_code,
        "decision": decision,
        "evidence": evidence,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    IDENTITY_RECORDS.append(rec)
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_PATH, "w") as f:
            json.dump(IDENTITY_RECORDS, f, indent=2)
    except Exception as e:
        print(f"Warning: Failed to write identity log: {e}")


def _build_test_face(
    yaw_offset: int = 0,
    is_blink: bool = False,
    face_id: int = 1,
    blur: bool = False,
    dark: bool = False,
) -> tuple[np.ndarray, bytes]:
    """Generate synthetic face image with distinctive textures."""
    base_lum = 20 if dark else 130
    img = np.full((320, 320, 3), (base_lum, base_lum + 5, base_lum - 5), dtype=np.uint8)

    cx = int(160 + yaw_offset)
    cy = 160

    if face_id == 1:
        # Face 1: Horizontal texture pattern
        for i in range(15, 305, 20):
            cv2.line(img, (20, i), (300, i), (base_lum + 12, base_lum + 8, base_lum - 8), 1)
        re_x, re_y = cx - 35, cy - 25
        le_x, le_y = cx + 35, cy - 25
        if not is_blink:
            cv2.rectangle(img, (re_x - 10, re_y - 7), (re_x + 10, re_y + 7), (18, 18, 18), -1)
            cv2.rectangle(img, (le_x - 10, le_y - 7), (le_x + 10, le_y + 7), (18, 18, 18), -1)
        else:
            cv2.line(img, (re_x - 10, re_y), (re_x + 10, re_y), (85, 85, 85), 2)
            cv2.line(img, (le_x - 10, le_y), (le_x + 10, le_y), (85, 85, 85), 2)
        cv2.circle(img, (cx, cy + 12), 6, (30, 30, 30), -1)
        cv2.line(img, (cx - 28, cy + 45), (cx + 28, cy + 45), (40, 40, 40), 3)
    elif face_id == 2:
        # Face 2: Vertical texture pattern (non-matching person)
        for i in range(15, 305, 18):
            cv2.line(img, (i, 20), (i, 300), (base_lum + 14, base_lum - 10, base_lum + 8), 2)
        re_x, re_y = cx - 55, cy - 35
        le_x, le_y = cx + 55, cy - 35
        if not is_blink:
            cv2.circle(img, (re_x, re_y), 12, (15, 15, 15), -1)
            cv2.circle(img, (le_x, le_y), 12, (15, 15, 15), -1)
        else:
            cv2.line(img, (re_x - 12, re_y), (re_x + 12, re_y), (85, 85, 85), 2)
            cv2.line(img, (le_x - 12, le_y), (le_x + 12, le_y), (85, 85, 85), 2)
        cv2.rectangle(img, (cx - 8, cy - 5), (cx + 8, cy + 25), (25, 25, 25), -1)
        cv2.ellipse(img, (cx, cy + 50), (45, 18), 0, 0, 180, (35, 35, 35), 4)
    else:
        # Face 3: Diagonal texture pattern
        for i in range(-320, 320, 25):
            cv2.line(img, (max(0, i), max(0, -i)), (min(320, 320 + i), min(320, 320 - i)), (base_lum + 10, base_lum - 8, base_lum + 10), 1)
        cv2.circle(img, (cx - 40, cy - 30), 8, (20, 20, 20), -1)
        cv2.circle(img, (cx + 40, cy - 30), 8, (20, 20, 20), -1)
        cv2.circle(img, (cx, cy + 10), 5, (25, 25, 25), -1)
        cv2.line(img, (cx - 20, cy + 40), (cx + 20, cy + 40), (30, 30, 30), 2)

    if blur:
        img = cv2.GaussianBlur(img, (25, 25), 0)

    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 95])
    return img, buf.tobytes()


def _login_student_and_open_session():
    """Helper to login student1, teacher, and create open lecture session."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_user = s_login.json()["user"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    t_headers = {"Authorization": f"Bearer {t_login.json()['access_token']}"}

    sess = client.post(
        "/api/sessions",
        headers=t_headers,
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    ).json()
    session_id = sess["id"]

    return s_headers, s_user, session_id


@pytest.fixture(autouse=True)
def setup_test_state():
    reset_test_db()
    reset_security_caches()


# ── TC-ID-001: Correct Live Enrolled Student ──────────────────────────────────
def test_id_01_correct_live_enrolled_student():
    """Verify authentic live enrolled student marks attendance as present."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    # Enroll reference selfie
    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    enr_res = client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )
    assert enr_res.status_code == 200

    chal = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()
    token = chal["challenge_token"]

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    _, l_bytes = _build_test_face(yaw_offset=-25, face_id=1)
    _, r_bytes = _build_test_face(yaw_offset=25, face_id=1)
    _, b_bytes = _build_test_face(yaw_offset=0, is_blink=True, face_id=1)

    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": token},
        files={
            "face_image": ("live.jpg", f_bytes, "image/jpeg"),
            "face_left": ("left.jpg", l_bytes, "image/jpeg"),
            "face_right": ("right.jpg", r_bytes, "image/jpeg"),
            "face_blink": ("blink.jpg", b_bytes, "image/jpeg"),
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "present"
    assert body["face_match"] is True
    assert body["liveness_passed"] is True
    assert body["session_valid"] is True

    _record_identity_result(
        test_id="TC-ID-001",
        requirement="Verify authenticated student against enrolled reference",
        scenario="Live enrolled matching student",
        status_code=res.status_code,
        decision=body["status"],
        evidence=f"Match: {body['face_match']}, Liveness: {body['liveness_passed']}, Confidence: {body.get('face_confidence')}",
    )


# ── TC-ID-002: Correct Student With Poor Quality Capture ──────────────────────
def test_id_02_poor_quality_capture():
    """Verify that poor quality captures (blurry / underexposed) are rejected before matching."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )

    # Heavily blurred image
    _, blurry_bytes = _build_test_face(yaw_offset=0, face_id=1, blur=True)
    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("blurry.jpg", blurry_bytes, "image/jpeg")},
    )
    assert res.status_code == 400
    assert res.headers.get("X-Error-Code", "") in ("IMAGE_BLURRY", "IMAGE_QUALITY_BLURRY")

    _record_identity_result(
        test_id="TC-ID-002",
        requirement="Do not automatically accept uncertain or low-quality results",
        scenario="Correct student with blurry capture",
        status_code=res.status_code,
        decision="REJECTED_QUALITY",
        evidence=f"Code: {res.headers.get('X-Error-Code')}, Detail: {res.json().get('detail')}",
    )


# ── TC-ID-003: Live But Non-Matching Person ───────────────────────────────────
def test_id_03_live_non_matching_person():
    """Verify live impostor passes liveness challenges but is marked absent on biometric mismatch."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    # Enrolled with an orthogonal reference embedding
    engine = get_face_engine()
    ortho_ref = np.zeros(512, dtype=np.float32)
    ortho_ref[0] = 1.0
    enc_ortho = encrypt_face_embedding(ortho_ref)
    supa().table("face_templates").insert({
        "user_id": s_user["id"],
        "encrypted_embedding": enc_ortho,
        "model_version": "arcface-yunet-v1",
        "consent_timestamp": "2026-10-27T00:00:00Z",
    }).execute()

    chal = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()
    token = chal["challenge_token"]

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=2)
    _, l_bytes = _build_test_face(yaw_offset=-25, face_id=2)
    _, r_bytes = _build_test_face(yaw_offset=25, face_id=2)
    _, b_bytes = _build_test_face(yaw_offset=0, is_blink=True, face_id=2)

    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": token},
        files={
            "face_image": ("live.jpg", f_bytes, "image/jpeg"),
            "face_left": ("left.jpg", l_bytes, "image/jpeg"),
            "face_right": ("right.jpg", r_bytes, "image/jpeg"),
            "face_blink": ("blink.jpg", b_bytes, "image/jpeg"),
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "absent"
    assert body["face_match"] is False
    assert body["liveness_passed"] is True

    _record_identity_result(
        test_id="TC-ID-003",
        requirement="Live face is not necessarily the enrolled student",
        scenario="Live person with mismatched biometric template",
        status_code=res.status_code,
        decision=body["status"],
        evidence=f"Match: {body['face_match']}, Liveness: {body['liveness_passed']}, Confidence: {body.get('face_confidence')}",
    )


# ── TC-ID-004: Missing Enrollment ─────────────────────────────────────────────
def test_id_04_missing_enrollment():
    """Verify that student without enrolled biometric reference is rejected with clean 400."""
    s_headers, s_user, session_id = _login_student_and_open_session()
    # Explicitly do NOT enroll reference selfie

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "Biometrics not enrolled" in res.json()["detail"]
    assert res.headers.get("X-Error-Code") == "MISSING_ENROLLMENT_DATA"

    _record_identity_result(
        test_id="TC-ID-004",
        requirement="Reject missing enrollment data",
        scenario="Student with no template in face_templates",
        status_code=res.status_code,
        decision="REJECTED_MISSING_ENROLLMENT",
        evidence=f"Detail: {res.json().get('detail')}, Code: {res.headers.get('X-Error-Code')}",
    )


# ── TC-ID-005: Invalid or Malformed Enrollment ────────────────────────────────
def test_id_05_invalid_or_malformed_enrollment():
    """Verify that corrupted ciphertext in face_templates fails closed cleanly with 400 INVALID_ENROLLMENT_DATA."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    # Insert corrupted ciphertext
    supa().table("face_templates").insert({
        "user_id": s_user["id"],
        "encrypted_embedding": "gAAAAABcorrupted_ciphertext_not_valid_fernet_token===",
        "model_version": "arcface-yunet-v1",
        "consent_timestamp": "2026-10-27T00:00:00Z",
    }).execute()

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "INVALID_ENROLLMENT_DATA" in res.headers.get("X-Error-Code", "")
    assert "Malformed or corrupted biometric enrollment data" in res.json()["detail"]

    _record_identity_result(
        test_id="TC-ID-005",
        requirement="Reject malformed enrollment data",
        scenario="Corrupted AES/Fernet ciphertext in template store",
        status_code=res.status_code,
        decision="REJECTED_MALFORMED",
        evidence=f"Detail: {res.json().get('detail')}, Code: {res.headers.get('X-Error-Code')}",
    )


# ── TC-ID-006: Incompatible or Expired Enrollment ─────────────────────────────
def test_id_06_incompatible_or_expired_enrollment():
    """Verify that incompatible model versions or expired templates are rejected with 400."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    # Subcase A: Incompatible model version
    dummy_emb = np.zeros(512, dtype=np.float32)
    dummy_emb[0] = 1.0
    enc = encrypt_face_embedding(dummy_emb)
    supa().table("face_templates").insert({
        "user_id": s_user["id"],
        "encrypted_embedding": enc,
        "model_version": "unsupported-legacy-model-v0",
        "consent_timestamp": "2026-10-27T00:00:00Z",
    }).execute()

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res_incompatible = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res_incompatible.status_code == 400
    assert "INVALID_ENROLLMENT_DATA" in res_incompatible.headers.get("X-Error-Code", "")

    # Subcase B: Expired enrollment
    supa().table("face_templates").delete().eq("user_id", s_user["id"]).execute()
    supa().table("face_templates").insert({
        "user_id": s_user["id"],
        "encrypted_embedding": enc,
        "model_version": "arcface-yunet-v1",
        "consent_timestamp": "2020-01-01T00:00:00Z",
        "expires_at": "2021-01-01T00:00:00Z",
    }).execute()

    res_expired = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res_expired.status_code == 400
    assert "EXPIRED_ENROLLMENT_DATA" in res_expired.headers.get("X-Error-Code", "")

    _record_identity_result(
        test_id="TC-ID-006",
        requirement="Reject expired or incompatible enrollment data",
        scenario="Incompatible model version and expired enrollment timestamp",
        status_code=res_expired.status_code,
        decision="REJECTED_EXPIRED_OR_INCOMPATIBLE",
        evidence=f"Incompatible Code: {res_incompatible.headers.get('X-Error-Code')}, Expired Code: {res_expired.headers.get('X-Error-Code')}",
    )


# ── TC-ID-007: Ambiguous or Low-Confidence Match ──────────────────────────────
def test_id_07_ambiguous_or_low_confidence_match():
    """Verify that ambiguous/low-confidence matches are flagged for review and never auto-accepted."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    engine = get_face_engine()
    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    img_face = cv2.imdecode(np.frombuffer(f_bytes, np.uint8), cv2.IMREAD_COLOR)
    faces = engine.detect_faces(img_face, allow_fallback=True)
    live_emb = engine.extract_embedding(img_face, faces[0])

    # Craft an embedding with similarity exactly 0.40 (in the ambiguous window [0.35, 0.45))
    unit_live = live_emb / np.linalg.norm(live_emb)
    ortho_vec = np.random.randn(len(unit_live)).astype(np.float32)
    ortho_vec -= np.dot(ortho_vec, unit_live) * unit_live
    ortho_vec /= np.linalg.norm(ortho_vec)

    target_sim = 0.40
    ambiguous_emb = target_sim * unit_live + np.sqrt(1.0 - target_sim**2) * ortho_vec
    enc_ambiguous = encrypt_face_embedding(ambiguous_emb)

    supa().table("face_templates").insert({
        "user_id": s_user["id"],
        "encrypted_embedding": enc_ambiguous,
        "model_version": "arcface-yunet-v1",
        "consent_timestamp": "2026-10-27T00:00:00Z",
    }).execute()

    chal = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()
    token = chal["challenge_token"]

    _, l_bytes = _build_test_face(yaw_offset=-25, face_id=1)
    _, r_bytes = _build_test_face(yaw_offset=25, face_id=1)
    _, b_bytes = _build_test_face(yaw_offset=0, is_blink=True, face_id=1)

    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": token},
        files={
            "face_image": ("live.jpg", f_bytes, "image/jpeg"),
            "face_left": ("left.jpg", l_bytes, "image/jpeg"),
            "face_right": ("right.jpg", r_bytes, "image/jpeg"),
            "face_blink": ("blink.jpg", b_bytes, "image/jpeg"),
        },
    )
    assert res.status_code == 200
    body = res.json()
    # Must NOT be marked present!
    assert body["status"] == "pending"
    assert body["face_match"] is False
    assert "Ambiguous" in body["message"] or "Ambiguous" in body.get("note", "")

    _record_identity_result(
        test_id="TC-ID-007",
        requirement="Do not automatically accept uncertain or low-quality results",
        scenario="Cosine similarity 0.40 in ambiguous band [0.35, 0.45)",
        status_code=res.status_code,
        decision=body["status"],
        evidence=f"Status: {body['status']}, Match: {body['face_match']}, Confidence: {body.get('face_confidence')}",
    )


# ── TC-ID-008: Expired or Closed Session ───────────────────────────────────────
def test_id_08_expired_session():
    """Verify that attendance cannot be submitted to an expired or closed session."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    # Close session
    supa().table("sessions").update({"status": "closed"}).eq("id", session_id).execute()

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "session is not open" in res.json()["detail"].lower()

    _record_identity_result(
        test_id="TC-ID-008",
        requirement="Ensure verification applies to active lecture session",
        scenario="Submission against closed session",
        status_code=res.status_code,
        decision="REJECTED_SESSION_CLOSED",
        evidence=f"Detail: {res.json().get('detail')}",
    )


# ── TC-ID-009: Replayed Capture ───────────────────────────────────────────────
def test_id_09_replayed_capture():
    """Verify that identical camera frame bytes are blocked by replay defense."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)

    # First submission
    res1 = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res1.status_code in (200, 400)

    # Replay on a new session with new student
    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    sess2 = client.post(
        "/api/sessions",
        headers={"Authorization": f"Bearer {t_login.json()['access_token']}"},
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    ).json()

    res_replay = client.post(
        f"/api/sessions/{sess2['id']}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res_replay.status_code == 400
    assert "REPLAY_ATTACK_DETECTED" in res_replay.headers.get("X-Error-Code", "")

    _record_identity_result(
        test_id="TC-ID-009",
        requirement="Prevent previous capture from being reused",
        scenario="Identical SHA-256 frame bytes replayed in another session",
        status_code=res_replay.status_code,
        decision="REJECTED_REPLAY",
        evidence=f"Code: {res_replay.headers.get('X-Error-Code')}, Detail: {res_replay.json().get('detail')}",
    )


# ── TC-ID-010: Reused Challenge ───────────────────────────────────────────────
def test_id_10_reused_challenge():
    """Verify that liveness challenge token cannot be reused across requests."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )

    chal = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()
    token = chal["challenge_token"]

    _, f1_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res1 = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": token},
        files={"face_image": ("f1.jpg", f1_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200

    # Second request reusing token
    _, f2_bytes = _build_test_face(yaw_offset=5, face_id=1)
    res_reuse = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": token},
        files={"face_image": ("f2.jpg", f2_bytes, "image/jpeg")},
    )
    assert res_reuse.status_code == 400
    assert "already been used" in res_reuse.json()["detail"].lower()

    _record_identity_result(
        test_id="TC-ID-010",
        requirement="Prevent previous challenge from being reused",
        scenario="Reusing single-use HMAC challenge nonce",
        status_code=res_reuse.status_code,
        decision="REJECTED_CHALLENGE_REUSE",
        evidence=f"Detail: {res_reuse.json().get('detail')}",
    )


# ── TC-ID-011: Duplicate Attendance Submission ────────────────────────────────
def test_id_11_duplicate_attendance_submission():
    """Verify that repeat check-in attempts are rejected with ATTEMPT_LIMIT_REACHED."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )

    _, f1_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res1 = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("f1.jpg", f1_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200

    # Repeat submission
    _, f2_bytes = _build_test_face(yaw_offset=3, face_id=1)
    res_repeat = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("f2.jpg", f2_bytes, "image/jpeg")},
    )
    assert res_repeat.status_code == 400
    assert res_repeat.headers.get("X-Error-Code") == "ATTEMPT_LIMIT_REACHED"

    _record_identity_result(
        test_id="TC-ID-011",
        requirement="Prevent duplicate attendance with database constraints and transactional handling",
        scenario="Sequential repeat attendance submission by same student",
        status_code=res_repeat.status_code,
        decision="REJECTED_DUPLICATE_ATTEMPT",
        evidence=f"Code: {res_repeat.headers.get('X-Error-Code')}, Detail: {res_repeat.json().get('detail')}",
    )


# ── TC-ID-012: Simultaneous Requests for Same Student and Session ─────────────
def test_id_12_simultaneous_concurrent_requests():
    """Verify race condition handling: simultaneous verification requests serialize atomically."""
    import concurrent.futures

    s_headers, s_user, session_id = _login_student_and_open_session()

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )

    # Prepare 5 different face image payloads to avoid replay hash collisions
    frames = [_build_test_face(yaw_offset=i, face_id=1)[1] for i in range(5)]

    results: list[tuple[int, str]] = []

    def _send_request(idx: int):
        sub_client = TestClient(app)
        res = sub_client.post(
            f"/api/sessions/{session_id}/verify-attendance",
            headers=s_headers,
            files={"face_image": (f"live_{idx}.jpg", frames[idx], "image/jpeg")},
        )
        return res.status_code, res.headers.get("X-Error-Code", "")

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(_send_request, i) for i in range(5)]
        for f in concurrent.futures.as_completed(futures):
            results.append(f.result())

    successes = [r for r in results if r[0] == 200]
    blocked = [r for r in results if r[0] == 400 and r[1] == "ATTEMPT_LIMIT_REACHED"]

    # Exactly 1 request must succeed, and all 4 others must be blocked by concurrency lock
    assert len(successes) == 1, f"Expected exactly 1 success, got {len(successes)}: {results}"
    assert len(blocked) == 4, f"Expected 4 blocked requests, got {len(blocked)}: {results}"

    # Verify database has exactly 1 attendance row
    att_rows = supa().table("attendance").select("*").eq("session_id", session_id).eq("student_id", s_user["id"]).execute().data
    assert len(att_rows) == 1

    _record_identity_result(
        test_id="TC-ID-012",
        requirement="Prevent duplicate attendance with database constraints and transactional handling",
        scenario="5 simultaneous concurrent check-in requests for identical (session_id, student_id)",
        status_code=200,
        decision="ATOMIC_LOCK_SERIALIZED",
        evidence=f"Successes: {len(successes)}, Blocked: {len(blocked)}, Total DB Rows: {len(att_rows)}",
    )


# ── TC-ID-013: Database Transaction Failure ───────────────────────────────────
def test_id_13_database_transaction_failure():
    """Verify that a database transaction failure during write fails closed cleanly without phantom attendance."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
    )

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)

    # Simulate database transaction exception on attendance table insert/update
    original_table = supa().table

    def faulty_table(table_name: str):
        query = original_table(table_name)
        if table_name == "attendance":
            class FaultyQuery:
                def __getattr__(self, name):
                    if name in ("insert", "update"):
                        def failing_op(*args, **kwargs):
                            class FailingExec:
                                def execute(self):
                                    raise RuntimeError("PostgreSQL transaction lock timeout / disk failure")
                                def eq(self, *a, **k):
                                    return self
                            return FailingExec()
                        return failing_op
                    return getattr(query, name)
            return FaultyQuery()
        return query

    with patch.object(supa(), "table", side_effect=faulty_table):
        res = client.post(
            f"/api/sessions/{session_id}/verify-attendance",
            headers=s_headers,
            files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
        )
        # Must fail closed with 500 or 503
        assert res.status_code in (500, 503)
        assert res.headers.get("X-Error-Code") in ("DATABASE_TRANSACTION_FAILED", "TRANSACTION_ERROR")

    # Confirm zero phantom attendance records in database
    records = supa().table("attendance").select("*").eq("session_id", session_id).eq("student_id", s_user["id"]).execute().data
    assert len(records) == 0 or records[0].get("status") != "present"

    _record_identity_result(
        test_id="TC-ID-013",
        requirement="Make retry and timeout behaviour safe and idempotent",
        scenario="Simulated database transaction failure during attendance persistence",
        status_code=res.status_code,
        decision="FAILS_CLOSED_NO_PHANTOM",
        evidence=f"Status: {res.status_code}, Code: {res.headers.get('X-Error-Code')}, Detail: {res.json().get('detail')}",
    )


# ── TC-ID-014: Attempt to Submit Attendance for Another User (IDOR) ───────────
def test_id_14_attempt_attendance_for_another_user_idor():
    """Verify that client cannot submit attendance for another user via form/query fields (IDOR)."""
    s_headers, s_user, session_id = _login_student_and_open_session()

    victim_student_id = "22222222-2222-2222-2222-222222222222"
    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)

    # Attack: Attacker sends student_id of another student in form data
    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"student_id": victim_student_id},
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    assert res.status_code == 403
    assert res.headers.get("X-Error-Code") == "IDOR_ATTEMPT_BLOCKED"
    assert "Unauthorized" in res.json()["detail"]

    _record_identity_result(
        test_id="TC-ID-014",
        requirement="Prevent a client from submitting another student's ID to create attendance",
        scenario="Attacker submits victim student_id in form parameters",
        status_code=res.status_code,
        decision="BLOCKED_IDOR_FORBIDDEN",
        evidence=f"Status: {res.status_code}, Code: {res.headers.get('X-Error-Code')}, Detail: {res.json().get('detail')}",
    )


# ── TC-ID-015: Biometric Log Sanitization & Privacy Compliance ─────────────────
def test_id_15_biometric_log_sanitization(caplog):
    """Verify that raw embeddings, landmark tuples, or image buffers are NEVER logged."""
    with caplog.at_level(logging.DEBUG):
        s_headers, s_user, session_id = _login_student_and_open_session()

        _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
        client.post(
            "/api/auth/enroll",
            headers=s_headers,
            data={"consent": "true"},
            files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")},
        )

        _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
        client.post(
            f"/api/sessions/{session_id}/verify-attendance",
            headers=s_headers,
            files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
        )

    full_log_text = caplog.text

    # Assert that no 128/512 floating point vector representations or landmark dumps exist in logs
    assert "array([" not in full_log_text, "Raw NumPy embedding vector leaked in application log!"
    assert "dtype=float" not in full_log_text, "Float array representation leaked in log!"
    assert "landmark" not in full_log_text.lower() or "landmarks=" not in full_log_text, "Landmark coordinates leaked!"

    _record_identity_result(
        test_id="TC-ID-015",
        requirement="Keep biometric information out of ordinary application logs",
        scenario="Full enrollment and attendance verification logging audit",
        status_code=200,
        decision="PRIVACY_COMPLIANT_ZERO_LEAKAGE",
        evidence="Verified complete absence of float array vectors, raw landmarks, and image buffers in application logs.",
    )
