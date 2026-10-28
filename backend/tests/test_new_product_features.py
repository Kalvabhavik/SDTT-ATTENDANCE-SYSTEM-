import io
import os
import sys
from pathlib import Path
import pytest
from fastapi.testclient import TestClient
import numpy as np
import cv2

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from app.main import app, supa
from app.db import reset_test_db
from app.face_engine import FakeFaceEngine, set_face_engine

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db():
    reset_test_db()
    engine = FakeFaceEngine()
    set_face_engine(engine)
    yield
    set_face_engine(None)


def _login(email: str, password: str = "pass123", role: str = None) -> str:
    body = {"email": email, "password": password}
    if role:
        body["selected_role"] = role
    res = client.post("/api/auth/login", json=body)
    assert res.status_code == 200, f"Login failed for {email}: {res.text}"
    return res.json()["access_token"]


def test_account_recovery_and_password_reset():
    # 1. Official roster contains student1@demo.edu with roll CS-2026-001
    # Invalid roll number should fail 400
    bad_req = client.post(
        "/api/auth/recover-account",
        json={"email": "student1@demo.edu", "roll_number": "WRONG-ROLL"},
    )
    assert bad_req.status_code == 400
    assert "ROLL_NUMBER_MISMATCH" in bad_req.json()["detail"]

    # 2. Legitimate request with correct email and roll number
    good_req = client.post(
        "/api/auth/recover-account",
        json={"email": "student1@demo.edu", "roll_number": "CS-2026-001"},
    )
    assert good_req.status_code == 200
    data = good_req.json()
    assert data["status"] == "success"
    recovery_token = data["recovery_token"]
    assert recovery_token and len(recovery_token) > 20

    # 3. Tampered recovery token fails 400
    tampered = recovery_token[:-4] + "fake"
    bad_reset = client.post(
        "/api/auth/reset-password",
        json={"recovery_token": tampered, "new_password": "newpassword123"},
    )
    assert bad_reset.status_code == 400

    # 4. Valid reset
    good_reset = client.post(
        "/api/auth/reset-password",
        json={"recovery_token": recovery_token, "new_password": "brandnewpassword456"},
    )
    assert good_reset.status_code == 200
    assert good_reset.json()["status"] == "success"

    # 5. Verify new password allows login
    new_token = _login("student1@demo.edu", "brandnewpassword456", "student")
    assert new_token is not None


def test_controller_registry_import_preview_and_duplicates():
    ctrl_token = _login("controller@demo.edu", "admin123", "controller")
    headers = {"Authorization": f"Bearer {ctrl_token}"}

    # CSV with 1 existing (Jordan Ellis), 1 new, and 1 in-file duplicate
    csv_content = """name,email,roll_number,student_id,class_code
Jordan Ellis,student1@demo.edu,CS-2026-001,STU-9021,CS-101
Aarav Sharma,aarav@demo.edu,CS-2026-088,STU-9088,CS-101
Duplicate Aarav,aarav@demo.edu,CS-2026-088,STU-9088,CS-101
"""

    # 1. Preview mode: should report statistics and sample without inserting Aarav yet
    preview_res = client.post(
        "/api/controller/registry/import?preview=true",
        headers=headers,
        files={"file": ("roster.csv", io.BytesIO(csv_content.encode("utf-8")), "text/csv")},
    )
    assert preview_res.status_code == 200
    preview_data = preview_res.json()
    assert preview_data["preview"] is True
    assert preview_data["total_processed"] == 3
    assert preview_data["new_count"] >= 1
    assert preview_data["updated_count"] >= 1
    assert len(preview_data["duplicate_warnings"]) >= 1

    # Check that Aarav is not in profiles yet
    db = supa()
    aarav_check = db.table("profiles").select("*").eq("email", "aarav@demo.edu").execute().data
    assert not aarav_check

    # 2. Commit mode: now run without preview
    commit_res = client.post(
        "/api/controller/registry/import?preview=false",
        headers=headers,
        files={"file": ("roster.csv", io.BytesIO(csv_content.encode("utf-8")), "text/csv")},
    )
    assert commit_res.status_code == 200
    commit_data = commit_res.json()
    assert commit_data["imported"] >= 1

    # Check that Aarav is now in profiles
    aarav_created = db.table("profiles").select("*").eq("email", "aarav@demo.edu").execute().data
    assert len(aarav_created) == 1

    # 3. Duplicate scanner endpoint
    dup_res = client.get("/api/controller/students/duplicates", headers=headers)
    assert dup_res.status_code == 200
    dup_data = dup_res.json()
    assert "duplicate_email_groups" in dup_data
    assert "duplicate_roll_groups" in dup_data
    assert "total_duplicate_conflicts" in dup_data


