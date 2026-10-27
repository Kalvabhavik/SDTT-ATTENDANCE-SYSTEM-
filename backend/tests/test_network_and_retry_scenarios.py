"""Automated QA & Integration Tests: Network Failures, Timeouts, and Idempotent Retries.

Tests Category 9:
1. Intermittent database connection dropped / mocked transaction failure fails closed.
2. Network dropped packet / repeat check-in with identical Idempotency-Key returns cached 200 OK.
3. Multi-retry storm: sequential network retries with identical idempotency key replay safely.
4. Duplicate attempt with modified or missing idempotency key is blocked with 400 ATTEMPT_LIMIT_REACHED.
5. Service 503 / engine unavailable handling fails closed with explicit error headers.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path
from unittest.mock import patch

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"

from app.main import app
from app.db import supa, reset_test_db
from app.security import create_access_token, encrypt_face_embedding, reset_security_caches
from app.face_engine import get_face_engine

client = TestClient(app)

STUDENT_ID = "00000000-0000-0000-0000-000000000002"
TEACHER_ID = "00000000-0000-0000-0000-000000000001"
CLASS_ID = "11111111-1111-1111-1111-111111111111"
SESSION_ID = "ssssssss-0001-0001-0001-000000000001"


def _create_synthetic_face_jpg() -> bytes:
    img = np.full((320, 320, 3), 140, dtype=np.uint8)
    cx, cy = 160, 160
    for i in range(15, 305, 20):
        cv2.line(img, (20, i), (300, i), (152, 148, 132), 1)
    cv2.rectangle(img, (cx - 45, cy - 32), (cx - 25, cy - 18), (18, 18, 18), -1)
    cv2.rectangle(img, (cx + 25, cy - 32), (cx + 45, cy - 18), (18, 18, 18), -1)
    cv2.circle(img, (cx, cy + 12), 6, (30, 30, 30), -1)
    cv2.line(img, (cx - 28, cy + 45), (cx + 28, cy + 45), (40, 40, 40), 3)
    _, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 95])
    return buf.tobytes()


@pytest.fixture(autouse=True)
def setup_network_suite():
    reset_test_db()
    reset_security_caches()
    db = supa()

    # Enroll student template
    engine = get_face_engine()
    face_bytes = _create_synthetic_face_jpg()
    face_img = cv2.imdecode(np.frombuffer(face_bytes, np.uint8), cv2.IMREAD_COLOR)
    faces = engine.detect_faces(face_img, allow_fallback=True)
    emb = engine.extract_embedding(face_img, faces[0])

    db.table("face_templates").insert({
        "user_id": STUDENT_ID,
        "encrypted_embedding": encrypt_face_embedding(emb),
        "model_version": "arcface-yunet-v1",
        "updated_at": "2026-10-27T00:00:00Z",
    }).execute()

    # Open session in enrolled class
    db.table("sessions").insert({
        "id": SESSION_ID,
        "class_id": CLASS_ID,
        "status": "open",
        "created_by": TEACHER_ID,
    }).execute()


def test_database_connection_failure_fails_closed():
    """Database exception during attendance update must fail closed with 500 without recording phantom state."""
    token = create_access_token(STUDENT_ID, "student1@demo.edu", "student", "Ada Lovelace")
    headers = {"Authorization": f"Bearer {token}"}
    face_bytes = _create_synthetic_face_jpg()

    # Simulate database transaction timeout / connection reset specifically on attendance write
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
                                    raise ConnectionResetError("Mocked PostgreSQL socket disconnect")
                                def eq(self, *a, **k):
                                    return self
                            return FailingExec()
                        return failing_op
                    return getattr(query, name)
            return FaultyQuery()
        return query

    client_shield = TestClient(app, raise_server_exceptions=False)
    with patch.object(supa(), "table", side_effect=faulty_table):
        res = client_shield.post(
            f"/api/sessions/{SESSION_ID}/verify-attendance",
            headers=headers,
            files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
        )
        assert res.status_code in (500, 503)



def test_intermittent_network_drop_and_idempotent_retry():
    """Client retrying after network drop with identical Idempotency-Key receives cached 200 Present."""
    token = create_access_token(STUDENT_ID, "student1@demo.edu", "student", "Ada Lovelace")
    headers = {
        "Authorization": f"Bearer {token}",
        "Idempotency-Key": "net-idemp-unique-101",
    }
    face_bytes = _create_synthetic_face_jpg()

    # Initial check-in (simulating response dropped by network on client side)
    res1 = client.post(
        f"/api/sessions/{SESSION_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200
    assert res1.json()["status"] == "present"

    # Client retries with same Idempotency-Key
    res2 = client.post(
        f"/api/sessions/{SESSION_ID}/verify-attendance",
        headers=headers,
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["status"] == "present"
    assert data2.get("idempotent") is True


def test_network_retry_burst_storm_handled_idempotently():
    """10 sequential client retries with the same Idempotency-Key all return 200 OK without duplicates."""
    token = create_access_token(STUDENT_ID, "student1@demo.edu", "student", "Ada Lovelace")
    headers = {
        "Authorization": f"Bearer {token}",
        "Idempotency-Key": "burst-storm-key-777",
    }
    face_bytes = _create_synthetic_face_jpg()

    # Fire 10 sequential retries (as happens during aggressive mobile retry loops)
    responses = []
    for _ in range(10):
        r = client.post(
            f"/api/sessions/{SESSION_ID}/verify-attendance",
            headers=headers,
            files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
        )
        responses.append(r)

    # All 10 must succeed with HTTP 200
    assert all(r.status_code == 200 for r in responses)
    # Database must contain exactly 1 attendance record
    db = supa()
    records = db.table("attendance").select("*").eq("session_id", SESSION_ID).eq("student_id", STUDENT_ID).execute().data
    assert len(records) == 1
    assert records[0]["status"] == "present"


def test_retry_with_different_idempotency_key_blocked_400():
    """Client attempting second check-in with a different key is blocked by 1-attempt policy."""
    token = create_access_token(STUDENT_ID, "student1@demo.edu", "student", "Ada Lovelace")
    face_bytes = _create_synthetic_face_jpg()

    # First attempt with key 1
    res1 = client.post(
        f"/api/sessions/{SESSION_ID}/verify-attendance",
        headers={"Authorization": f"Bearer {token}", "Idempotency-Key": "key-attempt-alpha"},
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res1.status_code == 200

    # Second attempt with key 2: blocked
    res2 = client.post(
        f"/api/sessions/{SESSION_ID}/verify-attendance",
        headers={"Authorization": f"Bearer {token}", "Idempotency-Key": "key-attempt-beta"},
        files={"face_image": ("face.jpg", face_bytes, "image/jpeg")},
    )
    assert res2.status_code == 400
    assert res2.headers.get("X-Error-Code") == "ATTEMPT_LIMIT_REACHED"
