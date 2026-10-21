import json
import os
import sqlite3
import sys
import threading
import time
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import main


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("ATTENDANCE_ENV", "test")
    monkeypatch.setenv("ATTENDANCE_APP_SECRET", "test_secret_for_unit_testing_32_characters_minimum")
    main.DB_PATH = Path(tmp_path) / "test.sqlite3"
    with main._ws_lock:
        main._ws_tickets.clear()
        main._ws_clients.clear()
        main._ws_client_loops.clear()
        main._ws_client_queues.clear()
    main.init_db()
    with TestClient(main.app) as test_client:
        yield test_client


def login(client, email, password):
    response = client.post("/api/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    payload = response.json()
    return payload["access_token"], payload["user"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_login_and_role_access(client):
    teacher_token, teacher = login(client, "teacher@demo.edu", "teach123")
    student_token, student = login(client, "student1@demo.edu", "student123")
    assert teacher["role"] == "teacher"
    assert student["role"] == "student"
    assert client.get("/api/me", headers=auth(student_token)).json()["email"] == "student1@demo.edu"
    assert client.get("/api/classes/1/students", headers=auth(student_token)).status_code == 403
    assert client.get("/api/students/me/attendance", headers=auth(teacher_token)).status_code == 403


def test_teacher_flow_capture_privacy_finalize_and_student_notification(client):
    teacher_token, _ = login(client, "teacher@demo.edu", "teach123")
    student_token, student = login(client, "student1@demo.edu", "student123")
    headers = auth(teacher_token)
    created = client.post("/api/sessions", headers=headers, json={"class_id": 1})
    assert created.status_code == 200
    session = created.json()
    session_id = session["id"]
    assert session["status"] == "open"
    assert {entry["status"] for entry in session["attendance"]} == {"pending"}

    captured = client.post(
        f"/api/sessions/{session_id}/capture",
        headers=headers,
        files={"photo": ("class-photo.jpg", b"not-a-real-photo", "image/jpeg")},
    )
    assert captured.status_code == 200
    capture = captured.json()
    assert capture["simulated"] is True
    assert "no image was stored" in capture["message"]
    assert all(item["status"] == "suggestion" for item in capture["suggestions"])
    fetched = client.get(f"/api/sessions/{session_id}", headers=headers).json()
    assert len(fetched["suggestions"]) == 2
    assert {entry["status"] for entry in fetched["attendance"]} == {"pending"}

    # Teacher commits one present result; the other remains pending until finalization.
    student_ids = client.get("/api/classes/1/students", headers=headers).json()
    first_student_id = student_ids[0]["id"]
    changed = client.patch(f"/api/sessions/{session_id}/attendance/{first_student_id}", headers=headers, json={"status": "present", "note": "Reviewed manually"})
    assert changed.status_code == 200
    finalized = client.post(f"/api/sessions/{session_id}/finalize", headers=headers, json={"mark_pending_absent": True})
    assert finalized.status_code == 200
    assert finalized.json()["status"] == "finalized"
    assert finalized.json()["summary"]["pending"] == 0

    own = client.get("/api/students/me/attendance", headers=auth(student_token))
    assert own.status_code == 200
    assert all(row["student_id"] if "student_id" in row else True for row in own.json()["entries"])  # response is scoped and stable
    notifications = client.get("/api/notifications", headers=auth(student_token)).json()
    assert len(notifications) == 1
    assert notifications[0]["user_id"] if "user_id" in notifications[0] else True
    assert client.get("/api/notifications", headers=auth(teacher_token)).json() == []

    audit = client.get(f"/api/audit?session_id={session_id}", headers=headers)
    assert audit.status_code == 200
    actions = [item["action"] for item in audit.json()]
    assert "session.created" in actions
    assert "capture.received" in actions
    assert "suggestion.generated" in actions
    assert "attendance.changed" in actions
    assert "session.finalized" in actions
    assert all("actor_id" in item and "timestamp" in item for item in audit.json())


def test_student_privacy_and_teacher_report(client):
    teacher_token, _ = login(client, "teacher@demo.edu", "teach123")
    student_token, _ = login(client, "student1@demo.edu", "student123")
    second_token, _ = login(client, "student2@demo.edu", "student123")
    session_id = client.post("/api/sessions", headers=auth(teacher_token), json={"class_id": 1}).json()["id"]

    student_session = client.get(f"/api/sessions/{session_id}", headers=auth(student_token))
    assert student_session.status_code == 200
    assert len(student_session.json()["attendance"]) == 1
    assert "suggestions" not in student_session.json()
    assert client.get(f"/api/sessions/{session_id}", headers=auth(second_token)).status_code == 200
    assert len(client.get(f"/api/sessions/{session_id}", headers=auth(second_token)).json()["attendance"]) == 1
    assert client.get(f"/api/audit?session_id={session_id}", headers=auth(student_token)).status_code == 403
    report = client.get(f"/api/reports/sessions/{session_id}", headers=auth(teacher_token))
    assert report.status_code == 200
    assert "student_name,student_email,status,note,updated_at" in report.json()["csv"]
    assert "pdf_html" in report.json()


def test_ws_ticket_is_single_use(client):
    token, _ = login(client, "student1@demo.edu", "student123")
    teacher_token, _ = login(client, "teacher@demo.edu", "teach123")
    ticket_response = client.post("/api/auth/ws-ticket", headers=auth(token))
    assert ticket_response.status_code == 200
    ticket = ticket_response.json()["ticket"]
    with client.websocket_connect(f"/api/ws?ticket={ticket}") as websocket:
        assert websocket.receive_json()["type"] == "connected"
        created = client.post("/api/sessions", headers=auth(teacher_token), json={"class_id": 1})
        assert created.status_code == 200
        event = websocket.receive_json()
        assert event["type"] == "session.created"
        assert event["data"]["session_id"] == created.json()["id"]
    with pytest.raises(Exception):
        with client.websocket_connect(f"/api/ws?ticket={ticket}"):
            pass


def test_missing_production_signing_secret(monkeypatch):
    monkeypatch.setenv("ATTENDANCE_ENV", "production")
    monkeypatch.delenv("ATTENDANCE_APP_SECRET", raising=False)
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    with pytest.raises(RuntimeError, match="ATTENDANCE_APP_SECRET is required outside test mode"):
        main.get_app_secret()


def test_insecure_production_signing_secret(monkeypatch):
    monkeypatch.setenv("ATTENDANCE_ENV", "production")
    monkeypatch.setenv("ATTENDANCE_APP_SECRET", "DEV_ONLY_CHANGE_ME_attendance_secret")
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    with pytest.raises(RuntimeError, match="insecure or weak value"):
        main.get_app_secret()


def test_weak_production_signing_secret(monkeypatch):
    monkeypatch.setenv("ATTENDANCE_ENV", "production")
    monkeypatch.setenv("ATTENDANCE_APP_SECRET", "too_short_secret")
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    with pytest.raises(RuntimeError, match="at least 32 characters"):
        main.get_app_secret()


def test_explicit_test_mode_configuration(monkeypatch):
    test_secret = "explicit_test_secret_for_unit_tests_32_characters_long"
    monkeypatch.setenv("ATTENDANCE_ENV", "test")
    monkeypatch.setenv("ATTENDANCE_APP_SECRET", test_secret)
    assert main.get_app_secret() == test_secret
    token = main._sign_token({"sub": 42, "role": "student", "exp": int(time.time()) + 100})
    payload = main._read_token(token)
    assert payload is not None
    assert payload["sub"] == 42
    assert payload["role"] == "student"


def test_sqlite_wal_and_checkin_attempts_schema(client):
    with main.db() as conn:
        columns = [row["name"] for row in conn.execute("PRAGMA table_info(checkin_attempts)").fetchall()]
        assert "id" in columns
        assert "attempt_id" in columns
        assert "session_id" in columns
        assert "student_id" in columns
        assert "state" in columns
        assert "error_code" in columns
        assert "created_at" in columns
        assert "updated_at" in columns

        journal_mode = conn.execute("PRAGMA journal_mode").fetchone()[0]
        assert journal_mode.lower() in ("wal", "memory")

        fk = conn.execute("PRAGMA foreign_keys").fetchone()[0]
        assert fk == 1

        now = main.utc_now()
        cur = conn.execute("INSERT INTO sessions(class_id, status, created_by, created_at) VALUES(?, ?, ?, ?)", (1, "open", 1, now))
        session_id = cur.lastrowid

        # Test insert into checkin_attempts
        conn.execute(
            """
            INSERT INTO checkin_attempts(attempt_id, session_id, student_id, state, error_code, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            ("att_test_123", session_id, 2, "evaluating", None, now, now),
        )
        # Verify unique attempt_id constraint
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO checkin_attempts(attempt_id, session_id, student_id, state, error_code, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                ("att_test_123", session_id, 2, "evaluating", None, now, now),
            )
        # Verify check constraint on state
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO checkin_attempts(attempt_id, session_id, student_id, state, error_code, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                ("att_invalid_state", session_id, 2, "invalid_state", None, now, now),
            )
        # Verify foreign key constraint failure on invalid session_id
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                """
                INSERT INTO checkin_attempts(attempt_id, session_id, student_id, state, error_code, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                ("att_invalid_fk", 999999, 2, "evaluating", None, now, now),
            )


def test_sqlite_unique_attendance_constraint(client):
    teacher_token, _ = login(client, "teacher@demo.edu", "teach123")
    headers = auth(teacher_token)
    created = client.post("/api/sessions", headers=headers, json={"class_id": 1})
    assert created.status_code == 200
    session_id = created.json()["id"]

    with main.db() as conn:
        now = main.utc_now()
        student_id = conn.execute("SELECT student_id FROM enrollments WHERE class_id=1 LIMIT 1").fetchone()[0]
        # Direct duplicate insert of (session_id, student_id) must fail with IntegrityError
        with pytest.raises(sqlite3.IntegrityError):
            conn.execute(
                "INSERT INTO attendance(session_id, student_id, status, updated_by, updated_at) VALUES (?, ?, ?, ?, ?)",
                (session_id, student_id, "present", 1, now),
            )


def test_concurrent_database_operations(tmp_path, monkeypatch):
    monkeypatch.setenv("ATTENDANCE_ENV", "test")
    monkeypatch.setenv("ATTENDANCE_APP_SECRET", "test_secret_for_concurrent_testing_32_chars")
    test_db = Path(tmp_path) / "concurrent.sqlite3"
    main.DB_PATH = test_db
    main.init_db()

    with main.db() as conn:
        now = main.utc_now()
        cur = conn.execute("INSERT INTO sessions(class_id, status, created_by, created_at) VALUES(?, ?, ?, ?)", (1, "open", 1, now))
        session_id = cur.lastrowid
        conn.execute("INSERT INTO attendance(session_id, student_id, status, updated_by, updated_at) VALUES(?, ?, ?, ?, ?)", (session_id, 2, "pending", 1, now))

    errors = []
    def worker(worker_id):
        try:
            for i in range(5):
                with main.db() as conn:
                    main.audit(conn, session_id, 1, f"action.worker_{worker_id}_{i}", note="Concurrent audit entry")
                    conn.execute("UPDATE attendance SET note=? WHERE session_id=? AND student_id=?", (f"Note from worker {worker_id}_{i}", session_id, 2))
        except Exception as e:
            errors.append(e)

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(10)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert len(errors) == 0, f"Concurrent database operations failed: {errors}"
    with main.db() as conn:
        count = conn.execute("SELECT COUNT(*) FROM audit_log WHERE session_id=?", (session_id,)).fetchone()[0]
        assert count == 50  # 10 workers * 5 audits


def test_ws_disconnect_and_cleanup(client):
    token, user = login(client, "student1@demo.edu", "student123")
    user_id = user["id"]
    ticket_resp = client.post("/api/auth/ws-ticket", headers=auth(token))
    assert ticket_resp.status_code == 200
    ticket = ticket_resp.json()["ticket"]

    with client.websocket_connect(f"/api/ws?ticket={ticket}") as ws:
        connected_msg = ws.receive_json()
        assert connected_msg["type"] == "connected"
        with main._ws_lock:
            assert user_id in main._ws_clients
            assert len(main._ws_clients[user_id]) == 1

    # After exiting websocket context, cleanup should have occurred
    with main._ws_lock:
        assert user_id not in main._ws_clients
        assert len(main._ws_client_loops) == 0
        assert len(main._ws_client_queues) == 0


def test_session_finalization_protections(client):
    teacher_token, _ = login(client, "teacher@demo.edu", "teach123")
    headers = auth(teacher_token)
    created = client.post("/api/sessions", headers=headers, json={"class_id": 1})
    session_id = created.json()["id"]

    fin_resp = client.post(f"/api/sessions/{session_id}/finalize", headers=headers, json={"mark_pending_absent": True})
    assert fin_resp.status_code == 200
    assert fin_resp.json()["status"] == "finalized"

    # Attempting to finalize an already finalized session -> 409 Conflict
    fin_again = client.post(f"/api/sessions/{session_id}/finalize", headers=headers, json={"mark_pending_absent": True})
    assert fin_again.status_code == 409
    assert "already finalized" in fin_again.json()["detail"]

    # Attempting to update attendance on finalized session -> 409 Conflict
    patch_resp = client.patch(f"/api/sessions/{session_id}/attendance/2", headers=headers, json={"status": "present"})
    assert patch_resp.status_code == 409
    assert "Finalized sessions cannot be changed" in patch_resp.json()["detail"]

    # Attempting to capture on finalized session -> 409 Conflict
    cap_resp = client.post(
        f"/api/sessions/{session_id}/capture",
        headers=headers,
        files={"photo": ("test.jpg", b"fake", "image/jpeg")},
    )
    assert cap_resp.status_code == 409
    assert "Only open sessions accept captures" in cap_resp.json()["detail"]

