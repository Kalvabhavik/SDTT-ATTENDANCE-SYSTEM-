import io
import os
import subprocess
import sys
import time
from pathlib import Path

import jwt
import pytest
from PIL import Image
from fastapi import HTTPException
from starlette.requests import Request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import main

TEST_SECRET = "test-secret-for-attendrix-security-tests-32"


def test_realtime_events_have_structured_ordering_metadata():
    first = main.event_payload("attendance.changed", {"session_id": "session-order-test", "student_id": "student-1"})
    second = main.event_payload("attendance.changed", {"session_id": "session-order-test", "student_id": "student-2"})
    assert first["event_id"] != second["event_id"]
    assert first["event_type"] == "attendance.changed"
    assert first["session_id"] == "session-order-test"
    assert second["event_version"] == first["event_version"] + 1
    assert first["occurred_at"] == first["server_timestamp"] == first["created_at"]


def test_jwt_requires_signature_and_authenticated_audience(monkeypatch):
    monkeypatch.setattr(main, "SUPABASE_JWT_SECRET", TEST_SECRET)
    valid = jwt.encode(
        {"sub": "user-1", "aud": "authenticated", "exp": int(time.time()) + 60},
        TEST_SECRET,
        algorithm="HS256",
    )
    assert main._verify_supabase_jwt(valid)["sub"] == "user-1"

    unsigned = jwt.encode(
        {"sub": "attacker", "aud": "authenticated", "exp": int(time.time()) + 60},
        key="",
        algorithm="none",
    )
    with pytest.raises(HTTPException) as exc:
        main._verify_supabase_jwt(unsigned)
    assert exc.value.status_code == 401


def test_jwt_rejects_wrong_audience(monkeypatch):
    monkeypatch.setattr(main, "SUPABASE_JWT_SECRET", TEST_SECRET)
    token = jwt.encode(
        {"sub": "user-1", "aud": "anonymous", "exp": int(time.time()) + 60},
        TEST_SECRET,
        algorithm="HS256",
    )
    with pytest.raises(HTTPException) as exc:
        main._verify_supabase_jwt(token)
    assert exc.value.status_code == 401


def test_capture_validation_requires_real_bounded_image(monkeypatch):
    monkeypatch.setattr(main, "MAX_CAPTURE_PIXELS", 320 * 240)
    image = Image.new("RGB", (320, 240), color="white")
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    assert main._validate_capture(buffer.getvalue(), "image/jpeg") == (320, 240)

    with pytest.raises(HTTPException) as invalid:
        main._validate_capture(b"not-an-image", "image/jpeg")
    assert invalid.value.status_code == 422

    with pytest.raises(HTTPException) as mime:
        main._validate_capture(buffer.getvalue(), "application/octet-stream")
    assert mime.value.status_code == 415


def test_login_rate_limit_is_bounded():
    main._login_attempts.clear()
    scope = {"type": "http", "client": ("127.0.0.1", 1234), "method": "POST", "path": "/api/auth/login", "headers": []}
    request = Request(scope)
    original = main.RATE_LIMIT_MAX_LOGIN_ATTEMPTS
    main.RATE_LIMIT_MAX_LOGIN_ATTEMPTS = 2
    try:
        main._check_login_rate_limit(request, "teacher@example.edu")
        main._check_login_rate_limit(request, "teacher@example.edu")
        with pytest.raises(HTTPException) as exc:
            main._check_login_rate_limit(request, "teacher@example.edu")
        assert exc.value.status_code == 429
    finally:
        main.RATE_LIMIT_MAX_LOGIN_ATTEMPTS = original
        main._login_attempts.clear()


def test_production_configuration_fails_closed_in_fresh_process():
    env = os.environ.copy()
    env.update({"ATTENDANCE_ENV": "production", "SUPABASE_URL": "", "SUPABASE_SERVICE_ROLE_KEY": "", "SUPABASE_JWT_SECRET": ""})
    result = subprocess.run([sys.executable, "-c", "import app.main"], cwd=Path(__file__).resolve().parents[1], env=env, capture_output=True, text=True)
    assert result.returncode != 0
    assert "Missing required production configuration" in result.stderr
