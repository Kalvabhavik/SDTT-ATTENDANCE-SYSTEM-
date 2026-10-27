"""Tests for Controller Registry CSV Import, Registration Window management,
and Teacher Session Classroom Reference establishment.
"""
from __future__ import annotations

import io
import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))
os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from fastapi.testclient import TestClient
from app.db import reset_test_db, supa
from app.main import app

client = TestClient(app)


def test_registration_window_controls_student_enrollment():
    reset_test_db()
    # 1. Login as Controller
    c_login = client.post(
        "/api/auth/login",
        json={"email": "controller@demo.edu", "password": "password123"},
    )
    assert c_login.status_code == 200
    c_token = c_login.json()["access_token"]
    c_headers = {"Authorization": f"Bearer {c_token}"}

    # 2. Check initial registration window (should be open)
    w_resp = client.get("/api/controller/registration-window", headers=c_headers)
    assert w_resp.status_code == 200
    assert w_resp.json()["is_open"] is True

    # 3. Close the registration window
    set_resp = client.post(
        "/api/controller/registration-window",
        headers=c_headers,
        json={"is_open": False, "note": "Official enrollment deadline passed"},
    )
    assert set_resp.status_code == 200
    assert set_resp.json()["is_open"] is False

    # 4. Login as student without biometric template
    s_login = client.post(
        "/api/auth/login",
        json={"email": "student1@demo.edu", "password": "password123"},
    )
    assert s_login.status_code == 200
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    # 5. Check enrollment status reports window is closed
    st_resp = client.get("/api/auth/enrollment-status", headers=s_headers)
    assert st_resp.status_code == 200
    assert st_resp.json()["registration_window_open"] is False

    # 6. Attempt enrollment while window is closed -> Must be rejected (403)
    fake_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x10\x00\x00\x00\x10\x08\x06\x00\x00\x00\x1f\xf3\xffa\x00\x00\x00\x00IEND\xaeB`\x82"
    enroll_resp = client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("selfie.png", fake_png, "image/png")},
    )
    assert enroll_resp.status_code == 403
    assert "registration window is currently closed" in enroll_resp.json()["detail"].lower()

    # 7. Controller re-opens the registration window
    open_resp = client.post(
        "/api/controller/registration-window",
        headers=c_headers,
        json={"is_open": True, "note": "Extended registration for late enrollments"},
    )
    assert open_resp.status_code == 200
    assert open_resp.json()["is_open"] is True


def test_controller_registry_csv_import_validation():
    reset_test_db()
    c_login = client.post(
        "/api/auth/login",
        json={"email": "controller@demo.edu", "password": "password123"},
    )
    c_token = c_login.json()["access_token"]
    c_headers = {"Authorization": f"Bearer {c_token}"}

    # 1. Reject invalid CSV without required headers
    bad_csv = "student_code,department\n101,CS\n"
    res_bad = client.post(
        "/api/controller/registry/import",
        headers=c_headers,
        data={"csv_text": bad_csv},
    )
    assert res_bad.status_code == 400
    assert "missing mandatory columns" in res_bad.json()["detail"].lower()

    # 2. Valid CSV with valid and invalid rows
    csv_content = """name,email,roll_number,student_id,class_code
John Von Neumann,neumann@demo.edu,CS-2026-050,STU-9050,CS-101
Claude Shannon,shannon@demo.edu,CS-2026-051,STU-9051,CS-101
,emptyname@demo.edu,CS-2026-052,STU-9052,CS-101
Invalid Email Guy,not-an-email,CS-2026-053,STU-9053,CS-101
"""
    res_import = client.post(
        "/api/controller/registry/import",
        headers=c_headers,
        data={"csv_text": csv_content},
    )
    assert res_import.status_code == 200
    data = res_import.json()
    assert data["imported"] == 2  # John and Claude
    assert data["error_count"] == 2  # empty name and bad email
    assert any("Missing student name" in err for err in data["errors"])
    assert any("Invalid email address" in err for err in data["errors"])

    # 3. Verify students were added to profiles and enrolled in CS-101
    db = supa()
    imported_stu = db.table("profiles").select("*").eq("email", "neumann@demo.edu").execute().data
    assert len(imported_stu) == 1
    assert imported_stu[0]["name"] == "John Von Neumann"
    assert imported_stu[0]["role"] == "student"

    # Check enrollment in CS-101 (id "11111111-1111-1111-1111-111111111111")
    enr = db.table("enrollments").select("*").eq("class_id", "11111111-1111-1111-1111-111111111111").eq("student_id", imported_stu[0]["id"]).execute().data
    assert len(enr) == 1


def test_teacher_establishes_session_reference():
    reset_test_db()
    # 1. Login as Lecturer
    t_login = client.post(
        "/api/auth/login",
        json={"email": "teacher@demo.edu", "password": "password123"},
    )
    t_token = t_login.json()["access_token"]
    t_headers = {"Authorization": f"Bearer {t_token}"}

    # 2. Start a session
    sess_res = client.post(
        "/api/sessions",
        headers=t_headers,
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    )
    assert sess_res.status_code == 200
    session_id = sess_res.json()["id"]

    # 3. Teacher establishes classroom reference for this session
    dummy_b64 = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA="
    ref_res = client.post(
        f"/api/sessions/{session_id}/reference",
        headers=t_headers,
        data={"photo_base64": dummy_b64},
    )
    assert ref_res.status_code == 200
    assert ref_res.json()["status"] == "reference_established"

    # 4. Fetch session and verify room_photo is updated
    get_res = client.get(f"/api/sessions/{session_id}", headers=t_headers)
    assert get_res.status_code == 200
    assert get_res.json()["room_photo"] == dummy_b64


def test_empty_room_proxy_attempt_is_blocked_and_flagged():
    reset_test_db()
    # 1. Login as Student and enroll biometric reference
    s_login = client.post(
        "/api/auth/login",
        json={"email": "student1@demo.edu", "password": "password123"},
    )
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    # Generate synthetic face image
    import cv2
    import numpy as np
    img = np.zeros((200, 200, 3), dtype=np.uint8)
    cv2.circle(img, (100, 100), 50, (255, 255, 255), -1)
    _, face_buf = cv2.imencode(".jpg", img)
    face_bytes = face_buf.tobytes()

    enroll_resp = client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", face_bytes, "image/jpeg")},
    )
    assert enroll_resp.status_code == 200

    # 2. Teacher creates session
    t_login = client.post(
        "/api/auth/login",
        json={"email": "teacher@demo.edu", "password": "password123"},
    )
    t_token = t_login.json()["access_token"]
    sess_res = client.post(
        "/api/sessions",
        headers={"Authorization": f"Bearer {t_token}"},
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    )
    session_id = sess_res.json()["id"]

    # 3. Student scans an EMPTY ROOM (e.g. wall, empty hall, 0 human faces)
    empty_room = np.zeros((300, 500, 3), dtype=np.uint8)
    empty_room[:150] = [180, 190, 200]  # wall
    empty_room[150:] = [80, 90, 100]    # floor
    _, empty_buf = cv2.imencode(".jpg", empty_room)
    empty_bytes = empty_buf.tobytes()

    verify_res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        files={
            "face_image": ("live_face.jpg", face_bytes, "image/jpeg"),
            "classroom_image": ("empty_room.jpg", empty_bytes, "image/jpeg"),
        },
    )
    assert verify_res.status_code == 200
    v_data = verify_res.json()
    # Anti-Proxy Verification: Empty room CANNOT be marked present!
    assert v_data["status"] == "pending"
    assert v_data["is_empty_room"] is True
    assert v_data["sir_detected"] is False
    assert v_data["crowd_detected"] is False
    assert v_data["crowd_count"] == 0
    assert "Empty room detected" in v_data["message"]

    # Verify audit log recorded empty room proxy attempt
    db = supa()
    audits = db.table("audit_log").select("*").eq("session_id", session_id).eq("action", "attendance.empty_room_proxy_detected").execute().data
    assert len(audits) >= 1


def test_verify_student_live_attendance_with_active_classroom():
    reset_test_db()
    # 1. Login as Student and enroll biometric reference
    s_login = client.post(
        "/api/auth/login",
        json={"email": "student1@demo.edu", "password": "password123"},
    )
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    import cv2
    import numpy as np
    img = np.zeros((200, 200, 3), dtype=np.uint8)
    cv2.circle(img, (100, 100), 50, (255, 255, 255), -1)
    _, face_buf = cv2.imencode(".jpg", img)
    face_bytes = face_buf.tobytes()

    enroll_resp = client.post(
        "/api/auth/enroll",
        headers=s_headers,
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", face_bytes, "image/jpeg")},
    )
    assert enroll_resp.status_code == 200

    # 2. Teacher creates session
    t_login = client.post(
        "/api/auth/login",
        json={"email": "teacher@demo.edu", "password": "password123"},
    )
    t_token = t_login.json()["access_token"]
    sess_res = client.post(
        "/api/sessions",
        headers={"Authorization": f"Bearer {t_token}"},
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    )
    session_id = sess_res.json()["id"]

    # 3. Simulate active room with Sir on stage and crowd in audience
    from unittest.mock import patch
    from app.face_engine import FaceDetection, get_face_engine

    engine = get_face_engine()
    orig_detect = engine.detect_faces

    def mock_detect(frame, allow_fallback=False):
        if allow_fallback:
            return orig_detect(frame, allow_fallback=True)
        # For classroom panorama with active lecture:
        return [
            FaceDetection(bbox_x=250, bbox_y=60, bbox_w=60, bbox_h=60, confidence=0.92),   # Stage (Sir)
            FaceDetection(bbox_x=120, bbox_y=220, bbox_w=50, bbox_h=50, confidence=0.88),  # Audience peer
            FaceDetection(bbox_x=340, bbox_y=220, bbox_w=50, bbox_h=50, confidence=0.87),  # Audience peer
        ]

    with patch.object(engine, "detect_faces", side_effect=mock_detect):
        verify_res = client.post(
            f"/api/sessions/{session_id}/verify-attendance",
            headers=s_headers,
            files={
                "face_image": ("live_face.jpg", face_bytes, "image/jpeg"),
                "classroom_image": ("active_classroom.jpg", face_bytes, "image/jpeg"),
            },
        )
    assert verify_res.status_code == 200
    v_data = verify_res.json()
    assert v_data["status"] == "present"
    assert v_data["face_match"] is True
    assert v_data["sir_detected"] is True
    assert v_data["crowd_detected"] is True
    assert v_data["crowd_count"] >= 2
    assert "120-Seater" in v_data["hall_type"] or "Theater" in v_data["hall_type"]

