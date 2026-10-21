"""Classroom attendance prototype API.

This service intentionally implements synthetic, review-first attendance only. It never
stores uploaded photos or face embeddings and makes no biometric/production claims.
"""
from __future__ import annotations

import base64
import asyncio
import csv
from html import escape
import hashlib
import hmac
import io
import json
import os
import secrets
import sqlite3
import threading
import time
from contextlib import asynccontextmanager, contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Optional

from fastapi import Depends, FastAPI, File, Header, HTTPException, Query, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
ROOT = Path(__file__).resolve().parents[1]

try:
    from dotenv import load_dotenv
    load_dotenv(ROOT / ".env")
except ImportError:
    pass
DB_PATH = Path(os.getenv("ATTENDANCE_DB_PATH", str(ROOT / "data" / "attendance.sqlite3")))
TOKEN_TTL_SECONDS = int(os.getenv("ATTENDANCE_TOKEN_TTL_SECONDS", "28800"))
WS_TICKET_TTL_SECONDS = int(os.getenv("ATTENDANCE_WS_TICKET_TTL_SECONDS", "60"))
MAX_CAPTURE_BYTES = int(os.getenv("ATTENDANCE_MAX_CAPTURE_BYTES", "10485760"))
CORS_ORIGINS = [v.strip() for v in os.getenv("ATTENDANCE_CORS_ORIGINS", "http://localhost:3000,http://localhost:5173").split(",") if v.strip()]

INSECURE_SECRETS: set[str] = {
    "DEV_ONLY_CHANGE_ME_attendance_secret",
    "secret",
    "changeme",
    "password",
    "12345678",
}


def get_app_secret() -> str:
    env = os.getenv("ATTENDANCE_ENV", "").strip().lower()
    is_test = env in ("test", "testing") or "PYTEST_CURRENT_TEST" in os.environ
    secret = os.getenv("ATTENDANCE_APP_SECRET", "").strip()

    if is_test:
        return secret or "TEST_SECRET_DO_NOT_USE_IN_PROD_32_CHARS_MINIMUM!"

    if not secret:
        raise RuntimeError("ATTENDANCE_APP_SECRET is required outside test mode.")
    if secret in INSECURE_SECRETS or len(secret) < 32:
        raise RuntimeError(
            "ATTENDANCE_APP_SECRET is set to an insecure or weak value. "
            "Configure a strong secret of at least 32 characters outside test mode."
        )
    return secret


_db_lock = threading.RLock()
_ws_lock = threading.Lock()
_ws_tickets: dict[str, tuple[int, float]] = {}
_ws_clients: dict[int, set[WebSocket]] = {}
_ws_client_loops: dict[WebSocket, asyncio.AbstractEventLoop] = {}
_ws_client_queues: dict[WebSocket, asyncio.Queue[str]] = {}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _hash_password(password: str, salt: Optional[bytes] = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 180_000)
    return f"pbkdf2_sha256$180000${base64.urlsafe_b64encode(salt).decode()}${base64.urlsafe_b64encode(digest).decode()}"


def _verify_password(password: str, encoded: str) -> bool:
    try:
        scheme, rounds, salt_b64, digest_b64 = encoded.split("$", 3)
        if scheme != "pbkdf2_sha256":
            return False
        salt = base64.urlsafe_b64decode(salt_b64.encode())
        expected = base64.urlsafe_b64decode(digest_b64.encode())
        actual = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, int(rounds))
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def _sign_token(payload: dict[str, Any]) -> str:
    secret = get_app_secret()
    body = base64.urlsafe_b64encode(json.dumps(payload, separators=(",", ":")).encode()).decode().rstrip("=")
    sig = hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
    return f"{body}.{base64.urlsafe_b64encode(sig).decode().rstrip('=')}"


