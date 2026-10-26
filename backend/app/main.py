"""Classroom attendance API – Attendrix backend.

Consolidated entrypoint featuring:
- Role-enforced authentication with mismatch detection.
- Biometric reference selfie enrollment with encrypted embeddings.
- Server-authoritative time-limited attendance sessions with auto-close.
- 9-rule continuous front-camera sweep verification pipeline.
- Lecturer review queue for flagged attempts with key-frame filmstrip.
- Authenticated single-use WebSocket tickets and event streams.
- Full audit logging, in-app notifications, and CSV/print reporting.
"""
from __future__ import annotations

import asyncio
import csv
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

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Query,
    Request,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.config import (
    ATTENDANCE_ENV,
    AUTO_CLOSE_INTERVAL_S,
    CORS_ORIGINS,
    DEFAULT_SESSION_DURATION_MINUTES,
    MAX_CAPTURE_BYTES,
    MAX_SESSION_DURATION_MINUTES,
    MIN_LAPLACIAN_VAR,
    MIN_LUMINANCE,
    SESSION_DURATION_PRESETS,
    SESSION_GRACE_PERIOD_S,
    WS_TICKET_TTL_SECONDS,
)
from app.db import supa, utc_now
from app.face_engine import FaceDetection, get_face_engine
from app.security import (
    check_login_rate_limit,
    check_submit_rate_limit,
    create_access_token,
    decrypt_face_embedding,
    encrypt_face_embedding,
    verify_jwt_token,
)
from app.verification import (
    SweepFrame,
    VerificationPipeline,
    compute_image_metrics,
    parse_image_frame,
)

logger = logging.getLogger("attendrix")

# ── WebSocket state ───────────────────────────────────────────────────────────
_ws_lock = threading.Lock()
_ws_tickets: dict[str, tuple[str, float]] = {}
_ws_clients: dict[str, set[WebSocket]] = {}
_ws_client_loops: dict[WebSocket, asyncio.AbstractEventLoop] = {}
_ws_client_queues: dict[WebSocket, asyncio.Queue[str]] = {}


