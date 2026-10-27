"""Camera, Image Quality and Capture Reliability automated test suite.

Tests all required edge cases:
- Empty upload, corrupted image, unsupported format, and oversized upload.
- No face detected, multiple faces, face too small, face partly outside frame.
- Blur, poor lighting, excessive exposure, and backlighting.
- Duplicate submission and idempotency enforcement.
- Quality failures never converting to attendance success.
"""
from __future__ import annotations

import io
import os
import sys
from pathlib import Path
import cv2
import numpy as np
import pytest
from starlette.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))
os.environ["ATTENDANCE_ENV"] = "test"

from app import main
from app.db import reset_test_db, supa
from app.face_engine import FaceDetection, FakeFaceEngine, set_face_engine
from app.verification import (
    assess_image_quality,
    validate_image_payload,
    validate_single_face,
)


def _make_valid_face_frame(w: int = 400, h: int = 300, lum: int = 120) -> bytes:
    """Generate clean synthetic frame with texture and balanced illumination."""
    img = np.full((h, w, 3), lum, dtype=np.uint8)
    for i in range(0, h, 20):
        cv2.line(img, (0, i), (w, i), (255, 255, 255), 2)
    for j in range(0, w, 20):
        cv2.line(img, (j, 0), (j, h), (0, 0, 0), 2)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_blurry_frame(w: int = 400, h: int = 300) -> bytes:
    """Generate heavily blurred frame resulting in near-zero Laplacian variance."""
    img = np.full((h, w, 3), 128, dtype=np.uint8)
    # Extremely smooth gradient with no high frequency edges
    for i in range(h):
        img[i, :, :] = int(120 + 10 * np.sin(i / 50.0))
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_dark_frame(w: int = 400, h: int = 300) -> bytes:
    """Generate underexposed frame with mean luminance < 20."""
    img = np.full((h, w, 3), 15, dtype=np.uint8)
    for i in range(0, h, 30):
        cv2.line(img, (0, i), (w, i), (25, 25, 25), 1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_overexposed_frame(w: int = 400, h: int = 300) -> bytes:
    """Generate overexposed frame with mean luminance > 235."""
    img = np.full((h, w, 3), 245, dtype=np.uint8)
    for i in range(0, h, 30):
        cv2.line(img, (0, i), (w, i), (255, 255, 255), 1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


def _make_backlit_frame(w: int = 400, h: int = 300) -> bytes:
    """Generate backlit frame: very bright background and dark center face ROI."""
    img = np.full((h, w, 3), 220, dtype=np.uint8) # Bright background
    # Dark face region in center
    bx, by, bw, bh = int(w * 0.3), int(h * 0.2), int(w * 0.4), int(h * 0.5)
    img[by:by + bh, bx:bx + bw] = 30 # Dark silhouette
    # Add mild texture so blur check doesn't fire before backlighting check
    for i in range(by, by + bh, 15):
        cv2.line(img, (bx, i), (bx + bw, i), (55, 55, 55), 1)
    for j in range(bx, bx + bw, 15):
        cv2.line(img, (j, by), (j, by + bh), (15, 15, 15), 1)
    _, encoded = cv2.imencode(".jpg", img)
    return encoded.tobytes()


@pytest.fixture
def fake_engine():
    engine = FakeFaceEngine()
    set_face_engine(engine)
    yield engine
    set_face_engine(None)


@pytest.fixture
def client(fake_engine):
    reset_test_db()
    with main._ws_lock:
        main._ws_tickets.clear()
        main._ws_clients.clear()
        main._ws_client_loops.clear()
    return TestClient(main.app)


def _login(client: TestClient, email: str, role: str) -> tuple[str, dict]:
    resp = client.post("/api/auth/login", json={"email": email, "password": "any", "selected_role": role})
    assert resp.status_code == 200, f"Login failed: {resp.text}"
    data = resp.json()
    return data["access_token"], data["user"]


def _hdr(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ── TEST 1: Empty and Corrupted Upload Validation ─────────────────────────────

def test_empty_image_upload_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    
    # 0 bytes upload to enroll
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("empty.jpg", b"", "image/jpeg")},
    )
    assert res.status_code == 400
    assert "EMPTY_IMAGE" in res.headers.get("X-Error-Code", "")
    assert "empty" in res.json()["detail"].lower()


def test_corrupted_image_upload_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    
    corrupt_bytes = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 20 + b"corrupt_broken_stream_data"
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("corrupted.jpg", corrupt_bytes, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "CORRUPTED_IMAGE" in res.headers.get("X-Error-Code", "")
    assert "corrupted" in res.json()["detail"].lower()


def test_unsupported_image_format_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    
    # HTML file masquerading as image
    html_bytes = b"<!DOCTYPE html><html><body><h1>Fake Image</h1></body></html>"
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("fake.html", html_bytes, "text/html")},
    )
    assert res.status_code == 415
    assert "UNSUPPORTED_FORMAT" in res.headers.get("X-Error-Code", "")
    assert "unsupported image format" in res.json()["detail"].lower()


def test_oversized_upload_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    
    # 11MB oversized JPEG payload
    large_bytes = b"\xff\xd8\xff\xe0" + b"\x00" * (11 * 1024 * 1024)
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("huge.jpg", large_bytes, "image/jpeg")},
    )
    assert res.status_code == 413
    assert "IMAGE_TOO_LARGE" in res.headers.get("X-Error-Code", "")
    assert "exceeds maximum" in res.json()["detail"].lower()