def test_timetable_and_calendar_ics_and_sync():
    student_token = _login("student1@demo.edu", "pass123", "student")
    s_headers = {"Authorization": f"Bearer {student_token}"}

    # 1. Student timetable query
    tt_res = client.get("/api/timetable", headers=s_headers)
    assert tt_res.status_code == 200
    tt_data = tt_res.json()
    assert "timetable" in tt_data
    assert "today_classes" in tt_data
    assert "total_classes" in tt_data

    # 2. iCalendar .ics export stream
    ics_res = client.get("/api/timetable/calendar.ics", headers=s_headers)
    assert ics_res.status_code == 200
    assert ics_res.headers["content-type"].startswith("text/calendar")
    ics_text = ics_res.text
    assert "BEGIN:VCALENDAR" in ics_text
    assert "VERSION:2.0" in ics_text
    assert "SUMMARY:" in ics_text
    assert "END:VCALENDAR" in ics_text

    # 3. Google Calendar URL generator
    gcal_res = client.get("/api/timetable/google-calendar-url", headers=s_headers)
    assert gcal_res.status_code == 200
    gcal_data = gcal_res.json()
    assert "google_calendar_url" in gcal_data
    assert "calendar.google.com/calendar/render" in gcal_data["google_calendar_url"]

    # 4. Teacher/Controller update timetable entry and verify notification
    ctrl_token = _login("controller@demo.edu", "admin123", "controller")
    c_headers = {"Authorization": f"Bearer {ctrl_token}"}
    
    entries = tt_data["timetable"]
    if entries:
        entry_id = entries[0]["id"]
        patch_res = client.patch(
            f"/api/timetable/{entry_id}",
            headers=c_headers,
            json={"room_number": "LH-Auditorium-A"},
        )
        assert patch_res.status_code == 200
        assert patch_res.json()["room_number"] == "LH-Auditorium-A"

        # Check notification was generated for room change
        notif_res = client.get("/api/notifications", headers=s_headers)
        assert notif_res.status_code == 200
        titles = [n["title"] for n in notif_res.json()]
        assert any("Room Change" in t for t in titles)


def test_panorama_compression_and_occupancy_analysis():
    ctrl_token = _login("controller@demo.edu", "admin123", "controller")
    headers = {"Authorization": f"Bearer {ctrl_token}"}

    # Fetch existing class id
    db = supa()
    classes = db.table("classes").select("id").execute().data
    assert classes, "No classes found in test database"
    target_class_id = classes[0]["id"]

    # Generate a synthetic image (1600x1200) with sufficient brightness & contrast
    large_img = np.full((1200, 1600, 3), 180, dtype=np.uint8)
    # Add high-contrast features for Laplacian variance
    cv2.putText(large_img, "LECTURE HALL 120", (100, 200), cv2.FONT_HERSHEY_SIMPLEX, 3.0, (20, 20, 20), 5)
    cv2.rectangle(large_img, (50, 50), (1550, 1150), (0, 0, 0), 8)

    _, encoded = cv2.imencode(".jpg", large_img)
    img_bytes = encoded.tobytes()

    res = client.post(
        f"/api/controller/classes/{target_class_id}/capture-room",
        headers=headers,
        files={"photo": ("panorama.jpg", io.BytesIO(img_bytes), "image/jpeg")},
        data={"capacity": "120", "room_number": "LH-120"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["capacity"] == 120
    assert "estimated_occupancy_count" in data
    assert "density_pct" in data
    assert data["room_photo"].startswith("data:image/jpeg;base64,")
    # Verify downsampled image was compressed efficiently (< 300KB)
    assert len(data["room_photo"]) < 300000