# ── Background Task: Auto-Close Expired Sessions ──────────────────────────────
async def _session_auto_close_loop():
    """Background task running in lifespan to close expired sessions on server clock."""
    while True:
        try:
            await asyncio.sleep(AUTO_CLOSE_INTERVAL_S)
            now_dt = datetime.now(timezone.utc)
            db = supa()
            open_sessions = (
                db.table("sessions")
                .select("*, classes(name, code, teacher_id)")
                .eq("status", "open")
                .execute()
            )
            for sess in open_sessions.data or []:
                ends_at_str = sess.get("ends_at")
                if not ends_at_str:
                    continue
                try:
                    ends_at = datetime.fromisoformat(ends_at_str.replace("Z", "+00:00"))
                    if now_dt >= ends_at:
                        _close_session_internal(sess)
                except Exception as e:
                    logger.error(f"Error checking session expiry: {e}")
        except asyncio.CancelledError:
            break
        except Exception as exc:
            logger.error(f"Error in session auto-close loop: {exc}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Verify DB connectivity on startup
    try:
        supa().table("profiles").select("id").limit(1).execute()
    except Exception as exc:
        if ATTENDANCE_ENV != "test":
            logger.warning(f"Database connection note: {exc}")

    # Launch auto-close background loop
    task = asyncio.create_task(_session_auto_close_loop())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


# ── FastAPI App ───────────────────────────────────────────────────────────────
app = FastAPI(
    title="Attendrix Attendance API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Dependency: Auth & Role Guards ───────────────────────────────────────────
def current_user(authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer access token required")
    token = authorization.split(" ", 1)[1].strip()

    # Try verifying with PyJWT secret
    payload = verify_jwt_token(token)
    uid = payload.get("sub", "")
    if not uid:
        raise HTTPException(status_code=401, detail="Invalid token: missing subject")

    resp = supa().table("profiles").select("*").eq("id", uid).single().execute()
    if not resp.data:
        raise HTTPException(status_code=401, detail="User profile not found")
    return resp.data


def require_teacher(user: dict[str, Any]) -> None:
    # Role in DB is 'teacher' (presented as Lecturer in UI)
    if user.get("role") != "teacher":
        raise HTTPException(status_code=403, detail="Lecturer authorization required")


def require_student(user: dict[str, Any]) -> None:
    if user.get("role") != "student":
        raise HTTPException(status_code=403, detail="Student authorization required")


# ── Utility: Session & Class Guards ───────────────────────────────────────────
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
    if isinstance(row.get("classes"), dict):
        row["class_name"] = row["classes"]["name"]
        row["class_code"] = row["classes"]["code"]
        row["teacher_id"] = row["classes"]["teacher_id"]

    # Lazy auto-close check so expiry survives server restarts and offline time
    if row.get("status") == "open" and row.get("ends_at"):
        try:
            ends_at = datetime.fromisoformat(row["ends_at"].replace("Z", "+00:00"))
            if datetime.now(timezone.utc) >= ends_at:
                _close_session_internal(row)
                row["status"] = "closed"
        except Exception:
            pass

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
            raise HTTPException(status_code=403, detail="You are not enrolled in this session's class")


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
            "metadata_json": json.dumps(metadata or {}),
        }
    ).execute()


def _create_notification(
    user_id: str,
    notif_type: str,
    title: str,
    body: str,
    session_id: Optional[str] = None,
) -> dict[str, Any]:
    row = {
        "user_id": user_id,
        "type": notif_type,
        "title": title,
        "body": body,
        "session_id": session_id,
        "created_at": utc_now(),
    }
    resp = supa().table("notifications").insert(row).execute()
    created = resp.data[0] if resp.data else row
    publish_event(event_payload("notification.created", created), [user_id])
    return created


def _close_session_internal(sess: dict[str, Any]) -> None:
    """Internal helper to close an expired session and emit session.closed event."""
    session_id = sess["id"]
    db = supa()
    # Check if already closed
    current = db.table("sessions").select("status").eq("id", session_id).single().execute()
    if current.data and current.data.get("status") != "open":
        return

    db.table("sessions").update({"status": "closed"}).eq("id", session_id).execute()

    # Tally results
    att = db.table("attendance").select("status").eq("session_id", session_id).execute()
    att_rows = att.data or []
    present_count = sum(1 for a in att_rows if a.get("status") == "present")
    pending_count = sum(1 for a in att_rows if a.get("status") == "pending")
    absent_count = sum(1 for a in att_rows if a.get("status") == "absent")
    total_enrolled = len(att_rows)

    rej = (
        db.table("checkin_attempts")
        .select("id", count="exact")
        .eq("session_id", session_id)
        .eq("state", "rejected")
        .execute()
    )
    rejected_count = rej.count if rej.count is not None else len(rej.data or [])

    flagged_attempts = (
        db.table("checkin_attempts")
        .select("id", count="exact")
        .eq("session_id", session_id)
        .eq("state", "flagged")
        .execute()
    )
    needs_review = flagged_attempts.count if flagged_attempts.count is not None else pending_count

    counts_payload = {
        "session_id": session_id,
        "class_id": sess.get("class_id"),
        "present": present_count,
        "needs_review": needs_review,
        "absent": absent_count,
        "rejected_attempts": rejected_count,
        "total_enrolled": total_enrolled,
    }

    # Audit log
    teacher_id = sess.get("teacher_id") or sess.get("created_by")
    _audit(
        session_id,
        teacher_id,
        "session.closed",
        note="Attendance window closed automatically by server clock.",
        metadata=counts_payload,
    )

    # In-app notification for lecturer
    _create_notification(
        teacher_id,
        "session.closed",
        "Attendance Window Closed",
        f"Attendance window closed. {present_count} verified present out of {total_enrolled} enrolled.",
        session_id=session_id,
    )

    # Broadcast WebSocket event
    enr = db.table("enrollments").select("student_id").eq("class_id", sess.get("class_id")).execute()
    student_ids = [s["student_id"] for s in (enr.data or [])]
    publish_event(
        event_payload("session.closed", counts_payload),
        [teacher_id, *student_ids],
    )


# ── WebSocket helpers ─────────────────────────────────────────────────────────
def event_payload(event_type: str, data: Any) -> str:
    return json.dumps(
        {
            "type": event_type,
            "data": data,
            "timestamp": utc_now(),
        }
    )


def publish_event(event_payload_json: str, user_ids: list[str]) -> None:
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


# ── Pydantic Request Models ───────────────────────────────────────────────────
class LoginRequest(BaseModel):
    email: str
    password: str
    selected_role: Optional[str] = None  # 'student' or 'teacher' / 'lecturer'


class CreateSessionRequest(BaseModel):
    class_id: str
    duration_minutes: Optional[int] = Field(
        default=DEFAULT_SESSION_DURATION_MINUTES,
        ge=1,
        le=MAX_SESSION_DURATION_MINUTES,
    )


class AttendanceUpdate(BaseModel):
    status: str = Field(pattern="^(present|absent|pending)$")
    note: Optional[str] = Field(default=None, max_length=500)


class FinalizeRequest(BaseModel):
    mark_pending_absent: bool = True


class ReviewAttemptRequest(BaseModel):
    decision: str = Field(pattern="^(accept|reject)$")
    note: Optional[str] = Field(default=None, max_length=500)


# ── Routes: Health & Server Time ──────────────────────────────────────────────
@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "attendrix-attendance-api"}


