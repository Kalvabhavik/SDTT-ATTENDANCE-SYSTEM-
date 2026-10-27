"""FastAPI Backend Security Hardening Test Suite (Task 06).

Comprehensive security audit testing covering:
1. Authentication & Authorization:
   - Missing authentication tokens across protected endpoints (401).
   - Invalid, forged, expired, and revoked JWT credentials (401).
   - Deactivated / suspended user accounts (401).
   - Server-enforced role-based access control (Student vs Teacher vs Controller) (403).
   - Class ownership & cross-teacher authorization (IDOR protection) (403).
   - Cross-student IDOR on attendance verification (403).
   - Session existence, context, and active open status (404/400).
   - Strict disregard of client-supplied IDs, roles, and verification flags.
2. Attendance Integrity:
   - Unique attendance per student/session combination.
   - Idempotent retries with Idempotency-Key headers (200).
   - Strict 1-attempt policy without idempotency key (400).
   - Transactional mutex serialization under concurrent load.
   - Fail-closed on service or model errors without phantom attendance.
3. Input & Infrastructure Security:
   - Schema validation and malformed request bodies (422).
   - Empty, corrupted, and unsupported image uploads (400/415).
   - Payload and request size limits exceeding 15MB / 10MB (413).
   - Sliding-window rate limiting & abuse protection (429).
   - Sanitized exception shield preventing sensitive stack trace leaks (500).
   - Credential and token redaction from audit logs.
"""
from __future__ import annotations

import concurrent.futures
import hashlib
import io
import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone
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

from app.db import reset_test_db, supa, utc_now
from app.face_engine import get_face_engine
from app.main import app
from app.security import (
    check_rate_limit,
    create_access_token,
    create_liveness_challenge_token,
    encrypt_face_embedding,
    is_token_revoked,
    reset_security_caches,
    revoke_token,
)
import jwt as pyjwt

client = TestClient(app)

LOG_PATH = Path(__file__).resolve().parents[2] / "proof" / "logs" / "security" / "api_security_test_log.json"
SECURITY_LOG_RECORDS: list[dict[str, Any]] = []

TEACHER_ID = "00000000-0000-0000-0000-000000000001"
STUDENT_1_ID = "00000000-0000-0000-0000-000000000002"
STUDENT_2_ID = "00000000-0000-0000-0000-000000000003"
CONTROLLER_ID = "00000000-0000-0000-0000-000000000004"
CLASS_1_ID = "11111111-1111-1111-1111-111111111111"
SESSION_1_ID = "ssssssss-0001-0001-0001-000000000001"


def _record_security_result(
    test_id: str,
    category: str,
    scenario: str,
    status_code: int,
    expected_status: int,
    passed: bool,
    details: str,
) -> None:
    entry = {
        "test_id": test_id,
        "category": category,
        "scenario": scenario,
        "status_code": status_code,
        "expected_status": expected_status,
        "passed": passed,
        "details": details,
        "timestamp": utc_now(),
    }
    SECURITY_LOG_RECORDS.append(entry)
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_PATH, "w") as f:
            json.dump(SECURITY_LOG_RECORDS, f, indent=2)
    except Exception:
        pass


def _create_synthetic_face_image(seed: int = 42, width: int = 320, height: int = 320, face_id: int = 1) -> bytes:
    """Generate a clean JPEG image containing a synthetic face with distinctive textures."""
    np.random.seed(seed)
    base_lum = 140
    img = np.full((height, width, 3), (base_lum, base_lum + 5, base_lum - 5), dtype=np.uint8)
    cx, cy = width // 2, height // 2

    if face_id == 1:
        # Face 1: Standard enrolled face with horizontal texture
        for i in range(15, height - 15, 20):
            cv2.line(img, (20, i), (width - 20, i), (base_lum + 12, base_lum + 8, base_lum - 8), 1)
        re_x, re_y = cx - 35, cy - 25
        le_x, le_y = cx + 35, cy - 25
        cv2.rectangle(img, (re_x - 10, re_y - 7), (re_x + 10, re_y + 7), (18, 18, 18), -1)
        cv2.rectangle(img, (le_x - 10, le_y - 7), (le_x + 10, le_y + 7), (18, 18, 18), -1)
        cv2.circle(img, (cx, cy + 12), 6, (30, 30, 30), -1)
        cv2.line(img, (cx - 28, cy + 45), (cx + 28, cy + 45), (40, 40, 40), 3)
    else:
        # Face 2: Attacker / Non-matching person with vertical texture and divergent landmark geometry
        for i in range(15, width - 15, 18):
            cv2.line(img, (i, 20), (i, height - 20), (base_lum + 14, base_lum - 10, base_lum + 8), 2)
        re_x, re_y = cx - 55, cy - 35
        le_x, le_y = cx + 55, cy - 35
        cv2.circle(img, (re_x, re_y), 12, (15, 15, 15), -1)
        cv2.circle(img, (le_x, le_y), 12, (15, 15, 15), -1)
        cv2.rectangle(img, (cx - 8, cy - 5), (cx + 8, cy + 25), (25, 25, 25), -1)
        cv2.ellipse(img, (cx, cy + 50), (45, 18), 0, 0, 180, (35, 35, 35), 4)

    _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 95])
    return buf.tobytes()


