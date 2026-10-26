from __future__ import annotations

import asyncio
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-anon-key")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-jwt-secret-that-is-long-enough-for-hs256")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import main
from app.verification import RuleResult, evaluate_sweep, inside_submission_window
from app.verification_config import VerificationConfig
from app.verification_pipeline import decide, hash_distance


class Query:
    def __init__(self, data): self.data = data
    def select(self, *_args, **_kwargs): return self
    def eq(self, *_args, **_kwargs): return self
    def single(self): return self
    def execute(self): return SimpleNamespace(data=self.data)


class FakeSupabase:
    def __init__(self, profile, user_id="user-1"):
        self.profile = profile
        self.auth = SimpleNamespace(
            sign_in_with_password=lambda _credentials: SimpleNamespace(
                user=SimpleNamespace(id=user_id),
                session=SimpleNamespace(access_token="signed-access-token"),
            ),
            get_user=lambda _token: SimpleNamespace(user=SimpleNamespace(id=user_id)),
        )
    def table(self, _name): return Query(self.profile)


def test_jwt_requires_valid_signature_and_authenticated_audience(monkeypatch):
    monkeypatch.setattr(main, "SUPABASE_JWT_SECRET", "unit-test-secret")
    token = main.pyjwt.encode({"sub": "student-1", "aud": "authenticated", "exp": int(time.time()) + 60}, "unit-test-secret", algorithm="HS256")
    assert main._verify_supabase_jwt(token)["sub"] == "student-1"
    with pytest.raises(HTTPException) as invalid: main._verify_supabase_jwt(token + "tampered")
    assert invalid.value.status_code == 401


def test_login_checks_authoritative_profile_role(monkeypatch):
    fake = FakeSupabase({"id": "user-1", "name": "Student One", "email": "s@example.test", "role": "student"})
    monkeypatch.setattr(main, "supa", lambda: fake)
    request = SimpleNamespace(client=SimpleNamespace(host="127.0.0.1"))
    result = main.login(main.LoginRequest(email="s@example.test", password="secret", selected_role="student"), request)
    assert result["user"]["role"] == "student"
    with pytest.raises(HTTPException) as mismatch:
        main.login(main.LoginRequest(email="s@example.test", password="secret", selected_role="teacher"), request)
    assert mismatch.value.status_code == 403


def test_current_user_requires_bearer_and_valid_supabase_identity(monkeypatch):
    monkeypatch.setattr(main, "supa", lambda: FakeSupabase({"id": "student-1", "role": "student"}, "student-1"))
    assert main.current_user("Bearer good-token")["role"] == "student"
    with pytest.raises(HTTPException) as missing: main.current_user(None)
    assert missing.value.status_code == 401
    monkeypatch.setattr(main, "supa", lambda: FakeSupabase(None))
    with pytest.raises(HTTPException) as rejected: main.current_user("Bearer invalid-token")
    assert rejected.value.status_code == 401


def test_teacher_guard_rejects_student():
    with pytest.raises(HTTPException) as denied: main.require_teacher({"id": "s1", "role": "student"})
    assert denied.value.status_code == 403


def test_submission_rate_limit_is_enforced_per_user(monkeypatch):
    monkeypatch.setattr(main, "SUBMIT_RATE_LIMIT", 2)
    monkeypatch.setattr(main, "SUBMIT_RATE_WINDOW_SECONDS", 60)
    with main._submit_rate_lock:
        main._submit_attempts.clear()
    main.enforce_submit_rate("student-rate-test")
    main.enforce_submit_rate("student-rate-test")
    with pytest.raises(HTTPException) as limited:
        main.enforce_submit_rate("student-rate-test")
    assert limited.value.status_code == 429
    main.enforce_submit_rate("another-student")


def test_image_upload_rejects_wrong_mime_and_oversized_payload():
    class Photo:
        def __init__(self, content_type, data):
            self.content_type, self.data = content_type, data
        async def read(self, limit):
            return self.data[:limit]

    with pytest.raises(HTTPException) as wrong_type:
        asyncio.run(main._read_image_upload(Photo("text/plain", b"hello")))
    assert wrong_type.value.status_code == 415
    oversized = Photo("image/jpeg", b"\xff\xd8\xff" + b"x" * 12)
    with pytest.raises(HTTPException) as too_large:
        asyncio.run(main._read_image_upload(oversized, max_bytes=10))
    assert too_large.value.status_code == 413


def test_session_access_requires_class_enrollment(monkeypatch):
    monkeypatch.setattr(main, "supa", lambda: FakeSupabase([]))
    row = {"id": "session-1", "class_id": "class-1", "teacher_id": "teacher-1"}
    with pytest.raises(HTTPException) as denied: main._assert_session_access(row, {"id": "student-1", "role": "student"})
    assert denied.value.status_code == 403
    with pytest.raises(HTTPException) as teacher_denied: main._assert_session_access(row, {"id": "teacher-2", "role": "teacher"})
    assert teacher_denied.value.status_code == 403


def test_retired_photo_capture_never_creates_suggestions():
    with pytest.raises(HTTPException) as retired: main.capture({"id": "teacher-1", "role": "teacher"})
    assert retired.value.status_code == 410
    with pytest.raises(HTTPException) as forbidden: main.capture({"id": "student-1", "role": "student"})
    assert forbidden.value.status_code == 403


