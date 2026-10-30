"""Tests for session-owned classroom panorama capture and processing."""
from __future__ import annotations

import os
import sys
import asyncio
from pathlib import Path

import cv2
import numpy as np
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))
os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from app.db import reset_test_db, supa
from app import main
from app.main import app

client = TestClient(app)
CLASS_ID = "11111111-1111-1111-1111-111111111111"


def _jpeg(seed: int) -> bytes:
    rng = np.random.default_rng(seed)
    image = rng.integers(0, 256, (480, 640, 3), dtype=np.uint8)
    ok, encoded = cv2.imencode(".jpg", image)
    assert ok
    return encoded.tobytes()


def _login(email: str) -> dict[str, str]:
    response = client.post(
        "/api/auth/login",
        json={"email": email, "password": "password123"},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def _open_session(headers: dict[str, str]) -> str:
    response = client.post(
        "/api/sessions",
        headers=headers,
        json={"class_id": CLASS_ID, "duration_minutes": 15},
    )
    assert response.status_code == 200
    return response.json()["id"]


def _frames() -> list[tuple[str, tuple[str, bytes, str]]]:
    return [
        ("frames", (f"view_{index}.jpg", _jpeg(index), "image/jpeg"))
        for index in range(4)
    ]


def test_teacher_uploads_session_panorama_and_retrieves_processing_result(monkeypatch):
    reset_test_db()
    teacher_headers = _login("teacher@demo.edu")
    session_id = _open_session(teacher_headers)
    attendance_before = supa().table("attendance").select("*").eq("session_id", session_id).execute().data

    def finish_job(panorama_id: str, *_args, **_kwargs) -> None:
        supa().table("classroom_panoramas").update({
            "status": "completed",
            "panorama_path": f"{panorama_id}/panorama.jpg",
            "occupancy_count": 7,
            "quality_results": {"valid": True, "blur_score": 88.4},
            "context_analysis": {"matched": None},
            "warnings": [],
            "processed_at": "2026-10-30T00:00:00+00:00",
        }).eq("id", panorama_id).execute()

    monkeypatch.setattr("app.main._process_panorama_job", finish_job, raising=False)
    response = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=teacher_headers,
        data={"capture_id": "capture-test-001"},
        files=_frames(),
    )
    assert response.status_code == 202
    job = response.json()
    assert job["session_id"] == session_id
    assert job["status"] == "processing"

    result = client.get(
        f"/api/sessions/{session_id}/panorama/{job['id']}",
        headers=teacher_headers,
    )
    assert result.status_code == 200
    assert result.json()["quality_results"]["valid"] is True
    assert result.json()["occupancy_count"] == 7
    assert result.json()["panorama_url"].startswith("https://mock-storage.local/")
    attendance_after = supa().table("attendance").select("*").eq("session_id", session_id).execute().data
    assert attendance_after == attendance_before


def test_student_cannot_upload_classroom_panorama():
    reset_test_db()
    teacher_headers = _login("teacher@demo.edu")
    student_headers = _login("student1@demo.edu")
    session_id = _open_session(teacher_headers)

    response = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=student_headers,
        data={"capture_id": "capture-student-001"},
        files=_frames(),
    )
    assert response.status_code == 403


def test_panorama_upload_rejects_non_image_payload():
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    files = [("frames", (f"view_{index}.jpg", b"not an image", "image/jpeg")) for index in range(4)]

    response = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=headers,
        data={"capture_id": "capture-invalid-001"},
        files=files,
    )
    assert response.status_code == 400


def test_closed_session_rejects_panorama_upload():
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    supa().table("sessions").update({"status": "closed"}).eq("id", session_id).execute()

    response = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=headers,
        data={"capture_id": "capture-closed-001"},
        files=_frames(),
    )
    assert response.status_code == 409


def test_expired_open_session_rejects_panorama_upload():
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    supa().table("sessions").update({
        "ends_at": "2000-01-01T00:00:00+00:00",
    }).eq("id", session_id).execute()

    response = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=headers,
        data={"capture_id": "capture-expired-001"},
        files=_frames(),
    )
    assert response.status_code == 409