@app.get("/api/time")
def server_time() -> dict[str, Any]:
    """Return server clock time for client countdown synchronization."""
    now_dt = datetime.now(timezone.utc)
    return {
        "server_time": now_dt.isoformat(timespec="seconds"),
        "server_timestamp_ms": int(now_dt.timestamp() * 1000),
    }


# ── Routes: Authentication & Role Verification ────────────────────────────────
@app.post("/api/auth/login")
def login(req: LoginRequest, request: Request) -> dict[str, Any]:
    client_ip = request.client.host if request.client else "127.0.0.1"
    check_login_rate_limit(client_ip)

    email = req.email.strip().lower()

    # Look up profile
    prof_resp = supa().table("profiles").select("*").eq("email", email).single().execute()
    prof = prof_resp.data

    if not prof:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Map user-facing "lecturer" to DB role "teacher"
    requested_role = req.selected_role.lower() if req.selected_role else None
    if requested_role in ("lecturer", "teacher"):
        expected_role = "teacher"
    elif requested_role == "student":
        expected_role = "student"
    else:
        expected_role = None

    # Check role mismatch if selected_role was specified
    if expected_role and prof["role"] != expected_role:
        role_label = "Student" if prof["role"] == "student" else "Lecturer"
        selected_label = "Student" if expected_role == "student" else "Lecturer"
        raise HTTPException(
            status_code=403,
            detail=f"Role mismatch: This account is registered as {role_label}, not {selected_label}.",
        )

    # Issue verified token
    token = create_access_token(
        user_id=prof["id"],
        email=prof["email"],
        role=prof["role"],
        name=prof["name"],
    )

    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": prof["id"],
            "name": prof["name"],
            "email": prof["email"],
            "role": prof["role"],
        },
    }


@app.get("/api/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {
        "id": user["id"],
        "name": user["name"],
        "email": user["email"],
        "role": user["role"],
    }