@pytest.fixture(autouse=True)
def setup_security_suite():
    reset_test_db()
    reset_security_caches()
    os.environ.pop("ATTENDANCE_TEST_RATE_LIMIT", None)

    # Seed default open session for testing
    db = supa()
    now_iso = utc_now()
    ends_iso = (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat(timespec="seconds")
    db.table("sessions").insert({
        "id": SESSION_1_ID,
        "class_id": CLASS_1_ID,
        "status": "open",
        "created_by": TEACHER_ID,
        "created_at": now_iso,
        "starts_at": now_iso,
        "ends_at": ends_iso,
        "duration_minutes": 15,
    }).execute()

    yield
    reset_security_caches()
    os.environ.pop("ATTENDANCE_TEST_RATE_LIMIT", None)


# ==============================================================================
# CATEGORY 1: AUTHENTICATION & CREDENTIAL SECURITY
# ==============================================================================

def test_sec_01_missing_auth_token_rejected_across_protected_endpoints():
    """Ensure protected endpoints return 401 when Authorization header is absent."""
    protected_endpoints = [
        ("GET", "/api/me"),
        ("GET", "/api/sessions"),
        ("GET", "/api/classes"),
        ("GET", "/api/audit"),
        ("GET", "/api/analytics"),
        ("GET", "/api/notifications"),
        ("POST", "/api/realtime/ticket"),
    ]
    all_passed = True
    for method, path in protected_endpoints:
        if method == "GET":
            res = client.get(path)
        else:
            res = client.post(path)
        assert res.status_code == 401, f"Endpoint {method} {path} should return 401 without auth"
        assert "Bearer access token required" in res.json().get("detail", "")
        if res.status_code != 401:
            all_passed = False

    _record_security_result(
        "SEC-01",
        "Authentication",
        "Reject requests missing Authorization Bearer token across protected routes",
        401,
        401,
        all_passed,
        "All 7 protected endpoints rejected unauthenticated requests with HTTP 401",
    )


def test_sec_02_invalid_and_forged_tokens_rejected():
    """Ensure malformed tokens and tokens signed with forged secrets return 401."""
    # 1. Random garbage string
    res_garbage = client.get("/api/me", headers={"Authorization": "Bearer not-a-valid-jwt-token"})
    assert res_garbage.status_code == 401

    # 2. Forged signature using an attacker secret
    attacker_payload = {
        "sub": STUDENT_1_ID,
        "email": "attacker@evil.com",
        "aud": "authenticated",
        "role": "authenticated",
        "exp": int(time.time()) + 3600,
    }
    forged_token = pyjwt.encode(attacker_payload, "completely_wrong_secret_key_12345678", algorithm="HS256")
    res_forged = client.get("/api/me", headers={"Authorization": f"Bearer {forged_token}"})
    assert res_forged.status_code == 401
    assert "Invalid token" in res_forged.json().get("detail", "")

    _record_security_result(
        "SEC-02",
        "Authentication",
        "Reject malformed and forged HMAC-SHA256 JWT tokens",
        res_forged.status_code,
        401,
        res_forged.status_code == 401,
        "Forged secret and malformed JWT rejected with HTTP 401",
    )


def test_sec_03_expired_credentials_rejected():
    """Ensure expired JWT tokens are rejected with 401 and descriptive expiry message."""
    expired_payload = {
        "sub": STUDENT_1_ID,
        "email": "student1@demo.edu",
        "aud": "authenticated",
        "role": "authenticated",
        "exp": int(time.time()) - 3600,  # Expired 1 hour ago
        "iat": int(time.time()) - 7200,
    }
    expired_token = pyjwt.encode(
        expired_payload,
        os.environ["SUPABASE_JWT_SECRET"],
        algorithm="HS256",
    )
    res = client.get("/api/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert res.status_code == 401
    assert "Token has expired" in res.json().get("detail", "")

    _record_security_result(
        "SEC-03",
        "Authentication",
        "Reject expired JWT credentials",
        res.status_code,
        401,
        res.status_code == 401,
        "Expired token rejected with HTTP 401 Token has expired",
    )


def test_sec_04_revoked_credentials_rejected_after_logout():
    """Ensure that after calling /api/auth/logout, the revoked token can no longer be used."""
    login_res = client.post(
        "/api/auth/login",
        json={"email": "student1@demo.edu", "password": "password123"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Verify token works before logout
    me_before = client.get("/api/me", headers=headers)
    assert me_before.status_code == 200

    # Call logout
    logout_res = client.post("/api/auth/logout", headers=headers)
    assert logout_res.status_code == 200
    assert "credentials revoked" in logout_res.json().get("message", "")

    # Calling /api/me with revoked token must now fail with 401 REVOKED_CREDENTIALS
    me_after = client.get("/api/me", headers=headers)
    assert me_after.status_code == 401
    assert "revoked" in me_after.json().get("detail", "").lower()
    assert me_after.headers.get("X-Error-Code") == "REVOKED_CREDENTIALS"

    _record_security_result(
        "SEC-04",
        "Authentication",
        "Token revocation upon user logout",
        me_after.status_code,
        401,
        me_after.status_code == 401,
        "Revoked token blocked with HTTP 401 REVOKED_CREDENTIALS",
    )


def test_sec_05_deactivated_account_rejected_on_login_and_auth():
    """Ensure deactivated accounts cannot authenticate or access endpoints."""
    db = supa()
    # Deactivate student 1
    db.table("profiles").update({"is_active": False}).eq("email", "student1@demo.edu").execute()

    # 1. Login attempt must fail with 401 ACCOUNT_DEACTIVATED
    login_res = client.post(
        "/api/auth/login",
        json={"email": "student1@demo.edu", "password": "password123"},
    )
    assert login_res.status_code == 401
    assert "ACCOUNT_DEACTIVATED" in login_res.json().get("detail", "")

    # 2. Even with an existing active token, accessing /api/me fails with 401
    active_token = create_access_token(
        user_id=STUDENT_1_ID,
        email="student1@demo.edu",
        role="student",
        name="Ada Lovelace",
    )
    auth_res = client.get("/api/me", headers={"Authorization": f"Bearer {active_token}"})
    assert auth_res.status_code == 401
    assert auth_res.headers.get("X-Error-Code") == "ACCOUNT_DEACTIVATED"

    _record_security_result(
        "SEC-05",
        "Authorization",
        "Block login and access for deactivated accounts",
        auth_res.status_code,
        401,
        auth_res.status_code == 401,
        "Deactivated student blocked on login and route access with HTTP 401 ACCOUNT_DEACTIVATED",
    )


# ==============================================================================
# CATEGORY 2: ROLE-BASED ACCESS CONTROL & PRIVILEGE ESCALATION DEFENSE
# ==============================================================================

def test_sec_06_student_cannot_access_teacher_endpoints():
    """Ensure students cannot create sessions, view review queues, or finalize sessions."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    # 1. Create session attempt
    res_create = client.post(
        "/api/sessions",
        headers=s_headers,
        json={"class_id": CLASS_1_ID, "duration_minutes": 10},
    )
    assert res_create.status_code == 403
    assert "Lecturer authorization required" in res_create.json().get("detail", "")

    # 2. View review queue attempt
    res_queue = client.get(f"/api/sessions/{SESSION_1_ID}/review-queue", headers=s_headers)
    assert res_queue.status_code == 403

    # 3. Finalize session attempt
    res_fin = client.post(
        f"/api/sessions/{SESSION_1_ID}/finalize",
        headers=s_headers,
        json={"mark_pending_absent": True},
    )
    assert res_fin.status_code == 403

    _record_security_result(
        "SEC-06",
        "Authorization",
        "Prevent students from invoking lecturer management endpoints",
        res_create.status_code,
        403,
        res_create.status_code == 403 and res_queue.status_code == 403,
        "Student blocked from session creation, review queue, and finalization with HTTP 403",
    )


def test_sec_07_student_and_teacher_cannot_access_controller_endpoints():
    """Ensure non-controllers cannot access administrative controller management endpoints."""
    # Student check
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    res_stu_ctrl = client.get("/api/controller/classes", headers=s_headers)
    assert res_stu_ctrl.status_code == 403
    assert "Controller authorization required" in res_stu_ctrl.json().get("detail", "")

    res_stu_win = client.post("/api/controller/registration-window", headers=s_headers, json={"is_open": True})
    assert res_stu_win.status_code == 403

    # Teacher check
    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    t_headers = {"Authorization": f"Bearer {t_login.json()['access_token']}"}

    res_tch_ctrl = client.get("/api/controller/classes", headers=t_headers)
    assert res_tch_ctrl.status_code == 403
    assert "Controller authorization required" in res_tch_ctrl.json().get("detail", "")

    _record_security_result(
        "SEC-07",
        "Authorization",
        "Prevent students and teachers from accessing controller endpoints",
        res_tch_ctrl.status_code,
        403,
        res_stu_ctrl.status_code == 403 and res_tch_ctrl.status_code == 403,
        "Student and teacher blocked from academic controller endpoints with HTTP 403",
    )


def test_sec_08_teacher_cannot_access_or_modify_other_teacher_class_or_session():
    """Ensure Teacher B cannot create sessions or review attendance for Teacher A's classes."""
    db = supa()
    # Create Teacher B
    teacher_b_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    db.table("profiles").insert({
        "id": teacher_b_id,
        "name": "Dr. Other Teacher",
        "email": "teacher_b@demo.edu",
        "role": "teacher",
    }).execute()

    token_b = create_access_token(
        user_id=teacher_b_id,
        email="teacher_b@demo.edu",
        role="teacher",
        name="Dr. Other Teacher",
    )
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Class 1 belongs to Teacher A (TEACHER_ID)
    class_a_id = CLASS_1_ID

    # Teacher B attempts to start session for Class A -> must return 403
    res_b_create = client.post(
        "/api/sessions",
        headers=headers_b,
        json={"class_id": class_a_id, "duration_minutes": 10},
    )
    assert res_b_create.status_code == 403
    assert "You do not have access to this class" in res_b_create.json().get("detail", "")

    # Teacher B attempts to view Teacher A's session review queue
    res_b_queue = client.get(
        f"/api/sessions/{SESSION_1_ID}/review-queue",
        headers=headers_b,
    )
    assert res_b_queue.status_code == 403
    assert "You do not have access to this session" in res_b_queue.json().get("detail", "")

    _record_security_result(
        "SEC-08",
        "Authorization / IDOR",
        "Cross-teacher class and session modification blocked",
        res_b_create.status_code,
        403,
        res_b_create.status_code == 403 and res_b_queue.status_code == 403,
        "Teacher B denied access to Teacher A's class and session with HTTP 403",
    )


def test_sec_09_teacher_audit_logs_strictly_scoped_preventing_horizontal_data_leak():
    """Ensure GET /api/audit without session_id returns only audit logs for the calling teacher's sessions."""
    db = supa()
    teacher_b_id = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

    db.table("profiles").insert({
        "id": teacher_b_id,
        "name": "Prof B",
        "email": "prof_b@demo.edu",
        "role": "teacher",
    }).execute()

    class_b_id = "cb000000-0000-0000-0000-000000000001"
    db.table("classes").insert({
        "id": class_b_id,
        "name": "Advanced Physics",
        "code": "PHY-301",
        "teacher_id": teacher_b_id,
    }).execute()

    sess_b_id = "sb000000-0000-0000-0000-000000000001"
    db.table("sessions").insert({
        "id": sess_b_id,
        "class_id": class_b_id,
        "status": "open",
        "created_by": teacher_b_id,
    }).execute()

    # Create audit records for Teacher A and Teacher B
    db.table("audit_log").insert([
        {
            "session_id": SESSION_1_ID,  # Teacher A
            "actor_id": TEACHER_ID,
            "action": "session.created",
            "note": "Teacher A started session",
            "metadata_json": "{}",
            "timestamp": utc_now(),
        },
        {
            "session_id": sess_b_id,  # Teacher B
            "actor_id": teacher_b_id,
            "action": "session.created",
            "note": "Teacher B started physics session",
            "metadata_json": "{}",
            "timestamp": utc_now(),
        },
    ]).execute()

    token_a = create_access_token(TEACHER_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")
    res_a = client.get("/api/audit", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a.status_code == 200
    audits_a = res_a.json()

    # Verify Teacher A ONLY receives audit entries for Teacher A's session
    for record in audits_a:
        assert record.get("session_id") != sess_b_id, "Teacher A leaked Teacher B's audit log entry!"

    # Controller querying /api/audit sees both
    token_ctrl = create_access_token(CONTROLLER_ID, "controller@demo.edu", "controller", "Admin")
    res_ctrl = client.get("/api/audit", headers={"Authorization": f"Bearer {token_ctrl}"})
    assert res_ctrl.status_code == 200
    ctrl_session_ids = {r.get("session_id") for r in res_ctrl.json()}
    assert sess_b_id in ctrl_session_ids, "Controller must have institutional visibility"

    _record_security_result(
        "SEC-09",
        "Authorization / Data Privacy",
        "Audit log scoping to prevent cross-teacher data leakage (IDOR)",
        res_a.status_code,
        200,
        sess_b_id not in {r.get("session_id") for r in audits_a},
        "Teacher A received only owned session audit records; Teacher B data fully isolated",
    )


# ==============================================================================
# CATEGORY 3: ATTENDANCE INTEGRITY, IDOR, & CONCURRENCY
# ==============================================================================

def test_sec_10_student_cannot_submit_attendance_for_another_student_idor():
    """Ensure submitting attendance with another student's ID returns 403 IDOR_ATTEMPT_BLOCKED."""
    s1_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s1_token = s1_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {s1_token}"}

    face_bytes = _create_synthetic_face_image(seed=101)

    res = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
        data={"student_id": STUDENT_2_ID},
    )
    assert res.status_code == 403
    assert res.headers.get("X-Error-Code") == "IDOR_ATTEMPT_BLOCKED"
    assert "Cannot submit attendance for another student" in res.json().get("detail", "")

    _record_security_result(
        "SEC-10",
        "Attendance Integrity / IDOR",
        "Reject check-in submitted on behalf of another student",
        res.status_code,
        403,
        res.status_code == 403,
        "IDOR attempt blocked with HTTP 403 and X-Error-Code: IDOR_ATTEMPT_BLOCKED",
    )


def test_sec_11_student_cannot_verify_attendance_for_unenrolled_class_session():
    """Ensure a student not enrolled in the class cannot submit attendance."""
    db = supa()
    # Create student 3 who is NOT enrolled in Class 1
    student_3_id = "00000000-0000-0000-0000-000000000099"
    db.table("profiles").insert({
        "id": student_3_id,
        "name": "Outsider Student",
        "email": "outsider@demo.edu",
        "role": "student",
        "registration_locked": True,
    }).execute()

    token_3 = create_access_token(student_3_id, "outsider@demo.edu", "student", "Outsider")
    headers = {"Authorization": f"Bearer {token_3}"}

    face_bytes = _create_synthetic_face_image(seed=303)

    res = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res.status_code == 403
    assert "You are not enrolled in this session's class" in res.json().get("detail", "")

    _record_security_result(
        "SEC-11",
        "Attendance Integrity",
        "Reject attendance check-in for unenrolled student",
        res.status_code,
        403,
        res.status_code == 403,
        "Unenrolled student rejected with HTTP 403 You are not enrolled in this session's class",
    )


def test_sec_12_attendance_rejected_on_closed_or_expired_sessions():
    """Ensure attendance verification and challenge generation fail closed on closed sessions."""
    db = supa()
    closed_session_id = "sc000000-0000-0000-0000-000000000001"
    db.table("sessions").insert({
        "id": closed_session_id,
        "class_id": CLASS_1_ID,
        "status": "closed",
        "created_by": TEACHER_ID,
        "starts_at": "2026-10-25T10:00:00Z",
        "ends_at": "2026-10-25T10:15:00Z",
    }).execute()

    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    # 1. Challenge creation on closed session
    res_chal = client.post(f"/api/sessions/{closed_session_id}/liveness-challenge", headers=headers)
    assert res_chal.status_code == 400
    assert "not open" in res_chal.json().get("detail", "").lower()

    # 2. Verify-attendance on closed session
    face_bytes = _create_synthetic_face_image()
    res_att = client.post(
        f"/api/sessions/{closed_session_id}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res_att.status_code == 400
    assert "not open" in res_att.json().get("detail", "").lower()

    _record_security_result(
        "SEC-12",
        "Attendance Integrity",
        "Reject attendance requests on closed or expired sessions",
        res_att.status_code,
        400,
        res_chal.status_code == 400 and res_att.status_code == 400,
        "Challenge and attendance verification rejected on closed session with HTTP 400",
    )


def test_sec_13_client_manipulated_verification_flags_strictly_ignored():
    """Ensure client cannot bypass biometric verification by injecting verification flags."""
    db = supa()

    # Enroll reference for Student 1 with an orthogonal template (guarantees biometric mismatch against any attacker face)
    ortho_ref = np.zeros(512, dtype=np.float32)
    ortho_ref[0] = 1.0
    enc_emb = encrypt_face_embedding(ortho_ref)

    db.table("face_templates").insert({
        "user_id": STUDENT_1_ID,
        "encrypted_embedding": enc_emb,
        "model_version": "arcface-yunet-v1",
        "updated_at": utc_now(),
    }).execute()

    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    # Submit completely different face image (attacker, face_id=2) while asserting bypass flags
    attacker_face = _create_synthetic_face_image(seed=9999, face_id=2)
    res = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", attacker_face, "image/jpeg")},
        data={
            "is_live": True,
            "verified": True,
            "client_verified": True,
            "confidence": 0.999,
            "client_confidence": 0.999,
        },
    )
    assert res.status_code == 200
    data = res.json()
    # Must NOT be marked Present despite client assertion flags
    assert data["status"] in ("absent", "pending"), f"Status must be absent or pending, got {data['status']}"
    assert data["face_match"] is False

    _record_security_result(
        "SEC-13",
        "Attendance Integrity",
        "Strictly disregard client-supplied bypass assertions and verification flags",
        res.status_code,
        200,
        data["status"] != "present" and data["face_match"] is False,
        f"Server disregarded bypass flags; decided status '{data['status']}' from biometric inference",
    )


def test_sec_14_duplicate_requests_and_idempotency_handling():
    """Ensure retries with Idempotency-Key return previous decision idempotently; repeated non-idempotent check-ins are blocked."""
    db = supa()

    # Enroll reference face
    engine = get_face_engine()
    face_bytes = _create_synthetic_face_image(seed=777)
    ref_img = cv2.imdecode(np.frombuffer(face_bytes, np.uint8), cv2.IMREAD_COLOR)
    faces = engine.detect_faces(ref_img, allow_fallback=True)
    ref_emb = engine.extract_embedding(ref_img, faces[0])

    db.table("face_templates").insert({
        "user_id": STUDENT_1_ID,
        "encrypted_embedding": encrypt_face_embedding(ref_emb),
        "model_version": "arcface-yunet-v1",
        "updated_at": utc_now(),
    }).execute()

    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    headers = {
        "Authorization": f"Bearer {s_login.json()['access_token']}",
        "Idempotency-Key": "idemp-req-unique-999",
    }

    # 1. Initial successful verification
    res1 = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200
    assert res1.json()["status"] == "present"

    # 2. Idempotent retry with same Idempotency-Key returns 200 Present idempotently
    res2 = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res2.status_code == 200
    assert res2.json()["status"] == "present"
    assert res2.json().get("idempotent") is True

    # 3. Repeat attempt without idempotency key or different key is rejected with 400 ATTEMPT_LIMIT_REACHED
    headers_diff = {
        "Authorization": f"Bearer {s_login.json()['access_token']}",
        "Idempotency-Key": "different-attempt-key",
    }
    res3 = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=headers_diff,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res3.status_code == 400
    assert res3.headers.get("X-Error-Code") == "ATTEMPT_LIMIT_REACHED"

    _record_security_result(
        "SEC-14",
        "Attendance Integrity",
        "Idempotent retry with Idempotency-Key header; repeat attempts blocked with 400",
        res2.status_code,
        200,
        res2.status_code == 200 and res3.status_code == 400,
        "Idempotent retry returned 200 (idempotent: True); subsequent distinct attempt blocked with 400 ATTEMPT_LIMIT_REACHED",
    )


def test_sec_15_concurrent_attendance_requests_serialized_transactionally():
    """Ensure concurrent requests for the same student/session are serialized without duplicates."""
    db = supa()

    engine = get_face_engine()
    face_bytes = _create_synthetic_face_image(seed=888)
    ref_img = cv2.imdecode(np.frombuffer(face_bytes, np.uint8), cv2.IMREAD_COLOR)
    faces = engine.detect_faces(ref_img, allow_fallback=True)
    ref_emb = engine.extract_embedding(ref_img, faces[0])

    db.table("face_templates").insert({
        "user_id": STUDENT_1_ID,
        "encrypted_embedding": encrypt_face_embedding(ref_emb),
        "model_version": "arcface-yunet-v1",
        "updated_at": utc_now(),
    }).execute()

    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    token = s_login.json()["access_token"]

    def _submit_checkin(worker_id: int):
        c = TestClient(app)
        return c.post(
            f"/api/sessions/{SESSION_1_ID}/verify-attendance",
            headers={"Authorization": f"Bearer {token}"},
            files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
        )

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(_submit_checkin, i) for i in range(5)]
        results = [f.result() for f in futures]

    statuses = [r.status_code for r in results]
    # Exactly one request creates attendance (200), subsequent concurrent requests are rejected (400)
    assert 200 in statuses
    assert all(s in (200, 400) for s in statuses)

    # Verify database state: exactly 1 attendance record exists
    att_recs = db.table("attendance").select("*").eq("session_id", SESSION_1_ID).eq("student_id", STUDENT_1_ID).execute().data
    assert len(att_recs) == 1
    assert att_recs[0]["status"] in ("present", "verified")

    _record_security_result(
        "SEC-15",
        "Concurrency & Transactions",
        "Serialize concurrent check-in attempts via threading mutex lock",
        200,
        200,
        len(att_recs) == 1,
        f"5 concurrent threads executed cleanly; exactly 1 attendance record in database (statuses: {statuses})",
    )


# ==============================================================================
# CATEGORY 4: INPUT VALIDATION, PAYLOAD LIMITS, & ABUSE PROTECTION
# ==============================================================================

def test_sec_16_schema_validation_and_malformed_json_payloads_422():
    """Ensure malformed JSON schemas and out-of-range parameters return HTTP 422."""
    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    t_headers = {"Authorization": f"Bearer {t_login.json()['access_token']}"}

    # 1. Invalid duration_minutes (out of range > 60)
    res_duration = client.post(
        "/api/sessions",
        headers=t_headers,
        json={"class_id": CLASS_1_ID, "duration_minutes": 999},
    )
    assert res_duration.status_code == 422

    # 2. Invalid status in AttendanceUpdate
    res_status = client.patch(
        f"/api/sessions/{SESSION_1_ID}/attendance/{STUDENT_1_ID}",
        headers=t_headers,
        json={"status": "invalid_status_value"},
    )
    assert res_status.status_code == 422

    _record_security_result(
        "SEC-16",
        "Input Validation",
        "Reject schema violations and out-of-range parameters with HTTP 422",
        res_duration.status_code,
        422,
        res_duration.status_code == 422 and res_status.status_code == 422,
        "Pydantic schemas rejected invalid duration (>60m) and invalid status regex with HTTP 422",
    )


def test_sec_17_oversized_payload_and_request_size_limit_413():
    """Ensure requests exceeding maximum size limits return HTTP 413 PAYLOAD_TOO_LARGE."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    # 1. Test Content-Length exceeding 15MB at the ASGI middleware level
    huge_content_length = 20 * 1024 * 1024  # 20MB
    res_middleware = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers={**s_headers, "Content-Length": str(huge_content_length)},
        content=b"test",
    )
    assert res_middleware.status_code == 413
    assert "PAYLOAD_TOO_LARGE" in res_middleware.json().get("error_code", "")

    # 2. Test file upload exceeding 10MB in verify-attendance
    oversized_bytes = b"\xff\xd8\xff" + (b"\x00" * (11 * 1024 * 1024))  # 11MB
    res_upload = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("large.jpg", oversized_bytes, "image/jpeg")},
    )
    assert res_upload.status_code == 413
    assert res_upload.headers.get("X-Error-Code") == "IMAGE_TOO_LARGE"

    _record_security_result(
        "SEC-17",
        "Payload Limits",
        "Reject oversized payloads at middleware and file upload levels with HTTP 413",
        res_middleware.status_code,
        413,
        res_middleware.status_code == 413 and res_upload.status_code == 413,
        "Payload exceeding 15MB rejected at ASGI level; 11MB file upload rejected with HTTP 413 IMAGE_TOO_LARGE",
    )


def test_sec_18_corrupted_and_unsupported_image_uploads_rejected():
    """Ensure zero-byte files and non-image files are rejected with appropriate error codes."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    # 1. Zero-byte empty image
    res_empty = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("empty.jpg", b"", "image/jpeg")},
    )
    assert res_empty.status_code == 400
    assert res_empty.headers.get("X-Error-Code") == "EMPTY_IMAGE"

    # 2. HTML executable disguised as JPEG
    html_bytes = b"<!DOCTYPE html><html><script>alert('xss')</script></html>"
    res_html = client.post(
        f"/api/sessions/{SESSION_1_ID}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("malicious.jpg", html_bytes, "image/jpeg")},
    )
    assert res_html.status_code == 415
    assert res_html.headers.get("X-Error-Code") == "UNSUPPORTED_FORMAT"

    _record_security_result(
        "SEC-18",
        "Input Validation",
        "Reject empty and disguised non-image files",
        res_html.status_code,
        415,
        res_empty.status_code == 400 and res_html.status_code == 415,
        "Empty image rejected with 400 EMPTY_IMAGE; HTML file rejected with 415 UNSUPPORTED_FORMAT",
    )


def test_sec_19_rate_limiting_abuse_defense():
    """Ensure sliding-window rate limiter raises HTTP 429 when threshold is exceeded."""
    os.environ["ATTENDANCE_TEST_RATE_LIMIT"] = "1"
    client_ip = "192.168.1.150"

    # RATE_LIMIT_LOGIN_PER_MIN is 10
    limit_hit = False
    for i in range(12):
        res = client.post(
            "/api/auth/login",
            headers={"X-Forwarded-For": client_ip},
            json={"email": f"nonexistent_{i}@demo.edu", "password": "password123"},
        )
        if res.status_code == 429:
            limit_hit = True
            assert "Rate limit exceeded" in res.json().get("detail", "")
            break

    assert limit_hit is True, "Rate limiter should have triggered 429 after 10 requests"

    _record_security_result(
        "SEC-19",
        "Abuse Protection",
        "Enforce sliding-window rate limiting on sensitive endpoints (HTTP 429)",
        429,
        429,
        limit_hit,
        "Rate limiter successfully triggered HTTP 429 Rate limit exceeded upon exceeding login threshold",
    )


def test_sec_20_global_exception_shield_sanitizes_500_errors():
    """Ensure unhandled server exceptions return sanitized JSON without exposing stack traces."""
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    # TestClient with raise_server_exceptions=False receives the 500 response from FastAPI
    shield_client = TestClient(app, raise_server_exceptions=False)

    with patch("app.main._get_session_or_404", side_effect=KeyError("CRITICAL_INTERNAL_DATABASE_KEY_LEAK")):
        res = shield_client.get(f"/api/sessions/{SESSION_1_ID}", headers=s_headers)

    assert res.status_code == 500
    data = res.json()
    assert data["error_code"] == "INTERNAL_SERVER_ERROR"
    assert "CRITICAL_INTERNAL_DATABASE_KEY_LEAK" not in json.dumps(data)
    assert "Traceback" not in json.dumps(data)
    assert "line " not in json.dumps(data)

    _record_security_result(
        "SEC-20",
        "Information Leakage Defense",
        "Sanitize unhandled server exceptions to prevent stack trace leaks",
        res.status_code,
        500,
        "Traceback" not in json.dumps(data) and data["error_code"] == "INTERNAL_SERVER_ERROR",
        "Unhandled error caught by exception shield; returned generic sanitized 500 JSON without stack trace",
    )


def test_sec_21_audit_log_redaction_prevents_credential_and_biometric_leakage():
    """Ensure tokens, passwords, and raw biometric arrays are stripped from audit log metadata."""
    from app.main import _sanitize_audit_metadata

    dirty_metadata = {
        "user_id": STUDENT_1_ID,
        "password": "super_secret_password_123",
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "raw_token": "secret_bearer_token",
        "jwt": "jwt_token_payload",
        "access_token": "bearer_access_token",
        "secret": "top_secret_salt",
        "embedding": [0.12, 0.45, -0.67] * 100,  # 300 float vector
        "landmarks": [(10, 20), (30, 40)],
        "safe_score": 0.88,
        "safe_note": "Normal audit metadata",
    }

    sanitized = _sanitize_audit_metadata(dirty_metadata)
    assert "password" not in sanitized
    assert "token" not in sanitized
    assert "raw_token" not in sanitized
    assert "jwt" not in sanitized
    assert "access_token" not in sanitized
    assert "secret" not in sanitized
    assert "embedding" not in sanitized
    assert "landmarks" not in sanitized
    assert sanitized["safe_score"] == 0.88
    assert sanitized["safe_note"] == "Normal audit metadata"

    _record_security_result(
        "SEC-21",
        "Information Leakage Defense",
        "Redact credentials, tokens, and biometric vectors from audit logs",
        200,
        200,
        "password" not in sanitized and "token" not in sanitized and "embedding" not in sanitized,
        "Audit sanitizer stripped all passwords, tokens, JWTs, and biometric vectors from metadata",
    )