def _read_token(token: str) -> Optional[dict[str, Any]]:
    try:
        body, signature = token.split(".", 1)
        secret = get_app_secret()
        expected = hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
        actual = base64.urlsafe_b64decode(signature + "=" * (-len(signature) % 4))
        if not hmac.compare_digest(expected, actual):
            return None
        payload = json.loads(base64.urlsafe_b64decode(body + "=" * (-len(body) % 4)).decode())
        if int(payload.get("exp", 0)) < int(time.time()):
            return None
        return payload
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        return None


@contextmanager
def db() -> sqlite3.Connection:
    with _db_lock:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(str(DB_PATH), timeout=5.0, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA busy_timeout = 5000")
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


def init_db() -> None:
    with db() as conn:
        try:
            conn.execute("PRAGMA journal_mode = WAL")
            conn.execute("PRAGMA synchronous = NORMAL")
        except Exception:
            pass
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL CHECK(role IN ('teacher','student')),
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS classes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                code TEXT NOT NULL UNIQUE,
                teacher_id INTEGER NOT NULL REFERENCES users(id),
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS enrollments (
                class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
                student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                PRIMARY KEY(class_id, student_id)
            );
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                class_id INTEGER NOT NULL REFERENCES classes(id),
                status TEXT NOT NULL CHECK(status IN ('open','finalized')),
                created_by INTEGER NOT NULL REFERENCES users(id),
                created_at TEXT NOT NULL,
                finalized_at TEXT
            );
            CREATE TABLE IF NOT EXISTS attendance (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                student_id INTEGER NOT NULL REFERENCES users(id),
                status TEXT NOT NULL CHECK(status IN ('pending','present','absent')),
                note TEXT,
                updated_by INTEGER NOT NULL REFERENCES users(id),
                updated_at TEXT NOT NULL,
                UNIQUE(session_id, student_id)
            );
            CREATE TABLE IF NOT EXISTS checkin_attempts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                attempt_id TEXT NOT NULL UNIQUE,
                session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                student_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                state TEXT NOT NULL CHECK(state IN ('evaluating','verified','flagged','rejected','error')),
                error_code TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS suggestions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                student_id INTEGER NOT NULL REFERENCES users(id),
                confidence REAL NOT NULL,
                label TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS audit_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                action TEXT NOT NULL,
                actor_id INTEGER NOT NULL REFERENCES users(id),
                timestamp TEXT NOT NULL,
                note TEXT,
                metadata_json TEXT
            );
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                session_id INTEGER REFERENCES sessions(id) ON DELETE SET NULL,
                created_at TEXT NOT NULL,
                read_at TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
            CREATE INDEX IF NOT EXISTS idx_checkin_attempts_session ON checkin_attempts(session_id);
            CREATE INDEX IF NOT EXISTS idx_checkin_attempts_student ON checkin_attempts(student_id);
            CREATE INDEX IF NOT EXISTS idx_checkin_attempts_session_student ON checkin_attempts(session_id, student_id);
            CREATE INDEX IF NOT EXISTS idx_audit_session ON audit_log(session_id);
            CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at);
            """
        )
        if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] == 0:
            now = utc_now()
            users = [
                ("Demo Teacher", "teacher@demo.edu", _hash_password("teach123"), "teacher", now),
                ("Ari Student", "student1@demo.edu", _hash_password("student123"), "student", now),
                ("Bea Student", "student2@demo.edu", _hash_password("student123"), "student", now),
            ]
            conn.executemany("INSERT INTO users(name,email,password_hash,role,created_at) VALUES(?,?,?,?,?)", users)
            teacher = conn.execute("SELECT id FROM users WHERE email=?", ("teacher@demo.edu",)).fetchone()[0]
            students = [r[0] for r in conn.execute("SELECT id FROM users WHERE role='student' ORDER BY id").fetchall()]
            conn.execute("INSERT INTO classes(name,code,teacher_id,created_at) VALUES(?,?,?,?)", ("Foundations of Computing", "CS-101", teacher, now))
            class_id = conn.execute("SELECT id FROM classes WHERE code='CS-101'").fetchone()[0]
            conn.executemany("INSERT INTO enrollments(class_id,student_id) VALUES(?,?)", [(class_id, sid) for sid in students])


@asynccontextmanager
async def lifespan(_: FastAPI):
    get_app_secret()
    init_db()
    yield


app = FastAPI(title="Classroom Attendance Prototype API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=CORS_ORIGINS, allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


class LoginRequest(BaseModel):
    email: str
    password: str


class CreateSessionRequest(BaseModel):
    class_id: int


class AttendanceUpdate(BaseModel):
    status: str = Field(pattern="^(present|absent|pending)$")
    note: Optional[str] = Field(default=None, max_length=500)


class FinalizeRequest(BaseModel):
    mark_pending_absent: bool


def public_user(row: sqlite3.Row | dict[str, Any]) -> dict[str, Any]:
    return {"id": row["id"], "name": row["name"], "email": row["email"], "role": row["role"]}


def bearer_user(authorization: Optional[str]) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer access token required")
    payload = _read_token(authorization.split(" ", 1)[1].strip())
    if not payload or not payload.get("sub"):
        raise HTTPException(status_code=401, detail="Invalid or expired access token")
    with db() as conn:
        row = conn.execute("SELECT id,name,email,role FROM users WHERE id=?", (int(payload["sub"]),)).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="User no longer exists")
    return dict(row)


def current_user(authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    return bearer_user(authorization)


def require_teacher(user: dict[str, Any]) -> None:
    if user["role"] != "teacher":
        raise HTTPException(status_code=403, detail="Teacher role required")


def class_for_user(conn: sqlite3.Connection, class_id: int, user: dict[str, Any]) -> sqlite3.Row:
    row = conn.execute("SELECT * FROM classes WHERE id=?", (class_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Class not found")
    allowed = row["teacher_id"] == user["id"] or conn.execute("SELECT 1 FROM enrollments WHERE class_id=? AND student_id=?", (class_id, user["id"])).fetchone()
    if not allowed:
        raise HTTPException(status_code=403, detail="You do not have access to this class")
    return row


def session_for_user(conn: sqlite3.Connection, session_id: int, user: dict[str, Any], teacher_only: bool = False) -> sqlite3.Row:
    row = conn.execute("SELECT s.*, c.name AS class_name, c.code AS class_code, c.teacher_id FROM sessions s JOIN classes c ON c.id=s.class_id WHERE s.id=?", (session_id,)).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Session not found")
    if teacher_only or user["role"] == "teacher":
        if row["teacher_id"] != user["id"]:
            raise HTTPException(status_code=403, detail="You do not have access to this session")
    elif not conn.execute("SELECT 1 FROM enrollments WHERE class_id=? AND student_id=?", (row["class_id"], user["id"])).fetchone():
        raise HTTPException(status_code=403, detail="You do not have access to this session")
    return row


def _session_payload(conn: sqlite3.Connection, row: sqlite3.Row, user: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": row["id"], "class_id": row["class_id"], "class_name": row["class_name"], "class_code": row["class_code"],
        "status": row["status"], "created_at": row["created_at"], "finalized_at": row["finalized_at"],
    }
    if user["role"] == "teacher":
        entries = conn.execute(
            "SELECT a.student_id,a.status,a.note,a.updated_at,u.name,u.email FROM attendance a JOIN users u ON u.id=a.student_id WHERE a.session_id=? ORDER BY u.name",
            (row["id"],),
        ).fetchall()
        result["attendance"] = [dict(e) for e in entries]
        suggestions = conn.execute(
            "SELECT s.id,s.student_id,s.confidence,s.label,s.created_at,u.name FROM suggestions s JOIN users u ON u.id=s.student_id WHERE s.session_id=? ORDER BY s.id",
            (row["id"],),
        ).fetchall()
        result["suggestions"] = [dict(s) for s in suggestions]
    else:
        own = conn.execute("SELECT status,note,updated_at FROM attendance WHERE session_id=? AND student_id=?", (row["id"], user["id"])).fetchone()
        result["attendance"] = [dict(own)] if own else []
    return result


def audit(conn: sqlite3.Connection, session_id: int, actor_id: int, action: str, note: Optional[str] = None, metadata: Optional[dict[str, Any]] = None) -> None:
    conn.execute("INSERT INTO audit_log(session_id,action,actor_id,timestamp,note,metadata_json) VALUES(?,?,?,?,?,?)", (session_id, action, actor_id, utc_now(), note, json.dumps(metadata or {}, separators=(",", ":"))))


def event_payload(event_type: str, data: dict[str, Any]) -> dict[str, Any]:
    return {"type": event_type, "data": data, "created_at": utc_now()}


def publish_event(loopless_event: dict[str, Any], user_ids: list[int]) -> None:
    # Sync FastAPI routes run in worker threads. Enqueue on the socket's owning
    # event loop; the endpoint coroutine performs all WebSocket writes.
    event_payload_json = json.dumps(loopless_event)
    targets: list[tuple[asyncio.AbstractEventLoop, asyncio.Queue[str]]] = []
    with _ws_lock:
        for uid in user_ids:
            for ws in _ws_clients.get(uid, ()):
                loop = _ws_client_loops.get(ws)
                queue = _ws_client_queues.get(ws)
                if loop and loop.is_running() and queue is not None:
                    targets.append((loop, queue))
    for loop, queue in targets:
        try:
            loop.call_soon_threadsafe(queue.put_nowait, event_payload_json)
        except Exception:
            pass


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "classroom-attendance-prototype"}


@app.post("/api/auth/login")
def login(body: LoginRequest) -> dict[str, Any]:
    with db() as conn:
        row = conn.execute("SELECT * FROM users WHERE lower(email)=lower(?)", (body.email.strip(),)).fetchone()
    if not row or not _verify_password(body.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    now = int(time.time())
    token = _sign_token({"sub": row["id"], "role": row["role"], "iat": now, "exp": now + TOKEN_TTL_SECONDS})
    return {"access_token": token, "token_type": "bearer", "user": public_user(row)}


@app.get("/api/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return user


@app.post("/api/auth/ws-ticket")
def ws_ticket(user: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    ticket = secrets.token_urlsafe(32)
    now = time.time()
    with _ws_lock:
        expired = [k for k, v in _ws_tickets.items() if v[1] < now]
        for k in expired:
            _ws_tickets.pop(k, None)
        _ws_tickets[ticket] = (user["id"], now + WS_TICKET_TTL_SECONDS)
    return {"ticket": ticket}


@app.get("/api/classes")
def classes(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    with db() as conn:
        if user["role"] == "teacher":
            rows = conn.execute("SELECT c.*, (SELECT COUNT(*) FROM enrollments e WHERE e.class_id=c.id) AS student_count FROM classes c WHERE c.teacher_id=? ORDER BY c.name", (user["id"],)).fetchall()
        else:
            rows = conn.execute("SELECT c.*, (SELECT COUNT(*) FROM enrollments e WHERE e.class_id=c.id) AS student_count FROM classes c JOIN enrollments mine ON mine.class_id=c.id WHERE mine.student_id=? ORDER BY c.name", (user["id"],)).fetchall()
        return [dict(r) for r in rows]


@app.get("/api/classes/{class_id}/students")
def class_students(class_id: int, user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    require_teacher(user)
    with db() as conn:
        class_for_user(conn, class_id, user)
        rows = conn.execute("SELECT u.id,u.name,u.email,u.role FROM enrollments e JOIN users u ON u.id=e.student_id WHERE e.class_id=? ORDER BY u.name", (class_id,)).fetchall()
        return [dict(r) for r in rows]


@app.get("/api/sessions")
def sessions(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    with db() as conn:
        if user["role"] == "teacher":
            rows = conn.execute("SELECT s.id,s.class_id,c.name AS class_name,c.code AS class_code,s.status,s.created_at,s.finalized_at,(SELECT COUNT(*) FROM attendance a WHERE a.session_id=s.id AND a.status='present') AS present_count,(SELECT COUNT(*) FROM attendance a WHERE a.session_id=s.id AND a.status='absent') AS absent_count,(SELECT COUNT(*) FROM attendance a WHERE a.session_id=s.id AND a.status='pending') AS pending_count FROM sessions s JOIN classes c ON c.id=s.class_id WHERE c.teacher_id=? ORDER BY s.created_at DESC", (user["id"],)).fetchall()
        else:
            rows = conn.execute("SELECT s.id,s.class_id,c.name AS class_name,c.code AS class_code,s.status,s.created_at,s.finalized_at,a.status AS my_status,a.note AS my_note FROM sessions s JOIN classes c ON c.id=s.class_id JOIN enrollments e ON e.class_id=c.id AND e.student_id=? LEFT JOIN attendance a ON a.session_id=s.id AND a.student_id=? ORDER BY s.created_at DESC", (user["id"], user["id"])).fetchall()
        return [dict(r) for r in rows]


@app.post("/api/sessions")
def create_session(body: CreateSessionRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    with db() as conn:
        cls = class_for_user(conn, body.class_id, user)
        now = utc_now()
        cursor = conn.execute("INSERT INTO sessions(class_id,status,created_by,created_at) VALUES(?,?,?,?)", (body.class_id, "open", user["id"], now))
        session_id = cursor.lastrowid
        student_rows = conn.execute("SELECT student_id FROM enrollments WHERE class_id=?", (body.class_id,)).fetchall()
        conn.executemany("INSERT INTO attendance(session_id,student_id,status,updated_by,updated_at) VALUES(?,?,?,?,?)", [(session_id, r[0], "pending", user["id"], now) for r in student_rows])
        audit(conn, session_id, user["id"], "session.created", metadata={"class_id": body.class_id})
        row = conn.execute("SELECT s.*,c.name AS class_name,c.code AS class_code,c.teacher_id FROM sessions s JOIN classes c ON c.id=s.class_id WHERE s.id=?", (session_id,)).fetchone()
        payload = _session_payload(conn, row, user)
    recipients = [user["id"], *(student[0] for student in student_rows)]
    publish_event(event_payload("session.created", {"session_id": session_id, "class_id": body.class_id}), recipients)
    return payload


@app.get("/api/sessions/{session_id}")
def get_session(session_id: int, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    with db() as conn:
        row = session_for_user(conn, session_id, user)
        return _session_payload(conn, row, user)


@app.post("/api/sessions/{session_id}/capture")
async def capture(session_id: int, photo: UploadFile = File(...), user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    with db() as conn:
        row = session_for_user(conn, session_id, user, teacher_only=True)
        if row["status"] != "open":
            raise HTTPException(status_code=409, detail="Only open sessions accept captures")
        data = bytearray()
        while True:
            chunk = await photo.read(1024 * 1024)
            if not chunk:
                break
            data.extend(chunk)
            if len(data) > MAX_CAPTURE_BYTES:
                raise HTTPException(status_code=413, detail=f"Capture exceeds {MAX_CAPTURE_BYTES} bytes")
        if not data:
            raise HTTPException(status_code=400, detail="Capture photo is empty")
        roster = conn.execute("SELECT u.id,u.name FROM enrollments e JOIN users u ON u.id=e.student_id WHERE e.class_id=? ORDER BY u.name", (row["class_id"],)).fetchall()
        # Synthetic, deterministic suggestions: no pixels, raw photo, embedding, or biometric data is retained.
        capture_number = conn.execute("SELECT COUNT(*) FROM audit_log WHERE session_id=? AND action='capture.received'", (session_id,)).fetchone()[0] + 1
        now = utc_now()
        suggestions = []
        for index, student in enumerate(roster):
            confidence = round(min(0.98, 0.70 + ((len(data) + capture_number * 17 + index * 11) % 25) / 100), 2)
            conn.execute("INSERT INTO suggestions(session_id,student_id,confidence,label,created_at) VALUES(?,?,?,?,?)", (session_id, student["id"], confidence, "simulated", now))
            suggestions.append({"student_id": student["id"], "name": student["name"], "confidence": confidence, "status": "suggestion", "label": "simulated"})
        audit(conn, session_id, user["id"], "capture.received", note="Capture processed for synthetic suggestions; not persisted by application.", metadata={"bytes_read": len(data)})
        audit(conn, session_id, user["id"], "suggestion.generated", note="Synthetic suggestions; teacher review required.", metadata={"count": len(suggestions), "synthetic": True})
    return {"session_id": session_id, "simulated": True, "message": "Synthetic suggestions only. Review and save attendance manually; no image was stored.", "suggestions": suggestions}


@app.patch("/api/sessions/{session_id}/attendance/{student_id}")
def update_attendance(session_id: int, student_id: int, body: AttendanceUpdate, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    with db() as conn:
        row = session_for_user(conn, session_id, user, teacher_only=True)
        if row["status"] != "open":
            raise HTTPException(status_code=409, detail="Finalized sessions cannot be changed")
        enrolled = conn.execute("SELECT 1 FROM enrollments WHERE class_id=? AND student_id=?", (row["class_id"], student_id)).fetchone()
        if not enrolled:
            raise HTTPException(status_code=404, detail="Student is not enrolled in this class")
        now = utc_now()
        conn.execute("UPDATE attendance SET status=?,note=?,updated_by=?,updated_at=? WHERE session_id=? AND student_id=?", (body.status, body.note, user["id"], now, session_id, student_id))
        audit(conn, session_id, user["id"], "attendance.changed", note=body.note, metadata={"student_id": student_id, "status": body.status})
        changed = conn.execute("SELECT a.student_id,a.status,a.note,a.updated_at,u.name FROM attendance a JOIN users u ON u.id=a.student_id WHERE a.session_id=? AND a.student_id=?", (session_id, student_id)).fetchone()
    event = event_payload("attendance.changed", {"session_id": session_id, "student_id": student_id, "status": body.status})
    publish_event(event, [user["id"]])
    return dict(changed)


@app.post("/api/sessions/{session_id}/finalize")
def finalize(session_id: int, body: FinalizeRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    if body.mark_pending_absent is not True:
        raise HTTPException(status_code=400, detail="mark_pending_absent must be true for explicit finalization")
    with db() as conn:
        row = session_for_user(conn, session_id, user, teacher_only=True)
        if row["status"] != "open":
            raise HTTPException(status_code=409, detail="Session is already finalized")
        now = utc_now()
        pending = conn.execute("SELECT student_id FROM attendance WHERE session_id=? AND status='pending'", (session_id,)).fetchall()
        conn.execute("UPDATE attendance SET status='absent',updated_by=?,updated_at=? WHERE session_id=? AND status='pending'", (user["id"], now, session_id))
        for student in pending:
            audit(conn, session_id, user["id"], "attendance.changed", note="Pending attendance marked absent at finalization.", metadata={"student_id": student[0], "status": "absent", "finalization": True})
        conn.execute("UPDATE sessions SET status='finalized',finalized_at=? WHERE id=?", (now, session_id))
        audit(conn, session_id, user["id"], "session.finalized", note="Session finalized; pending records marked absent.", metadata={"pending_marked_absent": len(pending)})
        students = conn.execute("SELECT student_id FROM enrollments WHERE class_id=?", (row["class_id"],)).fetchall()
        for student in students:
            conn.execute("INSERT INTO notifications(user_id,type,title,body,session_id,created_at) VALUES(?,?,?,?,?,?)", (student[0], "attendance.finalized", "Attendance updated", "Your attendance record for a class session is available in the app.", session_id, now))
        summary = {"present": conn.execute("SELECT COUNT(*) FROM attendance WHERE session_id=? AND status='present'", (session_id,)).fetchone()[0], "absent": conn.execute("SELECT COUNT(*) FROM attendance WHERE session_id=? AND status='absent'", (session_id,)).fetchone()[0], "pending": 0}
        student_ids = [r[0] for r in students]
    event = event_payload("session.finalized", {"session_id": session_id, "summary": summary})
    publish_event(event, [user["id"], *student_ids])
    for sid in student_ids:
        publish_event(event_payload("notification.created", {"session_id": session_id}), [sid])
    return {"session_id": session_id, "status": "finalized", "finalized_at": now, "summary": summary}


@app.get("/api/students/me/attendance")
def my_attendance(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    if user["role"] != "student":
        raise HTTPException(status_code=403, detail="Student role required")
    with db() as conn:
        rows = conn.execute("SELECT a.session_id,a.status,a.note,a.updated_at,s.created_at,s.finalized_at,c.id AS class_id,c.name AS class_name,c.code AS class_code FROM attendance a JOIN sessions s ON s.id=a.session_id JOIN classes c ON c.id=s.class_id WHERE a.student_id=? ORDER BY s.created_at DESC", (user["id"],)).fetchall()
        entries = [dict(r) for r in rows]
        present = sum(1 for r in entries if r["status"] == "present")
        absent = sum(1 for r in entries if r["status"] == "absent")
        pending = sum(1 for r in entries if r["status"] == "pending")
        total = present + absent
        return {"student": user, "entries": entries, "summary": {"present": present, "absent": absent, "pending": pending, "total_finalized": total, "percentage": round((present / total) * 100, 1) if total else None}}


@app.get("/api/reports/sessions/{session_id}")
def report(session_id: int, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    with db() as conn:
        row = session_for_user(conn, session_id, user, teacher_only=True)
        entries = conn.execute("SELECT u.name,u.email,a.status,a.note,a.updated_at FROM attendance a JOIN users u ON u.id=a.student_id WHERE a.session_id=? ORDER BY u.name", (session_id,)).fetchall()
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["student_name", "student_email", "status", "note", "updated_at"])
        for e in entries:
            writer.writerow([e["name"], e["email"], e["status"], e["note"] or "", e["updated_at"]])
        csv_data = output.getvalue()
        pdf_html = (
            "<!doctype html><html><head><meta charset='utf-8'><title>Attendance report</title></head><body><h1>"
            + escape(str(row["class_name"]))
            + " attendance</h1><p>Session "
            + escape(str(session_id))
            + " · "
            + escape(str(row["created_at"]))
            + "</p><table><thead><tr><th>Student</th><th>Email</th><th>Status</th><th>Note</th></tr></thead><tbody>"
            + "".join(
                f"<tr><td>{escape(str(e['name']))}</td><td>{escape(str(e['email']))}</td><td>{escape(str(e['status']))}</td><td>{escape(str(e['note'] or ''))}</td></tr>"
                for e in entries
            )
            + "</tbody></table></body></html>"
        )
        return {"session": {"id": row["id"], "class_id": row["class_id"], "class_name": row["class_name"], "class_code": row["class_code"], "status": row["status"], "created_at": row["created_at"], "finalized_at": row["finalized_at"]}, "rows": [dict(e) for e in entries], "csv": csv_data, "pdf": pdf_html, "pdf_html": pdf_html, "pdf_note": "Print pdf_html from a trusted client to create a PDF; the API does not claim to be a PDF renderer."}


@app.get("/api/audit")
def get_audit(session_id: int = Query(...), user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    require_teacher(user)
    with db() as conn:
        session_for_user(conn, session_id, user, teacher_only=True)
        rows = conn.execute("SELECT a.id,a.session_id,a.action,a.timestamp,a.note,a.metadata_json,u.id AS actor_id,u.name AS actor_name FROM audit_log a JOIN users u ON u.id=a.actor_id WHERE a.session_id=? ORDER BY a.id", (session_id,)).fetchall()
        result = []
        for r in rows:
            item = dict(r)
            item["metadata"] = json.loads(item.pop("metadata_json") or "{}")
            result.append(item)
        return result


@app.get("/api/notifications")
def notifications(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    with db() as conn:
        rows = conn.execute("SELECT id,type,title,body,session_id,created_at,read_at FROM notifications WHERE user_id=? ORDER BY created_at DESC,id DESC", (user["id"],)).fetchall()
        return [dict(r) for r in rows]


@app.post("/api/notifications/{notification_id}/read")
def mark_notification_read(notification_id: int, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    with db() as conn:
        row = conn.execute("SELECT id FROM notifications WHERE id=? AND user_id=?", (notification_id, user["id"])).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Notification not found")
        read_at = utc_now()
        conn.execute("UPDATE notifications SET read_at=? WHERE id=?", (read_at, notification_id))
        return {"id": notification_id, "read_at": read_at}


@app.websocket("/ws")
@app.websocket("/api/ws")
async def websocket_endpoint(websocket: WebSocket, ticket: str = Query(...)):
    now = time.time()
    with _ws_lock:
        record = _ws_tickets.pop(ticket, None)
    if not record or record[1] < now:
        await websocket.close(code=1008, reason="Invalid or expired single-use ticket")
        return
    user_id = record[0]
    await websocket.accept()
    event_queue: asyncio.Queue[str] = asyncio.Queue()
    with _ws_lock:
        _ws_clients.setdefault(user_id, set()).add(websocket)
        _ws_client_loops[websocket] = asyncio.get_running_loop()
        _ws_client_queues[websocket] = event_queue
    receive_task: Optional[asyncio.Task[Any]] = None
    event_task: Optional[asyncio.Task[str]] = None
    try:
        await websocket.send_json(event_payload("connected", {"user_id": user_id}))
        receive_task = asyncio.create_task(websocket.receive())
        event_task = asyncio.create_task(event_queue.get())
        while True:
            done, _ = await asyncio.wait(
                {receive_task, event_task}, return_when=asyncio.FIRST_COMPLETED
            )
            if receive_task in done:
                try:
                    message = receive_task.result()
                except WebSocketDisconnect:
                    break
                if message.get("type") == "websocket.disconnect":
                    break
                receive_task = asyncio.create_task(websocket.receive())
            if event_task in done:
                try:
                    msg_text = event_task.result()
                    await websocket.send_text(msg_text)
                except (WebSocketDisconnect, RuntimeError):
                    break
                event_task = asyncio.create_task(event_queue.get())
    except WebSocketDisconnect:
        pass
    finally:
        for task in (receive_task, event_task):
            if task is not None and not task.done():
                task.cancel()
        if receive_task is not None or event_task is not None:
            await asyncio.gather(
                *(task for task in (receive_task, event_task) if task is not None),
                return_exceptions=True,
            )
        with _ws_lock:
            if user_id in _ws_clients:
                _ws_clients[user_id].discard(websocket)
                if not _ws_clients[user_id]:
                    _ws_clients.pop(user_id, None)
            _ws_client_loops.pop(websocket, None)
            _ws_client_queues.pop(websocket, None)


@app.exception_handler(sqlite3.IntegrityError)
async def integrity_error_handler(_, exc: sqlite3.IntegrityError):
    return JSONResponse(status_code=409, content={"detail": "Database constraint prevented this operation"})