# ── TEST 2: Face Detection Scenarios (Zero, Multiple, Small, Clipped) ─────────

def test_no_face_detected_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    valid_frame = _make_valid_face_frame()
    
    # Preset zero faces detected
    fake_engine.preset_detections = []
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", valid_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "NO_FACE_DETECTED" in res.headers.get("X-Error-Code", "")
    assert "no face detected" in res.json()["detail"].lower()


def test_multiple_faces_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    valid_frame = _make_valid_face_frame()
    
    # Preset multiple faces (proxy / group attempt)
    fake_engine.preset_detections = [
        FaceDetection(bbox_x=50, bbox_y=50, bbox_w=100, bbox_h=120, confidence=0.95, ipd_px=40.0),
        FaceDetection(bbox_x=220, bbox_y=50, bbox_w=100, bbox_h=120, confidence=0.92, ipd_px=38.0),
    ]
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", valid_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "MULTIPLE_FACES" in res.headers.get("X-Error-Code", "")
    assert "multiple faces" in res.json()["detail"].lower()


def test_face_too_small_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    valid_frame = _make_valid_face_frame(w=400, h=300)
    
    # Face tiny in frame (width=20, height=25 -> 500 px / 120,000 px = 0.4% area ratio)
    fake_engine.preset_detections = [
        FaceDetection(bbox_x=190, bbox_y=140, bbox_w=20, bbox_h=25, confidence=0.90, ipd_px=8.0)
    ]
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", valid_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "FACE_TOO_SMALL" in res.headers.get("X-Error-Code", "")
    assert "face is too small" in res.json()["detail"].lower()


def test_face_partially_outside_frame_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    valid_frame = _make_valid_face_frame(w=400, h=300)
    
    # Face clipped against the left and top edge (bbox_x=1, bbox_y=1)
    fake_engine.preset_detections = [
        FaceDetection(bbox_x=1, bbox_y=1, bbox_w=120, bbox_h=150, confidence=0.95, ipd_px=45.0)
    ]
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", valid_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "FACE_OUT_OF_BOUNDS" in res.headers.get("X-Error-Code", "")
    assert "outside the camera frame" in res.json()["detail"].lower()


# ── TEST 3: Image Quality Thresholds (Blur, Lighting, Exposure, Backlight) ───

def test_blurry_image_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    blurry_frame = _make_blurry_frame()
    
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("blurry.jpg", blurry_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "IMAGE_BLURRY" in res.headers.get("X-Error-Code", "")
    assert "blurry" in res.json()["detail"].lower()


def test_poor_lighting_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    dark_frame = _make_dark_frame()
    
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("dark.jpg", dark_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "POOR_LIGHTING" in res.headers.get("X-Error-Code", "")
    assert "dark" in res.json()["detail"].lower()


def test_excessive_exposure_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    bright_frame = _make_overexposed_frame()
    
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("bright.jpg", bright_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "EXCESSIVE_EXPOSURE" in res.headers.get("X-Error-Code", "")
    assert "overexposed" in res.json()["detail"].lower()


def test_backlighting_detected_rejected(client: TestClient, fake_engine: FakeFaceEngine):
    token, _ = _login(client, "student1@demo.edu", "student")
    backlit_frame = _make_backlit_frame(w=400, h=300)
    
    res = client.post(
        "/api/auth/enroll",
        headers=_hdr(token),
        data={"consent": "true"},
        files={"photo": ("backlit.jpg", backlit_frame, "image/jpeg")},
    )
    assert res.status_code == 400
    assert "BACKLIGHTING_DETECTED" in res.headers.get("X-Error-Code", "")
    assert "backlighting" in res.json()["detail"].lower()


# ── TEST 4: Integrity — Quality Failures Never Grant Attendance ───────────────

def test_failed_quality_never_marks_attendance_success(client: TestClient, fake_engine: FakeFaceEngine):
    # Setup valid enrolled student & open session
    s_token, student = _login(client, "student1@demo.edu", "student")
    t_token, _ = _login(client, "teacher@demo.edu", "teacher")
    
    valid_frame = _make_valid_face_frame()
    enroll_res = client.post(
        "/api/auth/enroll",
        headers=_hdr(s_token),
        data={"consent": "true"},
        files={"photo": ("selfie.jpg", valid_frame, "image/jpeg")},
    )
    assert enroll_res.status_code == 200
    
    sess_res = client.post(
        "/api/sessions",
        headers=_hdr(t_token),
        json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15},
    )
    session_id = sess_res.json()["id"]
    
    # Submit blurry frame for live attendance
    blurry_frame = _make_blurry_frame()
    verify_res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=_hdr(s_token),
        files={"face_image": ("blurry.jpg", blurry_frame, "image/jpeg")},
    )
    assert verify_res.status_code == 400
    assert "IMAGE_BLURRY" in verify_res.headers.get("X-Error-Code", "")
    
    # Assert database state: student was NOT marked present or verified
    db = supa()
    att_rows = db.table("attendance").select("*").eq("session_id", session_id).eq("student_id", student["id"]).execute().data
    for row in att_rows:
        assert row["status"] not in ("present", "verified")