def test_capture_id_is_idempotent():
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    capture_id = "capture-idempotent-001"
    first = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=headers,
        data={"capture_id": capture_id},
        files=_frames(),
    )
    second = client.post(
        f"/api/sessions/{session_id}/panorama",
        headers=headers,
        data={"capture_id": capture_id},
        files=_frames(),
    )

    assert first.status_code == 202
    assert second.status_code == 202
    assert first.json()["id"] == second.json()["id"]
    rows = supa().table("classroom_panoramas").select("*").eq("session_id", session_id).execute().data
    assert len(rows) == 1


def test_panorama_processing_persists_stitched_detection_results(monkeypatch):
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    panorama_id = "panorama-process-test"
    paths = [f"{session_id}/{panorama_id}/source_{index}.jpg" for index in range(3)]
    bucket = supa().storage.from_(main.PANORAMA_BUCKET)
    for index, path in enumerate(paths):
        bucket.upload(path, _jpeg(index))
    supa().table("classroom_panoramas").insert({
        "id": panorama_id,
        "session_id": session_id,
        "class_id": CLASS_ID,
        "faculty_id": "00000000-0000-0000-0000-000000000001",
        "source_paths": paths,
        "status": "processing",
    }).execute()

    class Stitcher:
        def stitch(self, images):
            assert len(images) == 3
            return cv2.Stitcher_OK, images[0]

    monkeypatch.setattr(cv2, "Stitcher_create", lambda *_args: Stitcher())
    monkeypatch.setattr(main, "_analyze_panorama_image", lambda image: (
        {"valid": True, "width": 640, "height": 480, "acceptable": True},
        {"count": 2, "detections": [], "method": "test"},
        image.copy(),
        [],
    ))

    main._process_panorama_job(panorama_id)
    result = supa().table("classroom_panoramas").select("*").eq("id", panorama_id).execute().data[0]
    assert result["status"] == "completed"
    assert result["occupancy_count"] == 2
    assert result["panorama_path"]
    assert result["annotated_path"]


def test_panorama_processing_failure_does_not_store_an_occupancy_estimate():
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    panorama_id = "panorama-failure-test"
    source_path = f"{session_id}/{panorama_id}/source_0.jpg"
    supa().storage.from_(main.PANORAMA_BUCKET).upload(source_path, b"invalid image")
    supa().table("classroom_panoramas").insert({
        "id": panorama_id,
        "session_id": session_id,
        "class_id": CLASS_ID,
        "faculty_id": "00000000-0000-0000-0000-000000000001",
        "source_paths": [source_path],
        "status": "processing",
        "occupancy_count": None,
    }).execute()

    main._process_panorama_job(panorama_id)
    result = supa().table("classroom_panoramas").select("*").eq("id", panorama_id).execute().data[0]
    assert result["status"] == "failed"
    assert result["occupancy_count"] is None
    assert result["warnings"] == ["PROCESSING_FAILED"]


def test_student_cannot_retrieve_panorama_results():
    reset_test_db()
    teacher_headers = _login("teacher@demo.edu")
    student_headers = _login("student1@demo.edu")
    session_id = _open_session(teacher_headers)
    panorama_id = "panorama-private-test"
    supa().table("classroom_panoramas").insert({
        "id": panorama_id,
        "session_id": session_id,
        "class_id": CLASS_ID,
        "faculty_id": "00000000-0000-0000-0000-000000000001",
        "source_paths": [],
        "status": "completed",
    }).execute()

    response = client.get(
        f"/api/sessions/{session_id}/panorama/{panorama_id}",
        headers=student_headers,
    )
    assert response.status_code == 403