def test_websocket_ticket_is_single_use():
    with main._ws_lock: main._ws_tickets.clear()
    ticket = main.ws_ticket({"id": "student-1", "role": "student"})["ticket"]
    with main._ws_lock: stored = main._ws_tickets.pop(ticket)
    assert stored[0] == "student-1" and stored[1] > time.time()
    with main._ws_lock: assert main._ws_tickets.pop(ticket, None) is None


def _sweep(count=13, headings=None, continuity=True):
    headings = headings or [i * 15 for i in range(count)]
    return [{"offset_seconds": i * (10 / max(count - 1, 1)), "heading_degrees": headings[i], "continuity_ok": continuity} for i in range(count)]


def test_sweep_minimum_frame_count_and_capture_duration():
    assert evaluate_sweep(_sweep(11), 10)["frame_count"].reason_code == "sweep.too_few_frames"
    assert evaluate_sweep(_sweep(), 3)["duration"].reason_code == "sweep.duration_out_of_range"
    assert evaluate_sweep(_sweep(), 10)["frame_count"].passed is True


def test_sweep_heading_monotonicity_gap_span_and_continuity():
    assert evaluate_sweep(_sweep(), 10)["heading_span"].passed is True
    short = [i * 5 for i in range(13)]
    assert evaluate_sweep(_sweep(headings=short), 10)["heading_span"].passed is False
    reversed_sweep = [0, 15, 30, 45, 60, 75, 90, 75, 60, 45, 30, 15, 0]
    assert evaluate_sweep(_sweep(headings=reversed_sweep), 10)["heading_monotonic"].passed is False
    gap = [0, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 210]
    assert evaluate_sweep(_sweep(headings=gap), 10)["heading_gap"].passed is False
    assert evaluate_sweep(_sweep(continuity=False), 10)["visual_continuity"].reason_code == "sweep.visual_discontinuity"


def test_verification_policy_and_duplicate_hash_distance():
    assert decide({"self": RuleResult(False, "reject.self_not_matched", "no match")})["status"] == "rejected"
    assert decide({"lecturer": RuleResult(None, "review.lecturer_face_too_small", "small")})["status"] == "flagged"
    assert decide({"all": RuleResult(True, "ok", "pass")})["status"] == "verified"
    assert hash_distance("1010", "1010") == 0
    assert hash_distance("1010", "0011") == 2


def test_submission_uses_server_time_and_rejects_after_grace():
    end = datetime(2026, 1, 1, tzinfo=timezone.utc)
    assert inside_submission_window("closed", end, end + timedelta(seconds=5))
    assert not inside_submission_window("closed", end, end + timedelta(seconds=6))
    assert not inside_submission_window("finalized", end, end + timedelta(seconds=1))


def test_verification_threshold_defaults_documented():
    config = VerificationConfig()
    assert config.minimum_frames == 12
    assert config.minimum_heading_span_degrees == 150
    assert config.self_pass_similarity == 0.72
    assert config.self_review_similarity == 0.50


def test_session_auto_close_runs_once_and_emits_exact_counts(monkeypatch):
    class Builder:
        def __init__(self, store, table):
            self.store, self.table_name, self.action = store, table, "select"
            self.payload = None
        def select(self, *_args, **_kwargs): self.action = "select"; return self
        def eq(self, *_args, **_kwargs): return self
        def lte(self, *_args, **_kwargs): return self
        def update(self, payload): self.action, self.payload = "update", payload; return self
        def insert(self, payload): self.action, self.payload = "insert", payload; return self
        def execute(self):
            if self.table_name == "sessions":
                if self.action == "select":
                    return SimpleNamespace(data=[] if self.store.closed else [self.store.session])
                if self.action == "update":
                    if self.store.closed: return SimpleNamespace(data=[])
                    self.store.closed = True
                    return SimpleNamespace(data=[self.store.session])
            if self.table_name == "attendance": return SimpleNamespace(data=[{"status": "present"}, {"status": "pending"}, {"status": "absent"}])
            if self.table_name == "checkin_attempts": return SimpleNamespace(data=[{"state": "rejected"}, {"state": "flagged"}])
            if self.table_name == "enrollments": return SimpleNamespace(data=[{"student_id": "s1"}, {"student_id": "s2"}, {"student_id": "s3"}])
            if self.table_name == "audit_log": self.store.audits.append(self.payload); return SimpleNamespace(data=[self.payload])
            if self.table_name == "notifications": self.store.notifications.append(self.payload); return SimpleNamespace(data=[self.payload])
            return SimpleNamespace(data=[])

    class Store:
        def __init__(self):
            self.closed = False
            self.session = {"id": "session-1", "class_id": "class-1", "created_by": "teacher-1", "ends_at": "2026-01-01T00:00:00+00:00"}
            self.audits, self.notifications = [], []
        def table(self, name): return Builder(self, name)

    store = Store()
    emitted = []
    monkeypatch.setattr(main, "supa", lambda: store)
    monkeypatch.setattr(main, "publish_event", lambda event, user_ids: emitted.append((event, user_ids)))
    assert main.close_expired_sessions("2026-01-01T00:00:05+00:00") == ["session-1"]
    assert main.close_expired_sessions("2026-01-01T00:00:06+00:00") == []
    assert len(store.audits) == len(store.notifications) == len(emitted) == 1
    assert emitted[0][0]["type"] == "session.closed"
    assert emitted[0][0]["data"] == {
        "session_id": "session-1", "present": 1, "needs_review": 1,
        "absent": 1, "rejected_attempts": 1, "total_enrolled": 3,
    }
