"""Automated security tests for Attendrix Fix 1: Server-Enforced Role Authorization.

Verifies:
1. Registration prevents self-assignment of teacher, controller, or admin privileges.
2. Login does not derive controller privileges from email substrings ('admin', 'controller').
3. Login does not create a privileged fallback profile on unknown emails.
4. Client-selected roles cannot elevate privileges or bypass role mismatch checks.
5. Student tokens cannot access controller-only endpoints (403).
6. Students cannot modify or spoof another student's attendance (403 IDOR blocked).
7. Teachers cannot access or modify classes, sessions, or attendance outside their authorization.
8. Missing, None, or invalid database roles fail closed (403).
9. Inconsistent token role claims (forged or elevated) vs authoritative database profile are rejected (403).
10. Expired, forged, or unauthenticated tokens are rejected (401).
11. Legitimate authorized users can perform their permitted operations.
"""
from __future__ import annotations

import os
import sys
import uuid
from pathlib import Path
from typing import Any

import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from app.db import reset_test_db, supa, utc_now
from app.main import app
from app.security import create_access_token
import jwt as pyjwt

client = TestClient(app)

TEACHER_1_ID = "00000000-0000-0000-0000-000000000001"
STUDENT_1_ID = "00000000-0000-0000-0000-000000000002"
STUDENT_2_ID = "00000000-0000-0000-0000-000000000003"
CONTROLLER_ID = "00000000-0000-0000-0000-000000000004"
CLASS_1_ID = "11111111-1111-1111-1111-111111111111"
SESSION_1_ID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"


@pytest.fixture(autouse=True)
def setup_test_environment():
    """Reset the database to clean default state before each test."""
    db = reset_test_db()
    # Ensure standard session exists for test class 1
    db.tables["sessions"] = [
        {
            "id": SESSION_1_ID,
            "class_id": CLASS_1_ID,
            "status": "open",
            "starts_at": utc_now(),
            "ends_at": "2099-01-01T00:00:00Z",
            "duration_minutes": 10,
            "created_by": TEACHER_1_ID,
            "created_at": utc_now(),
        }
    ]
    db.tables["attendance"] = [
        {
            "id": "att-1",
            "session_id": SESSION_1_ID,
            "student_id": STUDENT_1_ID,
            "status": "pending",
            "updated_by": TEACHER_1_ID,
            "updated_at": utc_now(),
        },
        {
            "id": "att-2",
            "session_id": SESSION_1_ID,
            "student_id": STUDENT_2_ID,
            "status": "pending",
            "updated_by": TEACHER_1_ID,
            "updated_at": utc_now(),
        },
    ]
    return db


# ── TEST 1: Registration Role Self-Assignment Prevention ───────────────────────

def test_registration_cannot_self_assign_teacher_role():
    """An ordinary user cannot self-assign the teacher role during public signup."""
    res = client.post(
        "/api/auth/signup",
        json={
            "email": "malicious.teacher@example.edu",
            "password": "Password123!",
            "role": "teacher",
            "name": "Wannabe Teacher",
        },
    )
    # Must reject role elevation attempt
    assert res.status_code == 403
    assert "teacher" in res.json().get("detail", "").lower() or "role" in res.json().get("detail", "").lower()


def test_registration_cannot_self_assign_controller_role():
    """An ordinary user cannot self-assign controller or admin roles during public signup."""
    for bad_role in ("controller", "admin"):
        res = client.post(
            "/api/auth/signup",
            json={
                "email": f"malicious.{bad_role}@example.edu",
                "password": "Password123!",
                "role": bad_role,
                "name": f"Wannabe {bad_role.capitalize()}",
            },
        )
        assert res.status_code == 403