def test_faculty_can_retry_stale_processing_job(monkeypatch):
    reset_test_db()
    headers = _login("teacher@demo.edu")
    session_id = _open_session(headers)
    panorama_id = "stale-panorama"
    source_paths = []
    bucket = supa().storage.from_(main.PANORAMA_BUCKET)
    for index in range(3):
        path = f"{session_id}/{panorama_id}/source_{index}.jpg"
        bucket.upload(path, _jpeg(index))
        source_paths.append(path)
    supa().table("classroom_panoramas").insert({
        "id": panorama_id,
        "capture_id": "stale-capture",
        "session_id": session_id,
        "class_id": CLASS_ID,
        "faculty_id": "00000000-0000-0000-0000-000000000001",
        "source_paths": source_paths,
        "status": "processing",
        "captured_at": "2000-01-01T00:00:00+00:00",
        "occupancy_count": None,
    }).execute()
    monkeypatch.setattr(main, "_process_panorama_job", lambda *_args, **_kwargs: None)
    response = client.post(
        f"/api/sessions/{session_id}/panorama/{panorama_id}/retry",
        headers=headers,
    )

    assert response.status_code == 202
    assert response.json()["status"] == "processing"


def test_expired_panorama_retention_removes_private_source_objects():
    reset_test_db()
    source_path = "session/expired/source_0.jpg"
    bucket = supa().storage.from_(main.PANORAMA_BUCKET)
    bucket.upload(source_path, b"private image")
    supa().table("classroom_panoramas").insert({
        "id": "expired-panorama",
        "session_id": "old-session",
        "source_paths": [source_path],
        "status": "failed",
        "expires_at": "2000-01-01T00:00:00+00:00",
    }).execute()

    assert main._purge_expired_classroom_panoramas() == 1
    assert source_path not in bucket.files
    assert supa().table("classroom_panoramas").select("*").eq("id", "expired-panorama").execute().data == []


def test_request_size_limit_allows_panorama_budget_only_for_panorama_uploads():
    async def invoke(path: str) -> list[dict]:
        sent = []

        async def downstream(scope, receive, send):
            sent.append({"type": "downstream"})

        async def receive():
            return {"type": "http.request", "body": b"", "more_body": False}

        async def send(message):
            sent.append(message)

        middleware = main.RequestSizeLimitMiddleware(downstream)
        await middleware({
            "type": "http",
            "method": "POST",
            "path": path,
            "headers": [(b"content-length", b"16777216")],
        }, receive, send)
        return sent

    panorama_events = asyncio.run(invoke("/api/sessions/session-1/panorama"))
    normal_events = asyncio.run(invoke("/api/sessions/session-1/reference"))
    assert any(event.get("type") == "downstream" for event in panorama_events)
    assert not any(event.get("type") == "downstream" for event in normal_events)


def test_panorama_intelligence_engine_detects_crowd_venue_sir_and_phone():
    # Construct synthetic panorama with crowd, podium Sir, and glowing phone
    img = np.zeros((480, 1280, 3), dtype=np.uint8)
    img[0:150, :] = (200, 200, 200) # ceiling / lights
    img[80:160, 400:880] = (30, 80, 30) # blackboard
    img[160:300, :] = (180, 170, 160) # wall / podium
    img[300:480, :] = (120, 110, 100) # floor / desks

    # Sir at podium
    cv2.circle(img, (640, 160), 20, (200, 180, 150), -1)

    # Phone screen pointing towards camera
    cv2.rectangle(img, (850, 360), (875, 400), (250, 250, 250), -1)

    # Fake session row with 240-seater amphitheater
    session_row = {
        "class_id": CLASS_ID,
        "room_photo": "https://example.com/class-ref.jpg",
    }
    context = main._panorama_context_analysis(img, session_row)
    assert context["venue_classification"]["predicted_capacity"] in (80, 120, 240, 260)

    quality, detections, annotated, warnings = main._analyze_panorama_image(img, session_row=session_row, context=context)
    assert quality["valid"] is True
    assert "venue_classification" in detections
    assert "sir_presence" in detections
    assert "phone_pointing" in detections
    assert detections["phone_pointing"]["detected"] is True
    assert detections["phone_pointing"]["count"] >= 1
    assert "PHONE_POINTING_DETECTED" in warnings
    assert annotated.shape == img.shape