# ── Routes: Biometric Selfie Reference Enrollment ─────────────────────────────
@app.post("/api/auth/enroll")
async def enroll_reference_selfie(
    consent: bool = Form(...),
    photo: UploadFile = File(...),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    """Enroll a quality-checked reference selfie. Stores ONLY encrypted embedding."""
    if not consent:
        raise HTTPException(
            status_code=400,
            detail="Biometric consent is required to enroll reference face verification.",
        )

    image_bytes = await photo.read()
    if len(image_bytes) > MAX_CAPTURE_BYTES:
        raise HTTPException(status_code=413, detail="Photo file size exceeds maximum limit.")

    img = parse_image_frame(image_bytes)
    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image file.")

    engine = get_face_engine()
    faces = engine.detect_faces(img)

    if not faces:
        raise HTTPException(
            status_code=400,
            detail="No face detected. Please center your face in the front camera and try again.",
        )
    if len(faces) > 1:
        raise HTTPException(
            status_code=400,
            detail="Multiple faces detected. Please ensure only you are visible in your reference selfie.",
        )

    lap_var, mean_lum = compute_image_metrics(img)
    if lap_var < MIN_LAPLACIAN_VAR:
        raise HTTPException(
            status_code=400,
            detail="Photo is too blurry. Please hold the phone steady in good lighting.",
        )
    if mean_lum < MIN_LUMINANCE:
        raise HTTPException(
            status_code=400,
            detail="Photo is too dark. Please take your reference photo in a well-lit area.",
        )

    # Extract 512-dim embedding and encrypt it symmetrically
    emb = engine.extract_embedding(img, faces[0])
    encrypted_emb = encrypt_face_embedding(emb)
    consent_ts = utc_now()
    model_version = "arcface-yunet-v1"

    # Save to face_templates (overwriting previous enrollment if any)
    db = supa()
    existing = db.table("face_templates").select("id").eq("user_id", user["id"]).execute()
    if existing.data:
        db.table("face_templates").update(
            {
                "encrypted_embedding": encrypted_emb,
                "model_version": model_version,
                "consent_timestamp": consent_ts,
            }
        ).eq("user_id", user["id"]).execute()
    else:
        db.table("face_templates").insert(
            {
                "user_id": user["id"],
                "encrypted_embedding": encrypted_emb,
                "model_version": model_version,
                "consent_timestamp": consent_ts,
            }
        ).execute()

    # Raw image bytes and decrypted embedding are immediately freed
    del image_bytes
    del img

    return {
        "status": "enrolled",
        "consent_timestamp": consent_ts,
        "model_version": model_version,
        "message": "Reference selfie successfully enrolled and encrypted.",
    }


@app.get("/api/auth/enrollment-status")
def enrollment_status(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    """Check if the signed-in user has enrolled a reference selfie (never exposes embedding)."""
    resp = (
        supa()
        .table("face_templates")
        .select("consent_timestamp, model_version, created_at")
        .eq("user_id", user["id"])
        .single()
        .execute()
    )
    if resp.data:
        return {
            "enrolled": True,
            "consent_timestamp": resp.data["consent_timestamp"],
            "model_version": resp.data["model_version"],
        }
    return {"enrolled": False}


# ── Routes: Classes ───────────────────────────────────────────────────────────
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


# ── Routes: Sessions Lifecycle ────────────────────────────────────────────────
@app.get("/api/sessions")
def sessions(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    now_iso = utc_now()
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
        if isinstance(r.get("classes"), dict):
            flat["class_name"] = r["classes"]["name"]
            flat["class_code"] = r["classes"]["code"]
            flat.pop("classes", None)

        # Lazy auto-close check
        if flat.get("status") == "open" and flat.get("ends_at"):
            try:
                ends_at = datetime.fromisoformat(flat["ends_at"].replace("Z", "+00:00"))
                if datetime.now(timezone.utc) >= ends_at:
                    _close_session_internal(flat)
                    flat["status"] = "closed"
            except Exception:
                pass

        flat["server_time"] = now_iso
        rows.append(flat)
    return rows


@app.post("/api/sessions")
def create_session(
    body: CreateSessionRequest, user: dict[str, Any] = Depends(current_user)
) -> dict[str, Any]:
    require_teacher(user)
    cls = _get_class_or_404(body.class_id)
    _assert_class_access(cls, user)

    duration = body.duration_minutes or DEFAULT_SESSION_DURATION_MINUTES
    now_dt = datetime.now(timezone.utc)
    ends_dt = now_dt + timedelta(minutes=duration)

    now_iso = now_dt.isoformat(timespec="seconds")
    ends_iso = ends_dt.isoformat(timespec="seconds")

    sess_resp = (
        supa()
        .table("sessions")
        .insert(
            {
                "class_id": body.class_id,
                "status": "open",
                "created_by": user["id"],
                "created_at": now_iso,
                "starts_at": now_iso,
                "ends_at": ends_iso,
                "duration_minutes": duration,
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
            "updated_at": now_iso,
        }
        for s in (students.data or [])
    ]
    if att_rows:
        supa().table("attendance").insert(att_rows).execute()

    _audit(
        session_id,
        user["id"],
        "session.created",
        note=f"Session created with {duration} minute duration.",
        metadata={"class_id": body.class_id, "duration_minutes": duration, "ends_at": ends_iso},
    )

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


def _session_payload(row: dict[str, Any], user: dict[str, Any]) -> dict[str, Any]:
    session_id = row["id"]
    db = supa()
    att = (
        db.table("attendance")
        .select("*, profiles!attendance_student_id_fkey(name, email)")
        .eq("session_id", session_id)
        .execute()
    )
    entries = []
    for e in att.data or []:
        flat = {**e}
        prof = e.get("profiles!attendance_student_id_fkey") or e.get("profiles")
        if isinstance(prof, dict):
            flat["name"] = prof.get("name")
            flat["email"] = prof.get("email")
            flat.pop("profiles!attendance_student_id_fkey", None)
            flat.pop("profiles", None)
        entries.append(flat)

    counts = {
        "present": sum(1 for e in entries if e["status"] == "present"),
        "pending": sum(1 for e in entries if e["status"] == "pending"),
        "absent": sum(1 for e in entries if e["status"] == "absent"),
        "total": len(entries),
    }

    # Verified headline count for live screen
    verified_attempts = (
        db.table("checkin_attempts")
        .select("id", count="exact")
        .eq("session_id", session_id)
        .eq("state", "verified")
        .execute()
    )
    counts["verified_count"] = verified_attempts.count or counts["present"]

    flagged_attempts = (
        db.table("checkin_attempts")
        .select("id", count="exact")
        .eq("session_id", session_id)
        .eq("state", "flagged")
        .execute()
    )
    counts["flagged_count"] = flagged_attempts.count or 0

    return {
        "id": row["id"],
        "class_id": row["class_id"],
        "class_name": row.get("class_name", ""),
        "class_code": row.get("class_code", ""),
        "teacher_id": row.get("teacher_id"),
        "status": row["status"],
        "created_at": row["created_at"],
        "starts_at": row.get("starts_at", row["created_at"]),
        "ends_at": row.get("ends_at"),
        "duration_minutes": row.get("duration_minutes", DEFAULT_SESSION_DURATION_MINUTES),
        "finalized_at": row.get("finalized_at"),
        "server_time": utc_now(),
        "summary": counts,
        "attendance": entries,
    }


# ── Routes: Continuous Front-Camera Sweep Check-in ────────────────────────────
@app.post("/api/sessions/{session_id}/checkin")
async def student_sweep_checkin(
    session_id: str,
    attempt_id: str = Form(...),
    metadata: str = Form(...),
    frames: list[UploadFile] = File(...),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    """Continuous front-camera sweep attendance check-in.

    Executes 9-rule ordered verification pipeline. Persists ONLY metrics and reason codes.
    Deletes raw frames after analysis for verified and rejected attempts.
    """
    require_student(user)
    check_submit_rate_limit(user["id"])

    row = _get_session_or_404(session_id)
    _assert_session_access(row, user)

    # Parse sweep frames metadata
    try:
        frame_meta_list = json.loads(metadata)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid metadata format; expected JSON array.")

    # Read uploaded frame bytes
    sweep_frames: list[SweepFrame] = []
    for idx, upload in enumerate(frames):
        data = await upload.read()
        meta = frame_meta_list[idx] if idx < len(frame_meta_list) else {}
        sweep_frames.append(
            SweepFrame(
                index=idx,
                image_bytes=data,
                heading_deg=float(meta.get("heading_deg", idx * 10.0)),
                time_offset_s=float(meta.get("time_offset_s", idx * 0.2)),
            )
        )

    # Retrieve student reference face embedding
    db = supa()
    st_template = (
        db.table("face_templates")
        .select("encrypted_embedding")
        .eq("user_id", user["id"])
        .single()
        .execute()
    )
    st_emb = None
    if st_template.data:
        st_emb = decrypt_face_embedding(st_template.data["encrypted_embedding"])

    # Retrieve lecturer reference face embedding
    lec_template = (
        db.table("face_templates")
        .select("encrypted_embedding")
        .eq("user_id", row.get("teacher_id"))
        .single()
        .execute()
    )
    lec_emb = None
    if lec_template.data:
        lec_emb = decrypt_face_embedding(lec_template.data["encrypted_embedding"])

    # Execute 9-Rule Verification Pipeline
    pipeline = VerificationPipeline()
    outcome = pipeline.run(
        session=row,
        student_profile=user,
        attempt_id=attempt_id,
        frames=sweep_frames,
        student_enrolled_embedding=st_emb,
        lecturer_enrolled_embedding=lec_emb,
    )

    filmstrip_paths: list[str] = []
    # If FLAGGED: retain key frames for lecturer review
    if outcome.state == "flagged" and outcome.filmstrip_bytes:
        for k_idx, fb in enumerate(outcome.filmstrip_bytes):
            p = f"filmstrips/{session_id}/{attempt_id}/frame_{k_idx}.jpg"
            db.storage.from_("private-filmstrips").upload(p, fb)
            filmstrip_paths.append(p)

    # Record checkin attempt
    db.table("checkin_attempts").insert(
        {
            "attempt_id": attempt_id,
            "session_id": session_id,
            "student_id": user["id"],
            "state": outcome.state,
            "error_code": outcome.reason_code,
            "metrics_json": json.dumps(outcome.metrics),
            "filmstrip_paths": filmstrip_paths,
            "created_at": utc_now(),
            "updated_at": utc_now(),
        }
    ).execute()

    # Update attendance & notify on VERIFIED
    if outcome.state == "verified":
        db.table("attendance").update(
            {"status": "present", "note": "Verified by continuous sweep.", "updated_at": utc_now()}
        ).eq("session_id", session_id).eq("student_id", user["id"]).execute()

        _audit(
            session_id,
            user["id"],
            "attendance.verified",
            note="Verified via continuous front-camera sweep.",
            metadata={"attempt_id": attempt_id},
        )

        _create_notification(
            user["id"],
            "attendance.verified",
            "Attendance Verified",
            f"Your attendance for {row.get('class_name', 'Class')} has been verified as Present.",
            session_id=session_id,
        )

        # Notify lecturer and students via WebSocket
        publish_event(
            event_payload(
                "attendance.changed",
                {
                    "session_id": session_id,
                    "student_id": user["id"],
                    "status": "present",
                    "note": "Verified by continuous sweep.",
                },
            ),
            [row["teacher_id"], user["id"]],
        )

    elif outcome.state == "flagged":
        _audit(
            session_id,
            user["id"],
            "attendance.flagged",
            note=f"Check-in flagged for lecturer review: {outcome.reason_code}",
            metadata={"attempt_id": attempt_id, "reason_code": outcome.reason_code},
        )
        _create_notification(
            row["teacher_id"],
            "attendance.flagged",
            "Attendance Review Needed",
            f"{user['name']}'s sweep was flagged for review ({outcome.reason_code}).",
            session_id=session_id,
        )

    elif outcome.state == "rejected":
        _audit(
            session_id,
            user["id"],
            "attendance.rejected",
            note=f"Check-in attempt rejected: {outcome.reason_code}",
            metadata={"attempt_id": attempt_id, "reason_code": outcome.reason_code},
        )

    # Privacy Rule: Purge raw frames from memory
    for f in sweep_frames:
        f.image_bytes = b""
        f.img_bgr = None
    del sweep_frames

    return {
        "attempt_id": attempt_id,
        "session_id": session_id,
        "state": outcome.state,
        "reason_code": outcome.reason_code,
        "message": outcome.message,
        "metrics": outcome.metrics,
    }


# ── Routes: Lecturer Review Queue & Decision ──────────────────────────────────
@app.get("/api/sessions/{session_id}/review-queue")
def review_queue(
    session_id: str, user: dict[str, Any] = Depends(current_user)
) -> list[dict[str, Any]]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)

    db = supa()
    attempts = (
        db.table("checkin_attempts")
        .select("*, profiles!checkin_attempts_student_id_fkey(name, email)")
        .eq("session_id", session_id)
        .eq("state", "flagged")
        .order("created_at", desc=False)
        .execute()
    )

    result = []
    for a in attempts.data or []:
        item = {**a}
        prof = a.get("profiles!checkin_attempts_student_id_fkey") or a.get("profiles")
        if isinstance(prof, dict):
            item["student_name"] = prof.get("name")
            item["student_email"] = prof.get("email")

        # Generate signed URLs for filmstrip frames
        paths = a.get("filmstrip_paths") or []
        signed_urls = []
        for p in paths:
            url_resp = db.storage.from_("private-filmstrips").create_signed_url(p, expires_in=3600)
            signed_urls.append(url_resp.get("signedURL", ""))
        item["filmstrip_urls"] = signed_urls
        item["metrics"] = json.loads(item.get("metrics_json") or "{}")
        result.append(item)

    return result


@app.post("/api/sessions/{session_id}/review/{attempt_id}")
def review_decision(
    session_id: str,
    attempt_id: str,
    body: ReviewAttemptRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)

    db = supa()
    attempt = (
        db.table("checkin_attempts")
        .select("*")
        .eq("session_id", session_id)
        .eq("attempt_id", attempt_id)
        .single()
        .execute()
    )
    if not attempt.data:
        raise HTTPException(status_code=404, detail="Checkin attempt not found.")

    att_row = attempt.data
    student_id = att_row["student_id"]
    new_status = "present" if body.decision == "accept" else "absent"
    new_state = "verified" if body.decision == "accept" else "rejected"
    note = body.note or (
        "Accepted by lecturer review." if body.decision == "accept" else "Rejected by lecturer review."
    )

    db.table("checkin_attempts").update(
        {"state": new_state, "updated_at": utc_now()}
    ).eq("id", att_row["id"]).execute()

    db.table("attendance").update(
        {"status": new_status, "note": note, "updated_by": user["id"], "updated_at": utc_now()}
    ).eq("session_id", session_id).eq("student_id", student_id).execute()

    action = "attendance.accepted_by_lecturer" if body.decision == "accept" else "attendance.rejected_by_lecturer"
    _audit(session_id, user["id"], action, note=note, metadata={"attempt_id": attempt_id})

    _create_notification(
        student_id,
        action,
        "Attendance Review Decision",
        f"Your attendance for {row.get('class_name', 'Class')} was reviewed: {new_status.capitalize()}.",
        session_id=session_id,
    )

    publish_event(
        event_payload(
            "attendance.changed",
            {"session_id": session_id, "student_id": student_id, "status": new_status, "note": note},
        ),
        [user["id"], student_id],
    )

    return {"status": "ok", "decision": body.decision, "attendance_status": new_status}


# ── Routes: Manual Attendance & Finalization ──────────────────────────────────
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
    if row["status"] == "finalized":
        raise HTTPException(status_code=409, detail="Finalized sessions cannot be modified")

    db = supa()
    existing = (
        db.table("attendance")
        .select("id, status")
        .eq("session_id", session_id)
        .eq("student_id", student_id)
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Student attendance record not found")

    old_status = existing.data[0]["status"]
    now = utc_now()
    db.table("attendance").update(
        {"status": body.status, "note": body.note, "updated_by": user["id"], "updated_at": now}
    ).eq("session_id", session_id).eq("student_id", student_id).execute()

    _audit(
        session_id,
        user["id"],
        "attendance.changed",
        note=body.note,
        metadata={"student_id": student_id, "from": old_status, "to": body.status},
    )

    publish_event(
        event_payload(
            "attendance.changed",
            {"session_id": session_id, "student_id": student_id, "status": body.status, "note": body.note},
        ),
        [user["id"], student_id],
    )

    return {"session_id": session_id, "student_id": student_id, "status": body.status, "note": body.note}


@app.post("/api/sessions/{session_id}/finalize")
def finalize_session(
    session_id: str,
    body: FinalizeRequest,
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)
    if row["status"] == "finalized":
        raise HTTPException(status_code=409, detail="Session is already finalized")

    db = supa()
    now = utc_now()

    if body.mark_pending_absent:
        pending = (
            db.table("attendance")
            .select("student_id")
            .eq("session_id", session_id)
            .eq("status", "pending")
            .execute()
        )
        for p in pending.data or []:
            db.table("attendance").update(
                {"status": "absent", "note": "Marked absent upon finalization.", "updated_by": user["id"], "updated_at": now}
            ).eq("session_id", session_id).eq("student_id", p["student_id"]).execute()

    db.table("sessions").update(
        {"status": "finalized", "finalized_at": now}
    ).eq("id", session_id).execute()

    _audit(session_id, user["id"], "session.finalized", note="Session finalized by lecturer.")

    # Student notifications
    att = db.table("attendance").select("student_id, status").eq("session_id", session_id).execute()
    for entry in att.data or []:
        _create_notification(
            entry["student_id"],
            "session.finalized",
            "Attendance Finalized",
            f"Attendance for {row.get('class_name', 'Class')} was finalized: {entry['status'].capitalize()}.",
            session_id=session_id,
        )

    updated_row = _get_session_or_404(session_id)
    payload = _session_payload(updated_row, user)

    enr = db.table("enrollments").select("student_id").eq("class_id", row["class_id"]).execute()
    student_ids = [s["student_id"] for s in (enr.data or [])]
    publish_event(
        event_payload("session.finalized", {"session_id": session_id}),
        [user["id"], *student_ids],
    )
    return payload


# ── Routes: Student Attendance History ────────────────────────────────────────
@app.get("/api/students/me/attendance")
def student_own_attendance(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_student(user)
    db = supa()
    resp = (
        db.table("attendance")
        .select("*, sessions(class_id, created_at, starts_at, ends_at, classes(name, code))")
        .eq("student_id", user["id"])
        .execute()
    )

    entries = []
    for r in resp.data or []:
        flat = {**r}
        sess = r.get("sessions")
        if isinstance(sess, dict):
            flat["class_id"] = sess.get("class_id")
            flat["session_created_at"] = sess.get("created_at")
            cls = sess.get("classes")
            if isinstance(cls, dict):
                flat["class_name"] = cls.get("name")
                flat["class_code"] = cls.get("code")
            flat.pop("sessions", None)
        entries.append(flat)

    present_count = sum(1 for e in entries if e.get("status") == "present")
    total_count = len(entries)
    pct = round((present_count / total_count * 100.0), 1) if total_count > 0 else 0.0

    return {
        "student_id": user["id"],
        "summary": {
            "present": present_count,
            "total": total_count,
            "percentage": pct,
        },
        "entries": entries,
    }


# ── Routes: Reports & Audit ───────────────────────────────────────────────────
@app.get("/api/sessions/{session_id}/report")
def session_report(
    session_id: str, user: dict[str, Any] = Depends(current_user)
) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)

    db = supa()
    att = (
        db.table("attendance")
        .select("*, profiles!attendance_student_id_fkey(name, email)")
        .eq("session_id", session_id)
        .execute()
    )
    entries = []
    for e in att.data or []:
        flat = {**e}
        prof = e.get("profiles!attendance_student_id_fkey") or e.get("profiles")
        if isinstance(prof, dict):
            flat["name"] = prof.get("name")
            flat["email"] = prof.get("email")
        entries.append(flat)

    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["Student", "Email", "Status", "Note", "Updated At"])
    for e in entries:
        writer.writerow([e.get("name", ""), e.get("email", ""), e["status"], e.get("note") or "", e["updated_at"]])
    csv_data = out.getvalue()

    pdf_html = (
        f"<!doctype html><html><head><meta charset='utf-8'><title>Attendance report</title></head><body>"
        f"<h1>{escape(str(row.get('class_name', '')))} Attendance</h1>"
        f"<p>Session {escape(str(session_id))} · {escape(str(row['created_at']))}</p>"
        f"<table><thead><tr><th>Student</th><th>Email</th><th>Status</th><th>Note</th></tr></thead><tbody>"
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
        "pdf_note": "Print pdf_html from a browser to generate PDF; the backend outputs standards-compliant HTML.",
    }


@app.get("/api/audit")
def get_audit(
    session_id: str = Query(...), user: dict[str, Any] = Depends(current_user)
) -> list[dict[str, Any]]:
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
    db = supa()
    existing = (
        db.table("notifications")
        .select("id")
        .eq("id", notification_id)
        .eq("user_id", user["id"])
        .execute()
    )
    if not existing.data:
        raise HTTPException(status_code=404, detail="Notification not found")
    read_at = utc_now()
    db.table("notifications").update({"read_at": read_at}).eq("id", notification_id).execute()
    return {"id": notification_id, "read_at": read_at}


# ── Routes: Realtime WebSockets ───────────────────────────────────────────────
@app.post("/api/realtime/ticket")
def create_ticket(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    ticket = secrets.token_urlsafe(32)
    expires_at = time.time() + WS_TICKET_TTL_SECONDS
    with _ws_lock:
        _ws_tickets[ticket] = (user["id"], expires_at)
    return {"ticket": ticket, "expires_in": WS_TICKET_TTL_SECONDS}


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