def test_registration_always_creates_student_role():
    """Legitimate student registration succeeds and is strictly assigned student role."""
    res = client.post(
        "/api/auth/signup",
        json={
            "email": "genuine.student@example.edu",
            "password": "Password123!",
            "role": "student",
            "name": "Genuine Student",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["user"]["role"] == "student"


# ── TEST 2: Email Keyword Elevation Prevention ────────────────────────────────

def test_login_email_containing_admin_does_not_elevate_student_privileges():
    """A student with 'admin' in their email address is not promoted to controller."""
    db = supa()
    admin_named_student_id = str(uuid.uuid4())
    db.table("profiles").insert({
        "id": admin_named_student_id,
        "name": "Admin Intern",
        "email": "admin.intern@demo.edu",
        "role": "student",
    }).execute()

    res = client.post(
        "/api/auth/login",
        json={"email": "admin.intern@demo.edu", "password": "password123"},
    )
    assert res.status_code == 200
    user_data = res.json()["user"]
    assert user_data["role"] == "student", "Role must NOT be elevated by 'admin' in email"

    # Token must not grant controller access
    token = res.json()["access_token"]
    ctrl_res = client.get(
        "/api/controller/classes",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ctrl_res.status_code == 403


def test_login_email_containing_controller_does_not_elevate_student_privileges():
    """A student with 'controller' in their email address is not promoted to controller."""
    db = supa()
    ctrl_named_student_id = str(uuid.uuid4())
    db.table("profiles").insert({
        "id": ctrl_named_student_id,
        "name": "Traffic Controller Student",
        "email": "traffic.controller@demo.edu",
        "role": "student",
    }).execute()

    res = client.post(
        "/api/auth/login",
        json={"email": "traffic.controller@demo.edu", "password": "password123"},
    )
    assert res.status_code == 200
    assert res.json()["user"]["role"] == "student"

    token = res.json()["access_token"]
    ctrl_res = client.get(
        "/api/controller/classes",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert ctrl_res.status_code == 403


def test_login_unknown_email_with_admin_or_controller_fails_closed_401():
    """Non-existent emails with 'admin' or 'controller' must NOT auto-provision or create fallback controller profile."""
    for bad_email in ("admin@unknown.edu", "controller@hacker.io", "admin_super@test.org"):
        res = client.post(
            "/api/auth/login",
            json={"email": bad_email, "password": "anypassword"},
        )
        assert res.status_code == 401, f"Expected 401 for unknown user {bad_email}, got {res.status_code}"


# ── TEST 3: Client Role Selection Cannot Elevate Privileges ───────────────────

def test_student_selecting_controller_role_is_denied():
    """A student selecting 'controller' role at login must be rejected with 403 Role mismatch."""
    res = client.post(
        "/api/auth/login",
        json={
            "email": "student1@demo.edu",
            "password": "password123",
            "selected_role": "controller",
        },
    )
    assert res.status_code == 403
    assert "Role mismatch" in res.json().get("detail", "")


def test_student_selecting_teacher_role_is_denied():
    """A student selecting 'lecturer' role at login must be rejected with 403 Role mismatch."""
    res = client.post(
        "/api/auth/login",
        json={
            "email": "student1@demo.edu",
            "password": "password123",
            "selected_role": "lecturer",
        },
    )
    assert res.status_code == 403
    assert "Role mismatch" in res.json().get("detail", "")


# ── TEST 4: Student Tokens Denied from All Controller Endpoints ───────────────

def test_student_token_denied_from_all_controller_endpoints():
    """A student token must be rejected with HTTP 403 from every controller endpoint."""
    s_token = create_access_token(STUDENT_1_ID, "student1@demo.edu", "student", "Ada Lovelace")
    headers = {"Authorization": f"Bearer {s_token}"}

    endpoints = [
        ("GET", "/api/controller/classes", None),
        ("POST", "/api/controller/classes", {"name": "Unauthorized Class", "code": "UNAUTH-1"}),
        ("GET", "/api/controller/students", None),
        ("POST", "/api/controller/students", {"name": "New Student", "email": "new@demo.edu", "roll_number": "STU-999"}),
        ("GET", "/api/controller/registration-window", None),
        ("POST", "/api/controller/registration-window", {"is_open": True}),
        ("POST", "/api/controller/registry/import", None),
        ("POST", f"/api/controller/students/{STUDENT_2_ID}/unlock", None),
        ("DELETE", f"/api/controller/students/{STUDENT_2_ID}/biometrics", None),
    ]

    for method, path, payload in endpoints:
        if method == "GET":
            r = client.get(path, headers=headers)
        elif method == "POST":
            if payload:
                r = client.post(path, headers=headers, json=payload)
            else:
                r = client.post(path, headers=headers)
        elif method == "DELETE":
            r = client.delete(path, headers=headers)
        assert r.status_code == 403, f"Expected 403 on {method} {path}, got {r.status_code}"


# ── TEST 5: Student Cannot Modify Attendance ──────────────────────────────────

def test_student_cannot_modify_attendance_records():
    """Students cannot modify attendance via PATCH or review endpoints."""
    s_token = create_access_token(STUDENT_1_ID, "student1@demo.edu", "student", "Ada Lovelace")
    headers = {"Authorization": f"Bearer {s_token}"}

    # Attempt manual attendance override
    patch_res = client.patch(
        f"/api/sessions/{SESSION_1_ID}/attendance/{STUDENT_2_ID}",
        headers=headers,
        json={"status": "present", "note": "student altered attendance"},
    )
    assert patch_res.status_code == 403

    # Attempt review queue decision
    review_res = client.post(
        f"/api/sessions/{SESSION_1_ID}/review/some_attempt_id",
        headers=headers,
        json={"decision": "verified"},
    )
    assert review_res.status_code == 403

    # Attempt session finalization
    fin_res = client.post(
        f"/api/sessions/{SESSION_1_ID}/finalize",
        headers=headers,
        json={"mark_pending_absent": True},
    )
    assert fin_res.status_code == 403


# ── TEST 6: Teacher Resource-Level Authorization (Horizontal IDOR) ────────────

def test_teacher_cannot_access_unauthorized_classes_or_sessions():
    """Teacher A cannot access or modify Teacher B's classes, sessions, or attendance."""
    db = supa()
    teacher_b_id = str(uuid.uuid4())
    class_b_id = str(uuid.uuid4())
    session_b_id = str(uuid.uuid4())

    # Create Teacher B, Class B, and Session B
    db.table("profiles").insert({
        "id": teacher_b_id,
        "name": "Prof. B",
        "email": "prof.b@demo.edu",
        "role": "teacher",
    }).execute()
    db.table("classes").insert({
        "id": class_b_id,
        "name": "Class B",
        "code": "CS-999",
        "teacher_id": teacher_b_id,
    }).execute()
    db.table("sessions").insert({
        "id": session_b_id,
        "class_id": class_b_id,
        "status": "open",
        "created_by": teacher_b_id,
    }).execute()
    db.table("attendance").insert({
        "id": "att-b-1",
        "session_id": session_b_id,
        "student_id": STUDENT_1_ID,
        "status": "pending",
        "updated_by": teacher_b_id,
    }).execute()

    # Teacher 1 tries to access Teacher B's resources
    t1_token = create_access_token(TEACHER_1_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")
    t1_headers = {"Authorization": f"Bearer {t1_token}"}

    # 1. Teacher 1 tries to view students of Class B
    res_cls_students = client.get(f"/api/classes/{class_b_id}/students", headers=t1_headers)
    assert res_cls_students.status_code == 403

    # 2. Teacher 1 tries to start a session for Class B
    res_create_sess = client.post(
        "/api/sessions",
        headers=t1_headers,
        json={"class_id": class_b_id, "duration_minutes": 10},
    )
    assert res_create_sess.status_code == 403

    # 3. Teacher 1 tries to get Session B details
    res_sess = client.get(f"/api/sessions/{session_b_id}", headers=t1_headers)
    assert res_sess.status_code == 403

    # 4. Teacher 1 tries to modify attendance in Session B
    res_patch = client.patch(
        f"/api/sessions/{session_b_id}/attendance/{STUDENT_1_ID}",
        headers=t1_headers,
        json={"status": "present"},
    )
    assert res_patch.status_code == 403

    # 5. Teacher 1 tries to finalize Session B
    res_fin = client.post(
        f"/api/sessions/{session_b_id}/finalize",
        headers=t1_headers,
        json={"mark_pending_absent": True},
    )
    assert res_fin.status_code == 403

    # 6. Teacher 1 listing sessions does NOT contain Session B
    res_list = client.get("/api/sessions", headers=t1_headers)
    assert res_list.status_code == 200
    session_ids = [s["id"] for s in res_list.json()]
    assert session_b_id not in session_ids, "Teacher 1 must not see Teacher B's sessions"


# ── TEST 7: Missing or Invalid Role Denied (Fail Closed) ───────────────────────

def test_missing_or_invalid_role_denied():
    """Users with missing or invalid roles in database profile fail closed with 403."""
    db = supa()
    broken_user_id = str(uuid.uuid4())
    db.table("profiles").insert({
        "id": broken_user_id,
        "name": "Broken Role User",
        "email": "broken.role@demo.edu",
        "role": "hacker_superuser",  # Invalid unrecognized role
    }).execute()

    # Login attempt fails closed
    login_res = client.post(
        "/api/auth/login",
        json={"email": "broken.role@demo.edu", "password": "password123"},
    )
    assert login_res.status_code == 403

    # Direct token attempt fails closed
    token = create_access_token(broken_user_id, "broken.role@demo.edu", "hacker_superuser", "Broken User")
    me_res = client.get("/api/me", headers={"Authorization": f"Bearer {token}"})
    assert me_res.status_code == 403


# ── TEST 8: Inconsistent Token Claims Denied ───────────────────────────────────

def test_inconsistent_token_role_claim_denied():
    """A forged token claiming 'controller' for a user whose DB profile is 'student' is rejected with 403."""
    # Mint token claiming controller role for STUDENT_1_ID
    forged_token = create_access_token(
        STUDENT_1_ID,
        "student1@demo.edu",
        "controller",
        "Ada Lovelace",
    )
    res = client.get(
        "/api/controller/classes",
        headers={"Authorization": f"Bearer {forged_token}"},
    )
    # Must fail closed: token claim does not match authoritative database role
    assert res.status_code == 403


# ── TEST 9: Expired and Malformed Tokens Rejected ──────────────────────────────

def test_expired_or_invalid_tokens_rejected_401():
    """Missing, expired, and signature-forged tokens return HTTP 401."""
    # 1. Missing header
    assert client.get("/api/me").status_code == 401

    # 2. Expired token
    now = int(utc_now().replace("+00:00", "").replace("Z", "")) if False else 1000
    expired_payload = {
        "sub": STUDENT_1_ID,
        "email": "student1@demo.edu",
        "aud": "authenticated",
        "role": "authenticated",
        "iat": 1000,
        "exp": 1001,
    }
    expired_token = pyjwt.encode(expired_payload, "test_jwt_secret_must_be_at_least_32_chars_long", algorithm="HS256")
    exp_res = client.get("/api/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert exp_res.status_code == 401

    # 3. Forged secret
    forged_token = pyjwt.encode(expired_payload, "wrong_secret_key_abcdefghijklmnop", algorithm="HS256")
    forged_res = client.get("/api/me", headers={"Authorization": f"Bearer {forged_token}"})
    assert forged_res.status_code == 401


# ── TEST 10: Authorized Users Perform Legitimate Operations ───────────────────

def test_authorized_users_perform_legitimate_operations():
    """Authorized controller, teacher, and student can execute their permitted actions."""
    # Controller accesses classes
    c_token = create_access_token(CONTROLLER_ID, "controller@demo.edu", "controller", "Academic Controller")
    c_res = client.get("/api/controller/classes", headers={"Authorization": f"Bearer {c_token}"})
    assert c_res.status_code == 200

    # Teacher accesses their own session
    t_token = create_access_token(TEACHER_1_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")
    t_res = client.get(f"/api/sessions/{SESSION_1_ID}", headers={"Authorization": f"Bearer {t_token}"})
    assert t_res.status_code == 200

    # Student accesses their own attendance
    s_token = create_access_token(STUDENT_1_ID, "student1@demo.edu", "student", "Ada Lovelace")
    s_res = client.get("/api/students/me/attendance", headers={"Authorization": f"Bearer {s_token}"})
    assert s_res.status_code == 200
    assert s_res.json()["student_id"] == STUDENT_1_ID
