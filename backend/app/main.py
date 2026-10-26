"""Classroom attendance prototype API – Supabase edition.

Auth:  Supabase Auth (JWT verification via PyJWT + SUPABASE_JWT_SECRET).
DB:    Supabase PostgreSQL (via supabase-py service-role client).

Attendance is persisted only by this backend. Biometric decisions are made by
the configured verification pipeline; uncertain decisions remain reviewable.
"""
from __future__ import annotations

import asyncio
import base64
import csv
from collections import defaultdict, deque
import io
import json
import logging
import os
import secrets
import threading
import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from html import escape
from typing import Any, Optional

import jwt as pyjwt
from fastapi import (
    Depends,
    File,
    Form,
    FastAPI,
    Request,
    Header,
    HTTPException,
    Query,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from supabase import create_client, Client
from dotenv import load_dotenv
from pathlib import Path
from cryptography.fernet import Fernet, InvalidToken

from .verification_config import DEFAULTS
from .verification import RuleResult, inside_submission_window
from .verification_pipeline import analyze_sweep, decide, hash_distance

# ── Config ────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

SUPABASE_URL: str = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_ROLE_KEY: str = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
SUPABASE_JWT_SECRET: str = os.environ["SUPABASE_JWT_SECRET"]

WS_TICKET_TTL_SECONDS = int(os.getenv("ATTENDANCE_WS_TICKET_TTL_SECONDS", "60"))
MAX_SESSION_MINUTES = int(os.getenv("ATTENDANCE_MAX_SESSION_MINUTES", "60"))
SESSION_CLOSE_POLL_SECONDS = float(os.getenv("ATTENDANCE_SESSION_CLOSE_POLL_SECONDS", "1"))
CORS_ORIGINS = [
    v.strip()
    for v in os.getenv(
        "ATTENDANCE_CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5173,http://localhost:8081",
    ).split(",")
    if v.strip()
]

# ── Supabase clients ──────────────────────────────────────────────────────────
_supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
_auth_client: Client = create_client(SUPABASE_URL, os.getenv("SUPABASE_ANON_KEY", SUPABASE_SERVICE_ROLE_KEY))


def supa() -> Client:
    """Return the shared Supabase service-role client."""
    _supabase.postgrest.auth(SUPABASE_SERVICE_ROLE_KEY)
    return _supabase


def auth_client() -> Client:
    """Return the client dedicated to user authentication."""
    return _auth_client


# ── WebSocket state ───────────────────────────────────────────────────────────
_ws_lock = threading.Lock()
_ws_tickets: dict[str, tuple[str, float]] = {}
_ws_clients: dict[str, set[WebSocket]] = {}
_ws_client_loops: dict[WebSocket, asyncio.AbstractEventLoop] = {}
_ws_client_queues: dict[WebSocket, asyncio.Queue[str]] = {}
_login_attempts: dict[str, deque[float]] = defaultdict(deque)
_login_rate_lock = threading.Lock()
_submit_attempts: dict[str, deque[float]] = defaultdict(deque)
_submit_rate_lock = threading.Lock()
logger = logging.getLogger("attendance.api")
LOGIN_RATE_LIMIT = int(os.getenv("ATTENDANCE_LOGIN_RATE_LIMIT", "10"))
LOGIN_RATE_WINDOW_SECONDS = int(os.getenv("ATTENDANCE_LOGIN_RATE_WINDOW_SECONDS", "60"))
SUBMIT_RATE_LIMIT = int(os.getenv("ATTENDANCE_SUBMIT_RATE_LIMIT", "10"))
SUBMIT_RATE_WINDOW_SECONDS = int(os.getenv("ATTENDANCE_SUBMIT_RATE_WINDOW_SECONDS", "60"))


# ── Helpers ───────────────────────────────────────────────────────────────────
def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _verify_supabase_jwt(token: str) -> dict[str, Any]:
    """Decode and verify a Supabase-issued JWT."""
    try:
        payload = pyjwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        return payload
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired access token") from exc


def current_user(authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer access token required")
    token = authorization.split(" ", 1)[1].strip()
    uid: str = ""
    try:
        user_resp = supa().auth.get_user(token)
        if user_resp and user_resp.user:
            uid = user_resp.user.id
    except Exception as exc:
        raise HTTPException(status_code=401, detail="Invalid or expired access token") from exc

    if not uid:
        raise HTTPException(status_code=401, detail="Invalid token: missing subject")

    resp = supa().table("profiles").select("*").eq("id", uid).single().execute()
    if not resp.data:
        raise HTTPException(status_code=401, detail="User profile not found")
    return resp.data


def require_teacher(user: dict[str, Any]) -> None:
    if user.get("role") != "teacher":
        raise HTTPException(status_code=403, detail="Teacher role required")


def enforce_submit_rate(user_id: str) -> None:
    now_tick = time.monotonic()
    with _submit_rate_lock:
        attempts = _submit_attempts[user_id]
        while attempts and now_tick - attempts[0] >= SUBMIT_RATE_WINDOW_SECONDS:
            attempts.popleft()
        if len(attempts) >= SUBMIT_RATE_LIMIT:
            raise HTTPException(status_code=429, detail="Too many attendance attempts. Try again shortly.")
        attempts.append(now_tick)


# ── Pydantic schemas ──────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    email: str
    password: str
    selected_role: str = Field(pattern="^(student|teacher)$")


class CreateSessionRequest(BaseModel):
    class_id: str  # UUID
    duration_minutes: int = Field(default=10, ge=1, le=240)


class AttendanceUpdate(BaseModel):
    status: str = Field(pattern="^(present|absent|pending)$")
    note: Optional[str] = Field(default=None, max_length=500)


class FinalizeRequest(BaseModel):
    mark_pending_absent: bool


class SubmissionReview(BaseModel):
    decision: str = Field(pattern="^(accepted|rejected)$")
    note: str = Field(min_length=1, max_length=500)


# ── Lifespan ──────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(_: FastAPI):
    # Verify Supabase connectivity on startup
    try:
        supa().table("profiles").select("id").limit(1).execute()
    except Exception as exc:
        raise RuntimeError(f"Cannot connect to Supabase: {exc}") from exc
    stop = asyncio.Event()
    closer = asyncio.create_task(_session_closer(stop))
    retention = asyncio.create_task(_evidence_retention_worker(stop))
    try:
        yield
    finally:
        stop.set()
        closer.cancel()
        retention.cancel()
        await asyncio.gather(closer, retention, return_exceptions=True)


async def _session_closer(stop: asyncio.Event) -> None:
    while not stop.is_set():
        try:
            close_expired_sessions()
        except Exception:
            logger.error("Background session-close tick failed; it will retry.")
        try:
            await asyncio.wait_for(stop.wait(), timeout=SESSION_CLOSE_POLL_SECONDS)
        except asyncio.TimeoutError:
            continue


async def _evidence_retention_worker(stop: asyncio.Event) -> None:
    while not stop.is_set():
        try:
            delete_expired_flagged_evidence()
        except Exception:
            logger.error("Flagged evidence retention tick failed; it will retry.")
        try:
            await asyncio.wait_for(stop.wait(), timeout=3600)
        except asyncio.TimeoutError:
            continue


def delete_expired_flagged_evidence(now: Optional[datetime] = None) -> int:
    retention_days = max(1, int(os.getenv("ATTENDANCE_FLAGGED_RETENTION_DAYS", str(DEFAULTS.flagged_evidence_retention_days))))
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(days=retention_days)
    expired = (supa().table("submission_evidence").select("id, attempt_id, storage_path")
               .lte("created_at", cutoff.isoformat()).limit(1000).execute().data or [])
    if not expired:
        return 0
    bucket = supa().storage.from_(os.getenv("ATTENDANCE_EVIDENCE_BUCKET", "attendance-evidence"))
    for evidence in expired:
        bucket.remove([evidence["storage_path"]])
        supa().table("submission_evidence").delete().eq("id", evidence["id"]).execute()
    return len(expired)


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Classroom Attendance Prototype API",
    version="0.2.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Utility: session/class access guards ─────────────────────────────────────
def _get_class_or_404(class_id: str) -> dict[str, Any]:
    resp = supa().table("classes").select("*").eq("id", class_id).single().execute()
    if not resp.data:
        raise HTTPException(status_code=404, detail="Class not found")
    return resp.data


def _assert_class_access(cls: dict[str, Any], user: dict[str, Any]) -> None:
    if cls["teacher_id"] == user["id"]:
        return
    enr = (
        supa()
        .table("enrollments")
        .select("class_id")
        .eq("class_id", cls["id"])
        .eq("student_id", user["id"])
        .execute()
    )
    if not enr.data:
        raise HTTPException(status_code=403, detail="You do not have access to this class")


def _get_session_or_404(session_id: str) -> dict[str, Any]:
    close_expired_sessions()
    resp = (
        supa()
        .table("sessions")
        .select("*, classes(name, code, teacher_id)")
        .eq("id", session_id)
        .single()
        .execute()
    )
    if not resp.data:
        raise HTTPException(status_code=404, detail="Session not found")
    row = resp.data
    # Flatten nested classes join
    if isinstance(row.get("classes"), dict):
        row["class_name"] = row["classes"]["name"]
        row["class_code"] = row["classes"]["code"]
        row["teacher_id"] = row["classes"]["teacher_id"]
    return row


def _assert_session_access(
    row: dict[str, Any], user: dict[str, Any], teacher_only: bool = False
) -> None:
    if teacher_only or user["role"] == "teacher":
        if row.get("teacher_id") != user["id"]:
            raise HTTPException(status_code=403, detail="You do not have access to this session")
    else:
        enr = (
            supa()
            .table("enrollments")
            .select("class_id")
            .eq("class_id", row["class_id"])
            .eq("student_id", user["id"])
            .execute()
        )
        if not enr.data:
            raise HTTPException(status_code=403, detail="You do not have access to this session")


def _session_payload(row: dict[str, Any], user: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": row["id"],
        "class_id": row["class_id"],
        "class_name": row.get("class_name", ""),
        "class_code": row.get("class_code", ""),
        "status": row["status"],
        "created_at": row["created_at"],
        "starts_at": row.get("starts_at"),
        "ends_at": row.get("ends_at"),
        "duration_minutes": row.get("duration_minutes"),
        "server_time": utc_now(),
        "closed_at": row.get("closed_at"),
        "finalized_at": row.get("finalized_at"),
    }
    if user["role"] == "teacher":
        att = (
            supa()
            .table("attendance")
            .select("*, profiles!attendance_student_id_fkey(name, email)")
            .eq("session_id", row["id"])
            .order("profiles!attendance_student_id_fkey(name)")
            .execute()
        )
        entries = []
        for e in att.data or []:
            flat = {**e}
            prof = e.get("profiles!attendance_student_id_fkey") or e.get("profiles")
            if isinstance(prof, dict):
                flat["name"] = prof["name"]
                flat["email"] = prof["email"]
                flat.pop("profiles", None)
            entries.append(flat)
        result["attendance"] = entries

    else:
        own = (
            supa()
            .table("attendance")
            .select("status, note, updated_at")
            .eq("session_id", row["id"])
            .eq("student_id", user["id"])
            .execute()
        )
        result["attendance"] = own.data or []
    return result


_face_engine: Any = None
_face_engine_lock = threading.Lock()


def face_engine() -> Any:
    global _face_engine
    if _face_engine is None:
        with _face_engine_lock:
            if _face_engine is None:
                try:
                    from .face_engine import YuNetArcFaceEngine
                    _face_engine = YuNetArcFaceEngine()
                except Exception as exc:
                    raise HTTPException(status_code=503, detail="Face verification models are unavailable") from exc
    return _face_engine


def _template_cipher() -> Fernet:
    key = os.getenv("ATTENDANCE_TEMPLATE_ENCRYPTION_KEY", "")
    if not key or key == "replace-with-a-generated-Fernet-key":
        raise HTTPException(status_code=503, detail="Biometric encryption is not configured")
    try:
        return Fernet(key.encode("ascii"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Biometric encryption configuration is invalid") from exc


async def _read_image_upload(photo: UploadFile, max_bytes: int = DEFAULTS.maximum_upload_bytes) -> bytes:
    if photo.content_type not in ("image/jpeg", "image/png"):
        raise HTTPException(status_code=415, detail="Use a JPEG or PNG camera image")
    data = await photo.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise HTTPException(status_code=413, detail="Image exceeds the upload limit")
    if not (data.startswith(b"\xff\xd8\xff") or data.startswith(b"\x89PNG\r\n\x1a\n")):
        raise HTTPException(status_code=415, detail="Upload content is not a valid JPEG or PNG image")
    return data


def _audit(
    session_id: str,
    actor_id: str,
    action: str,
    note: Optional[str] = None,
    metadata: Optional[dict[str, Any]] = None,
) -> None:
    supa().table("audit_log").insert(
        {
            "session_id": session_id,
            "action": action,
            "actor_id": actor_id,
            "timestamp": utc_now(),
            "note": note,
            "metadata_json": json.dumps(metadata or {}, separators=(",", ":")),
        }
    ).execute()


def close_expired_sessions(now: Optional[str] = None) -> list[str]:
    """Atomically transition due open sessions once, then audit and notify."""
    now = now or utc_now()
    due = (supa().table("sessions").select("id, class_id, created_by, ends_at")
           .eq("status", "open").lte("ends_at", now).execute().data or [])
    closed_ids: list[str] = []
    for candidate in due:
        transition = (supa().table("sessions").update({"status": "closed", "closed_at": now})
                      .eq("id", candidate["id"]).eq("status", "open")
                      .lte("ends_at", now).select("id").execute())
        # PostgREST returns changed rows; only the winning transition emits effects.
        if not transition.data:
            continue
        session_id = candidate["id"]
        attendance = (supa().table("attendance").select("status")
                      .eq("session_id", session_id).execute().data or [])
        attempts = (supa().table("checkin_attempts").select("state")
                    .eq("session_id", session_id).execute().data or [])
        enrolled = (supa().table("enrollments").select("student_id")
                    .eq("class_id", candidate["class_id"]).execute().data or [])
        counts = {
            "present": sum(item.get("status") == "present" for item in attendance),
            "needs_review": sum(item.get("status") == "pending" for item in attendance),
            "absent": sum(item.get("status") == "absent" for item in attendance),
            "rejected_attempts": sum(item.get("state") == "rejected" for item in attempts),
            "total_enrolled": len(enrolled),
        }
        _audit(session_id, candidate["created_by"], "session.closed", metadata=counts)
        supa().table("notifications").insert({
            "user_id": candidate["created_by"],
            "type": "session.closed",
            "title": "Attendance window closed",
            "body": f"{counts['present']} present · {counts['needs_review']} need review · {counts['absent']} absent.",
            "session_id": session_id,
            "created_at": now,
        }).execute()
        student_ids = [entry["student_id"] for entry in enrolled]
        publish_event(event_payload("session.closed", {"session_id": session_id, **counts}),
                      [candidate["created_by"], *student_ids])
        closed_ids.append(session_id)
    return closed_ids


def event_payload(event_type: str, data: dict[str, Any]) -> dict[str, Any]:
    return {"type": event_type, "data": data, "created_at": utc_now()}


def publish_event(loopless_event: dict[str, Any], user_ids: list[str]) -> None:
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


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "classroom-attendance-prototype"}


@app.get("/api/config")
def public_config() -> dict[str, Any]:
    return {"session_duration_presets": [5, 10, 15], "max_session_minutes": MAX_SESSION_MINUTES,
            "server_time": utc_now()}


@app.post("/api/auth/login")
def login(req: LoginRequest, request: Request) -> dict[str, Any]:
    client_ip = request.client.host if request.client else "unknown"
    now_tick = time.monotonic()
    with _login_rate_lock:
        attempts = _login_attempts[client_ip]
        while attempts and now_tick - attempts[0] >= LOGIN_RATE_WINDOW_SECONDS:
            attempts.popleft()
        if len(attempts) >= LOGIN_RATE_LIMIT:
            raise HTTPException(status_code=429, detail="Too many sign-in attempts. Try again shortly.")
        attempts.append(now_tick)
    email = req.email.strip().lower()
    try:
        auth_resp = supa().auth.sign_in_with_password({
            "email": email,
            "password": req.password,
        })
        user_id = auth_resp.user.id
        access_token = auth_resp.session.access_token

        prof = supa().table("profiles").select("*").eq("id", user_id).single().execute()
        user_data = prof.data
        if not user_data:
            raise HTTPException(status_code=403, detail="User profile is not provisioned")
        if user_data.get("role") != req.selected_role:
            raise HTTPException(status_code=403, detail="Selected role does not match this account")
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user": user_data,
        }
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid email or password")


@app.get("/api/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {"id": user["id"], "name": user["name"], "email": user["email"], "role": user["role"]}


@app.get("/api/enrollment/status")
def enrollment_status(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    row = (supa().table("face_templates").select("model_version, consent_at")
           .eq("student_id", user["id"]).maybe_single().execute().data)
    return {"enrolled": bool(row), "model_version": row.get("model_version") if row else None,
            "consent_at": row.get("consent_at") if row else None}


@app.post("/api/enrollment/face")
async def enroll_face(
    consent: bool = Form(...),
    photo: UploadFile = File(...),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if user.get("role") not in ("student", "teacher"):
        raise HTTPException(status_code=403, detail="Account role cannot enroll")
    if consent is not True:
        raise HTTPException(status_code=400, detail="Explicit biometric consent is required")
    raw = await _read_image_upload(photo)
    engine = face_engine()
    analysis = engine.analyze(raw)
    if len(analysis["faces"]) != 1:
        raise HTTPException(status_code=422, detail="Retake with exactly one face visible")
    if (analysis["width"] < DEFAULTS.minimum_width or analysis["height"] < DEFAULTS.minimum_height
            or analysis["laplacian_variance"] < DEFAULTS.minimum_laplacian_variance
            or not DEFAULTS.minimum_brightness <= analysis["brightness"] <= DEFAULTS.maximum_brightness):
        raise HTTPException(status_code=422, detail="Image quality is too low; retake in brighter, sharper light")
    now = utc_now()
    embedding_ciphertext = _template_cipher().encrypt(
        json.dumps(analysis["faces"][0]["embedding"], separators=(",", ":")).encode("utf-8")
    ).decode("ascii")
    supa().table("face_templates").upsert({
        "student_id": user["id"],
        "encrypted_embedding": embedding_ciphertext,
        "model_version": engine.model_version,
        "consent_at": now,
        "updated_at": now,
    }, on_conflict="student_id").execute()
    return {"enrolled": True, "model_version": engine.model_version, "consent_at": now}


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
    if user["role"] == "teacher":
        resp = supa().table("classes").select("*").eq("teacher_id", user["id"]).order("name").execute()
    else:
        enr = supa().table("enrollments").select("class_id").eq("student_id", user["id"]).execute()
        class_ids = [e["class_id"] for e in (enr.data or [])]
        if not class_ids:
            return []
        resp = supa().table("classes").select("*").in_("id", class_ids).order("name").execute()
    return resp.data or []


@app.get("/api/classes/{class_id}/students")
def class_students(class_id: str, user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    require_teacher(user)
    cls = _get_class_or_404(class_id)
    _assert_class_access(cls, user)
    resp = (
        supa()
        .table("enrollments")
        .select("profiles(id, name, email, role)")
        .eq("class_id", class_id)
        .execute()
    )
    return [e["profiles"] for e in (resp.data or []) if e.get("profiles")]


@app.get("/api/sessions")
def sessions(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    close_expired_sessions()
    if user["role"] == "teacher":
        resp = (
            supa()
            .table("sessions")
            .select("*, classes(name, code, teacher_id)")
            .eq("classes.teacher_id", user["id"])
            .order("created_at", desc=True)
            .execute()
        )
    else:
        enr = supa().table("enrollments").select("class_id").eq("student_id", user["id"]).execute()
        class_ids = [e["class_id"] for e in (enr.data or [])]
        if not class_ids:
            return []
        resp = (
            supa()
            .table("sessions")
            .select("*, classes(name, code), attendance(status, note)")
            .in_("class_id", class_ids)
            .order("created_at", desc=True)
            .execute()
        )
    rows = []
    for r in resp.data or []:
        flat = {**r}
        flat["server_time"] = utc_now()
        if isinstance(r.get("classes"), dict):
            flat["class_name"] = r["classes"]["name"]
            flat["class_code"] = r["classes"]["code"]
            flat.pop("classes", None)
        rows.append(flat)
    return rows


@app.post("/api/sessions")
def create_session(
    body: CreateSessionRequest, user: dict[str, Any] = Depends(current_user)
) -> dict[str, Any]:
    require_teacher(user)
    if body.duration_minutes > MAX_SESSION_MINUTES:
        raise HTTPException(status_code=422, detail=f"Duration cannot exceed {MAX_SESSION_MINUTES} minutes")
    cls = _get_class_or_404(body.class_id)
    _assert_class_access(cls, user)
    now_dt = datetime.now(timezone.utc)
    now = now_dt.isoformat(timespec="seconds")
    ends_at = (now_dt + timedelta(minutes=body.duration_minutes)).isoformat(timespec="seconds")
    sess_resp = (
        supa()
        .table("sessions")
        .insert(
            {
                "class_id": body.class_id,
                "status": "open",
                "created_by": user["id"],
                "created_at": now,
                "starts_at": now,
                "ends_at": ends_at,
                "duration_minutes": body.duration_minutes,
            }
        )
        .execute()
    )
    session_id: str = sess_resp.data[0]["id"]

    # Seed attendance rows for all enrolled students
    students = (
        supa().table("enrollments").select("student_id").eq("class_id", body.class_id).execute()
    )
    att_rows = [
        {
            "session_id": session_id,
            "student_id": s["student_id"],
            "status": "pending",
            "updated_by": user["id"],
            "updated_at": now,
        }
        for s in (students.data or [])
    ]
    if att_rows:
        supa().table("attendance").insert(att_rows).execute()

    _audit(session_id, user["id"], "session.created", metadata={"class_id": body.class_id})
    row = _get_session_or_404(session_id)
    payload = _session_payload(row, user)

    student_ids = [s["student_id"] for s in (students.data or [])]
    publish_event(
        event_payload("session.created", {"session_id": session_id, "class_id": body.class_id}),
        [user["id"], *student_ids],
    )
    return payload


@app.get("/api/sessions/{session_id}")
def get_session(session_id: str, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user)
    return _session_payload(row, user)


@app.post("/api/sessions/{session_id}/capture")
def capture(user: dict[str, Any] = Depends(current_user)) -> None:
    """The former synthetic photo flow is retired; use manual roll call."""
    require_teacher(user)
    raise HTTPException(
        status_code=410,
        detail="Photo suggestions are retired. Use the audited manual attendance controls.",
    )


def _decode_template(student_id: str) -> tuple[list[float], str]:
    row = (supa().table("face_templates").select("encrypted_embedding, model_version")
           .eq("student_id", student_id).maybe_single().execute().data)
    if not row:
        raise HTTPException(status_code=409, detail="Face enrollment and consent are required before submitting")
    try:
        clear = _template_cipher().decrypt(row["encrypted_embedding"].encode("ascii"))
        return json.loads(clear), row["model_version"]
    except (InvalidToken, ValueError, KeyError, UnicodeError) as exc:
        raise HTTPException(status_code=503, detail="Stored face enrollment cannot be read") from exc


def _persist_attempt(attempt_id: str, status: str, reason_code: str,
                     rules: dict[str, RuleResult], metrics: dict[str, Any], model_version: str) -> None:
    from dataclasses import asdict
    supa().table("checkin_attempts").update({
        "state": status,
        "reason_code": reason_code,
        "error_code": reason_code if status == "rejected" else None,
        "rules_json": {name: asdict(result) for name, result in rules.items()},
        "metrics_json": metrics,
        "model_version": model_version,
        "updated_at": utc_now(),
    }).eq("attempt_id", attempt_id).execute()


@app.post("/api/sessions/{session_id}/submissions")
async def submit_sweep(
    session_id: str,
    attempt_id: str = Form(..., min_length=8, max_length=128),
    duration_seconds: float = Form(...),
    frame_metadata: str = Form(...),
    frames: list[UploadFile] = File(...),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student role required")
    enforce_submit_rate(user["id"])
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user)
    if row["status"] == "finalized":
        raise HTTPException(status_code=409, detail="Session is finalized")
    try:
        ends_at = datetime.fromisoformat(row["ends_at"].replace("Z", "+00:00"))
    except (KeyError, ValueError, AttributeError) as exc:
        raise HTTPException(status_code=503, detail="Session timing is not configured") from exc
    received_at = datetime.now(timezone.utc)
    if not inside_submission_window(row["status"], ends_at, received_at):
        raise HTTPException(status_code=410, detail="Attendance window has ended")

    try:
        metadata = json.loads(frame_metadata)
    except (TypeError, json.JSONDecodeError) as exc:
        raise HTTPException(status_code=422, detail="Frame metadata must be valid JSON") from exc
    if not isinstance(metadata, list) or len(metadata) != len(frames):
        raise HTTPException(status_code=422, detail="Provide one heading and time offset for every frame")
    for item in metadata:
        if (not isinstance(item, dict) or "offset_seconds" not in item or "heading_degrees" not in item):
            raise HTTPException(status_code=422, detail="Each frame needs offset_seconds and heading_degrees")
        try:
            offset, heading = float(item["offset_seconds"]), float(item["heading_degrees"])
        except (TypeError, ValueError) as exc:
            raise HTTPException(status_code=422, detail="Frame offsets and headings must be numeric") from exc
        if not (0 <= offset <= 30 and 0 <= heading <= 360):
            raise HTTPException(status_code=422, detail="Frame offsets or headings are outside accepted bounds")

    engine = face_engine()
    student_embedding, student_model = _decode_template(user["id"])
    lecturer_embedding, lecturer_model = _decode_template(row["teacher_id"])
    model_version = engine.model_version
    if student_model != model_version or lecturer_model != model_version:
        raise HTTPException(status_code=409, detail="Enrollment model version differs from the active verifier; re-enroll")

    # Postgres serializes concurrent submissions for this student/session.
    try:
        started = supa().rpc("begin_checkin_attempt", {
            "p_attempt_id": attempt_id,
            "p_session_id": session_id,
            "p_student_id": user["id"],
            "p_max_attempts": DEFAULTS.maximum_attempts_per_student,
        }).execute().data
    except Exception as exc:
        message = str(exc).lower()
        if "attempt_limit_reached" in message:
            raise HTTPException(status_code=429, detail="You have used all attendance attempts for this session") from exc
        if "attempt_in_progress" in message:
            raise HTTPException(status_code=409, detail="This attendance attempt is still being processed") from exc
        if "attempt_id_conflict" in message or "duplicate key" in message:
            previous = (supa().table("checkin_attempts").select("session_id, student_id, state, reason_code")
                        .eq("attempt_id", attempt_id).maybe_single().execute().data)
            if previous and previous.get("session_id") == session_id and previous.get("student_id") == user["id"]:
                return {"attempt_id": attempt_id, "status": previous["state"], "reason_code": previous.get("reason_code")}
            raise HTTPException(status_code=409, detail="attempt_id is already in use") from exc
        if "session_finalized" in message:
            raise HTTPException(status_code=409, detail="Session is finalized") from exc
        raise HTTPException(status_code=503, detail="Could not safely begin the attendance attempt") from exc
    if isinstance(started, list):
        started = started[0] if started else None
    if started and started.get("state") != "evaluating":
        return {"attempt_id": attempt_id, "status": started.get("state"), "reason_code": started.get("reason_code")}

    total_bytes = 0
    raw_frames: list[bytes] = []
    mime_types: list[str] = []
    validation_error: tuple[int, str, str] | None = None
    for frame in frames:
        mime_types.append(frame.content_type or "")
        if frame.content_type not in ("image/jpeg", "image/png"):
            validation_error = (415, "reject.unsupported_image_type", "Every frame must be JPEG or PNG")
            break
        data = await frame.read(DEFAULTS.maximum_upload_bytes + 1)
        total_bytes += len(data)
        if total_bytes > DEFAULTS.maximum_upload_bytes:
            validation_error = (413, "reject.upload_too_large", "The complete sweep exceeds the upload limit")
            break
        if not (data.startswith(b"\xff\xd8\xff") or data.startswith(b"\x89PNG\r\n\x1a\n")):
            validation_error = (415, "reject.invalid_image", "A frame is not a valid JPEG or PNG image")
            break
        raw_frames.append(data)

    rules: dict[str, RuleResult] = {
        "jwt": RuleResult(True, "ok", "Supabase Auth verified the bearer token."),
        "role": RuleResult(True, "ok", "Account role is student."),
        "class_enrollment": RuleResult(True, "ok", "Student is enrolled in the session class."),
        "session_window": RuleResult(True, "ok", "Server received the attempt inside the session grace window."),
        "idempotency": RuleResult(True, "ok", "Unique attempt_id reserved by Postgres."),
        "attempt_limit": RuleResult(True, "ok", "Attempt count is below the configured limit."),
    }
    metrics: dict[str, Any] = {"bytes_received": total_bytes}
    if validation_error:
        _, reason, detail = validation_error
        rules["limits"] = RuleResult(False, reason, detail)
        decision = decide(rules)
        _persist_attempt(attempt_id, decision["status"], decision["reason_code"], rules, metrics, model_version)
        return {"attempt_id": attempt_id, **decision}
    if len(frames) < DEFAULTS.minimum_frames:
        rules["frame_count"] = RuleResult(False, "reject.too_few_frames", f"At least {DEFAULTS.minimum_frames} frames are required.")
        decision = decide(rules)
        _persist_attempt(attempt_id, decision["status"], decision["reason_code"], rules, metrics, model_version)
        return {"attempt_id": attempt_id, **decision}
    if len(frames) > DEFAULTS.maximum_frames:
        rules["limits"] = RuleResult(False, "reject.too_many_frames", "Frame count exceeds the configured maximum.")
        decision = decide(rules)
        _persist_attempt(attempt_id, decision["status"], decision["reason_code"], rules, metrics, model_version)
        return {"attempt_id": attempt_id, **decision}
    facts = analyze_sweep(metadata, raw_frames, duration_seconds, student_embedding, lecturer_embedding, engine)
    rules.update(facts["rules"])

    # Perceptual hashes are a low-cost duplicate signal, never an identity check.
    earlier = (supa().table("checkin_attempts").select("student_id, session_id, metrics_json")
               .in_("state", ["verified", "flagged"]).neq("attempt_id", attempt_id)
               .limit(2000).execute().data or [])
    new_hashes = facts["perceptual_hashes"]
    duplicate = any(
        (prior.get("student_id") != user["id"] or prior.get("session_id") != session_id) and
        any(hash_distance(current, previous) <= 5 for current in new_hashes
            for previous in (prior.get("metrics_json") or {}).get("perceptual_hashes", []))
        for prior in earlier
    )
    rules["duplicate_signal"] = RuleResult(
        None if duplicate else True,
        "review.perceptual_hash_near_duplicate" if duplicate else "ok",
        "Near-duplicate image hashes are review signals only.",
    )
    decision = decide(rules)
    metrics.update(facts["metrics"])
    metrics["perceptual_hashes"] = new_hashes
    if decision["status"] == "verified":
        try:
            _persist_attempt(attempt_id, "verified", decision["reason_code"], rules, metrics, model_version)
        except Exception as exc:
            if "uq_one_verified_checkin_per_student_session" not in str(exc):
                raise
            rules["idempotency"] = RuleResult(False, "reject.already_verified", "A verified check-in already exists for this session.")
            decision = decide(rules)
            _persist_attempt(attempt_id, "rejected", decision["reason_code"], rules, metrics, model_version)
        if decision["status"] == "verified":
            supa().table("attendance").update({
                "status": "present", "updated_by": user["id"], "updated_at": utc_now(), "note": "Verified sweep attempt",
            }).eq("session_id", session_id).eq("student_id", user["id"]).execute()
            _audit(session_id, user["id"], "attendance.verified", metadata={"attempt_id": attempt_id, "reason_code": decision["reason_code"]})
    elif decision["status"] == "flagged":
        evidence_rows = []
        bucket = os.getenv("ATTENDANCE_EVIDENCE_BUCKET", "attendance-evidence")
        for index in facts["key_frame_indices"]:
            extension = "jpg" if mime_types[index] == "image/jpeg" else "png"
            storage_path = f"{session_id}/{attempt_id}/{index}.{extension}"
            supa().storage.from_(bucket).upload(storage_path, raw_frames[index], {
                "content-type": mime_types[index], "upsert": "true",
            })
            evidence_rows.append({"attempt_id": attempt_id, "storage_path": storage_path,
                                  "frame_offset_ms": int(float(metadata[index]["offset_seconds"]) * 1000),
                                  "heading_degrees": float(metadata[index]["heading_degrees"])})
        if evidence_rows:
            supa().table("submission_evidence").insert(evidence_rows).execute()
        _persist_attempt(attempt_id, decision["status"], decision["reason_code"], rules, metrics, model_version)
        supa().table("notifications").insert({
            "user_id": row["teacher_id"], "type": "attendance.review",
            "title": "Attendance needs review", "body": "A student sweep was flagged for lecturer review.",
            "session_id": session_id, "created_at": utc_now(),
        }).execute()
    else:
        _persist_attempt(attempt_id, decision["status"], decision["reason_code"], rules, metrics, model_version)
    _audit(session_id, user["id"], f"checkin.{decision['status']}", metadata={"attempt_id": attempt_id, "reason_code": decision["reason_code"]})
    publish_event(event_payload("attendance.attempt", {"session_id": session_id, "attempt_id": attempt_id,
                  "status": decision["status"], "reason_code": decision["reason_code"]}), [row["teacher_id"], user["id"]])
    return {"attempt_id": attempt_id, **decision}


@app.get("/api/sessions/{session_id}/review-queue")
def review_queue(session_id: str, user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)
    attempts = (supa().table("checkin_attempts").select("attempt_id, student_id, reason_code, rules_json, metrics_json, created_at")
                .eq("session_id", session_id).eq("state", "flagged").is_("review_decision", "null")
                .order("created_at").execute().data or [])
    result = []
    for attempt in attempts:
        evidence = (supa().table("submission_evidence").select("storage_path, frame_offset_ms, heading_degrees")
                   .eq("attempt_id", attempt["attempt_id"]).order("frame_offset_ms").execute().data or [])
        signed = []
        for item in evidence:
            link = supa().storage.from_(os.getenv("ATTENDANCE_EVIDENCE_BUCKET", "attendance-evidence"))\
                .create_signed_url(item["storage_path"], 60)
            signed.append({**item, "signed_url": link.get("signedURL") or link.get("signedUrl")})
        result.append({**attempt, "filmstrip": signed})
    return result


@app.patch("/api/sessions/{session_id}/submissions/{attempt_id}/review")
def review_submission(session_id: str, attempt_id: str, body: SubmissionReview,
                      user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)
    if row["status"] == "finalized":
        raise HTTPException(status_code=409, detail="Finalized sessions cannot be changed")
    attempt = (supa().table("checkin_attempts").select("attempt_id, student_id, state, review_decision")
               .eq("attempt_id", attempt_id).eq("session_id", session_id).maybe_single().execute().data)
    if not attempt or attempt["state"] != "flagged":
        raise HTTPException(status_code=404, detail="Flagged submission not found")
    if attempt.get("review_decision"):
        raise HTTPException(status_code=409, detail="Submission has already been reviewed")
    now = utc_now()
    status = "present" if body.decision == "accepted" else "absent"
    supa().table("attendance").update({"status": status, "note": body.note,
        "updated_by": user["id"], "updated_at": now}).eq("session_id", session_id)\
        .eq("student_id", attempt["student_id"]).execute()
    supa().table("checkin_attempts").update({"review_decision": body.decision,
        "reviewed_by": user["id"], "reviewed_at": now, "review_note": body.note}).eq("attempt_id", attempt_id).execute()
    _audit(session_id, user["id"], "checkin.reviewed", note=body.note,
           metadata={"attempt_id": attempt_id, "student_id": attempt["student_id"], "decision": body.decision})
    publish_event(event_payload("attendance.changed", {"session_id": session_id,
                  "student_id": attempt["student_id"], "status": status}), [user["id"], attempt["student_id"]])
    return {"attempt_id": attempt_id, "decision": body.decision, "status": status, "reviewed_at": now}


@app.patch("/api/sessions/{session_id}/attendance/{student_id}")
def update_attendance(
    session_id: str,
    student_id: str,
    body: AttendanceUpdate,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)
    if row["status"] not in ("open", "closed"):
        raise HTTPException(status_code=409, detail="Finalized sessions cannot be changed")

    enr = (
        supa()
        .table("enrollments")
        .select("class_id")
        .eq("class_id", row["class_id"])
        .eq("student_id", student_id)
        .execute()
    )
    if not enr.data:
        raise HTTPException(status_code=404, detail="Student is not enrolled in this class")

    now = utc_now()
    supa().table("attendance").update(
        {"status": body.status, "note": body.note, "updated_by": user["id"], "updated_at": now}
    ).eq("session_id", session_id).eq("student_id", student_id).execute()

    _audit(session_id, user["id"], "attendance.changed",
           note=body.note,
           metadata={"student_id": student_id, "status": body.status})

    changed = (
        supa()
        .table("attendance")
        .select("student_id, status, note, updated_at, profiles!attendance_student_id_fkey(name)")
        .eq("session_id", session_id)
        .eq("student_id", student_id)
        .single()
        .execute()
    )
    result = {**changed.data}
    prof = result.pop("profiles!attendance_student_id_fkey", None) or result.pop("profiles", None)
    if isinstance(prof, dict):
        result["name"] = prof["name"]

    publish_event(
        event_payload("attendance.changed", {"session_id": session_id, "student_id": student_id, "status": body.status}),
        [user["id"]],
    )
    return result


@app.post("/api/sessions/{session_id}/finalize")
def finalize(
    session_id: str,
    body: FinalizeRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    require_teacher(user)
    if body.mark_pending_absent is not True:
        raise HTTPException(status_code=400, detail="mark_pending_absent must be true for explicit finalization")

    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)
    if row["status"] == "open":
        raise HTTPException(status_code=409, detail="Session must close before finalization")
    if row["status"] != "closed":
        raise HTTPException(status_code=409, detail="Session is already finalized")

    now = utc_now()
    pending_resp = (
        supa()
        .table("attendance")
        .select("student_id")
        .eq("session_id", session_id)
        .eq("status", "pending")
        .execute()
    )
    pending = pending_resp.data or []

    supa().table("attendance").update(
        {"status": "absent", "updated_by": user["id"], "updated_at": now}
    ).eq("session_id", session_id).eq("status", "pending").execute()

    for s in pending:
        _audit(session_id, user["id"], "attendance.changed",
               note="Pending attendance marked absent at finalization.",
               metadata={"student_id": s["student_id"], "status": "absent", "finalization": True})

    supa().table("sessions").update({"status": "finalized", "finalized_at": now}).eq("id", session_id).execute()
    _audit(session_id, user["id"], "session.finalized",
           note="Session finalized; pending records marked absent.",
           metadata={"pending_marked_absent": len(pending)})

    students_resp = (
        supa().table("enrollments").select("student_id").eq("class_id", row["class_id"]).execute()
    )
    students = students_resp.data or []
    notif_rows = [
        {
            "user_id": s["student_id"],
            "type": "attendance.finalized",
            "title": "Attendance updated",
            "body": "Your attendance record for a class session is available in the app.",
            "session_id": session_id,
            "created_at": now,
        }
        for s in students
    ]
    if notif_rows:
        supa().table("notifications").insert(notif_rows).execute()

    att_resp = supa().table("attendance").select("status").eq("session_id", session_id).execute()
    att_all = att_resp.data or []
    summary = {
        "present": sum(1 for a in att_all if a["status"] == "present"),
        "absent": sum(1 for a in att_all if a["status"] == "absent"),
        "pending": 0,
    }
    student_ids = [s["student_id"] for s in students]

    ev = event_payload("session.finalized", {"session_id": session_id, "summary": summary})
    publish_event(ev, [user["id"], *student_ids])
    for sid in student_ids:
        publish_event(event_payload("notification.created", {"session_id": session_id}), [sid])

    return {"session_id": session_id, "status": "finalized", "finalized_at": now, "summary": summary}


@app.get("/api/students/me/attendance")
def my_attendance(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    if user["role"] != "student":
        raise HTTPException(status_code=403, detail="Student role required")

    resp = (
        supa()
        .table("attendance")
        .select("session_id, status, note, updated_at, sessions(created_at, finalized_at, class_id, classes(id, name, code))")
        .eq("student_id", user["id"])
        .order("sessions(created_at)", desc=True)
        .execute()
    )
    entries = []
    for r in resp.data or []:
        sess = r.get("sessions") or {}
        cls = sess.get("classes") or {}
        entries.append({
            "session_id": r["session_id"],
            "status": r["status"],
            "note": r.get("note"),
            "updated_at": r["updated_at"],
            "created_at": sess.get("created_at"),
            "finalized_at": sess.get("finalized_at"),
            "class_id": cls.get("id"),
            "class_name": cls.get("name"),
            "class_code": cls.get("code"),
        })

    present = sum(1 for e in entries if e["status"] == "present")
    absent = sum(1 for e in entries if e["status"] == "absent")
    pending = sum(1 for e in entries if e["status"] == "pending")
    total = present + absent
    return {
        "student": {"id": user["id"], "name": user["name"], "email": user["email"], "role": user["role"]},
        "entries": entries,
        "summary": {
            "present": present,
            "absent": absent,
            "pending": pending,
            "total_finalized": total,
            "percentage": round((present / total) * 100, 1) if total else None,
        },
    }


@app.get("/api/reports/sessions/{session_id}")
def report(session_id: str, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)

    entries_resp = (
        supa()
        .table("attendance")
        .select("status, note, updated_at, profiles!attendance_student_id_fkey(name, email)")
        .eq("session_id", session_id)
        .order("profiles!attendance_student_id_fkey(name)")
        .execute()
    )
    entries = []
    for e in entries_resp.data or []:
        flat = {**e}
        prof = flat.pop("profiles!attendance_student_id_fkey", None) or flat.pop("profiles", None)
        if isinstance(prof, dict):
            flat["name"] = prof["name"]
            flat["email"] = prof["email"]
        entries.append(flat)

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["student_name", "student_email", "status", "note", "updated_at"])
    for e in entries:
        writer.writerow([e.get("name", ""), e.get("email", ""), e["status"], e.get("note") or "", e["updated_at"]])
    csv_data = output.getvalue()

    pdf_html = (
        "<!doctype html><html><head><meta charset='utf-8'><title>Attendance report</title></head><body><h1>"
        + escape(str(row.get("class_name", "")))
        + " attendance</h1><p>Session "
        + escape(str(session_id))
        + " · "
        + escape(str(row["created_at"]))
        + "</p><table><thead><tr><th>Student</th><th>Email</th><th>Status</th><th>Note</th></tr></thead><tbody>"
        + "".join(
            f"<tr><td>{escape(str(e.get('name', '')))}</td><td>{escape(str(e.get('email', '')))}</td>"
            f"<td>{escape(str(e['status']))}</td><td>{escape(str(e.get('note') or ''))}</td></tr>"
            for e in entries
        )
        + "</tbody></table></body></html>"
    )
    return {
        "session": {
            "id": row["id"],
            "class_id": row["class_id"],
            "class_name": row.get("class_name", ""),
            "class_code": row.get("class_code", ""),
            "status": row["status"],
            "created_at": row["created_at"],
            "finalized_at": row.get("finalized_at"),
        },
        "rows": entries,
        "csv": csv_data,
        "pdf": pdf_html,
        "pdf_html": pdf_html,
        "pdf_note": "Print pdf_html from a trusted client to create a PDF; the API does not claim to be a PDF renderer.",
    }


@app.get("/api/audit")
def get_audit(session_id: str = Query(...), user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)

    resp = (
        supa()
        .table("audit_log")
        .select("*, profiles(id, name)")
        .eq("session_id", session_id)
        .order("id")
        .execute()
    )
    result = []
    for r in resp.data or []:
        item = {**r}
        if isinstance(r.get("profiles"), dict):
            item["actor_id"] = r["profiles"]["id"]
            item["actor_name"] = r["profiles"]["name"]
            item.pop("profiles", None)
        item["metadata"] = json.loads(item.pop("metadata_json") or "{}")
        result.append(item)
    return result


@app.get("/api/notifications")
def notifications(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    resp = (
        supa()
        .table("notifications")
        .select("id, type, title, body, session_id, created_at, read_at")
        .eq("user_id", user["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return resp.data or []


@app.post("/api/notifications/{notification_id}/read")
def mark_notification_read(
    notification_id: str, user: dict[str, Any] = Depends(current_user)
) -> dict[str, Any]:
    existing = (
        supa()
        .table("notifications")
        .select("id")
        .eq("id", notification_id)
        .eq("user_id", user["id"])
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Notification not found")
    read_at = utc_now()
    supa().table("notifications").update({"read_at": read_at}).eq("id", notification_id).execute()
    return {"id": notification_id, "read_at": read_at}


# ── WebSocket ─────────────────────────────────────────────────────────────────
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
            done, _ = await asyncio.wait({receive_task, event_task}, return_when=asyncio.FIRST_COMPLETED)
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
