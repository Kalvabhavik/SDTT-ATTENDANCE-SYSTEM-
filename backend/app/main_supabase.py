"""Classroom attendance prototype API – Supabase edition.

Auth:  Supabase Auth (JWT verification via PyJWT + SUPABASE_JWT_SECRET).
DB:    Supabase PostgreSQL (via supabase-py service-role client).

This service intentionally implements synthetic, review-first attendance only.
It never stores uploaded photos or face embeddings and makes no
biometric/production claims.
"""
from __future__ import annotations

import asyncio
import base64
import csv
import io
import json
import os
import secrets
import threading
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from html import escape
from typing import Any, Optional

import jwt as pyjwt
from fastapi import (
    Depends,
    FastAPI,
    File,
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

# ── Config ────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")

SUPABASE_URL: str = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_ROLE_KEY: str = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
SUPABASE_JWT_SECRET: str = os.environ["SUPABASE_JWT_SECRET"]

WS_TICKET_TTL_SECONDS = int(os.getenv("ATTENDANCE_WS_TICKET_TTL_SECONDS", "60"))
MAX_CAPTURE_BYTES = int(os.getenv("ATTENDANCE_MAX_CAPTURE_BYTES", "10485760"))
CORS_ORIGINS = [
    v.strip()
    for v in os.getenv(
        "ATTENDANCE_CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5173,http://localhost:8081",
    ).split(",")
    if v.strip()
]

# ── Supabase client (service-role – server side only) ─────────────────────────
_supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)


def supa() -> Client:
    """Return the shared Supabase service-role client."""
    return _supabase


# ── WebSocket state ───────────────────────────────────────────────────────────
_ws_lock = threading.Lock()
_ws_tickets: dict[str, tuple[int, float]] = {}
_ws_clients: dict[int, set[WebSocket]] = {}
_ws_client_loops: dict[WebSocket, asyncio.AbstractEventLoop] = {}
_ws_client_queues: dict[WebSocket, asyncio.Queue[str]] = {}


# ── Helpers ───────────────────────────────────────────────────────────────────
def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _verify_supabase_jwt(token: str) -> dict[str, Any]:
    """Decode and verify a Supabase-issued JWT using the project JWT secret."""
    try:
        payload = pyjwt.decode(
            token,
            SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        return payload
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except pyjwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


def _profile_from_jwt(payload: dict[str, Any]) -> dict[str, Any]:
    """
    Extract user identity from Supabase JWT payload.
    Supabase stores the user's UUID in `sub` and app-level metadata
    (like `role`) in `user_metadata` or `app_metadata`.
    """
    uid: str = payload.get("sub", "")
    if not uid:
        raise HTTPException(status_code=401, detail="Token missing subject")

    # Fetch user profile row from public.profiles table
    resp = supa().table("profiles").select("*").eq("id", uid).single().execute()
    if not resp.data:
        raise HTTPException(status_code=401, detail="User profile not found")
    return resp.data


def current_user(authorization: Optional[str] = Header(default=None)) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Bearer access token required")
    token = authorization.split(" ", 1)[1].strip()
    payload = _verify_supabase_jwt(token)
    return _profile_from_jwt(payload)


def require_teacher(user: dict[str, Any]) -> None:
    if user.get("role") != "teacher":
        raise HTTPException(status_code=403, detail="Teacher role required")


# ── Pydantic schemas ──────────────────────────────────────────────────────────
class CreateSessionRequest(BaseModel):
    class_id: str  # UUID


class AttendanceUpdate(BaseModel):
    status: str = Field(pattern="^(present|absent|pending)$")
    note: Optional[str] = Field(default=None, max_length=500)


class FinalizeRequest(BaseModel):
    mark_pending_absent: bool


# ── Lifespan ──────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(_: FastAPI):
    # Verify Supabase connectivity on startup
    try:
        supa().table("profiles").select("id").limit(1).execute()
    except Exception as exc:
        raise RuntimeError(f"Cannot connect to Supabase: {exc}") from exc
    yield


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
        "finalized_at": row.get("finalized_at"),
    }
    if user["role"] == "teacher":
        att = (
            supa()
            .table("attendance")
            .select("*, profiles(name, email)")
            .eq("session_id", row["id"])
            .order("profiles(name)")
            .execute()
        )
        entries = []
        for e in att.data or []:
            flat = {**e}
            if isinstance(e.get("profiles"), dict):
                flat["name"] = e["profiles"]["name"]
                flat["email"] = e["profiles"]["email"]
                flat.pop("profiles", None)
            entries.append(flat)
        result["attendance"] = entries

        sugg = (
            supa()
            .table("suggestions")
            .select("*, profiles(name)")
            .eq("session_id", row["id"])
            .order("id")
            .execute()
        )
        slist = []
        for s in sugg.data or []:
            flat = {**s}
            if isinstance(s.get("profiles"), dict):
                flat["name"] = s["profiles"]["name"]
                flat.pop("profiles", None)
            slist.append(flat)
        result["suggestions"] = slist
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


# NOTE: Login/signup are handled entirely by Supabase Auth.
# The Flutter app calls supabase.auth.signIn directly.
# The backend never handles passwords – it only validates the JWT the
# Supabase SDK returns to the client.

@app.get("/api/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {"id": user["id"], "name": user["name"], "email": user["email"], "role": user["role"]}


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
        rows.append(flat)
    return rows


@app.post("/api/sessions")
def create_session(
    body: CreateSessionRequest, user: dict[str, Any] = Depends(current_user)
) -> dict[str, Any]:
    require_teacher(user)
    cls = _get_class_or_404(body.class_id)
    _assert_class_access(cls, user)
    now = utc_now()
    sess_resp = (
        supa()
        .table("sessions")
        .insert(
            {
                "class_id": body.class_id,
                "status": "open",
                "created_by": user["id"],
                "created_at": now,
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
async def capture(
    session_id: str,
    photo: UploadFile = File(...),
    user: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    require_teacher(user)
    row = _get_session_or_404(session_id)
    _assert_session_access(row, user, teacher_only=True)
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

    roster = (
        supa()
        .table("enrollments")
        .select("student_id, profiles(name)")
        .eq("class_id", row["class_id"])
        .execute()
    )
    audit_count_resp = (
        supa()
        .table("audit_log")
        .select("id", count="exact")
        .eq("session_id", session_id)
        .eq("action", "capture.received")
        .execute()
    )
    capture_number = (audit_count_resp.count or 0) + 1
    now = utc_now()
    suggestions = []
    sugg_rows = []
    for index, entry in enumerate(roster.data or []):
        student_id = entry["student_id"]
        name = entry.get("profiles", {}).get("name", "Student") if entry.get("profiles") else "Student"
        confidence = round(min(0.98, 0.70 + ((len(data) + capture_number * 17 + index * 11) % 25) / 100), 2)
        sugg_rows.append(
            {
                "session_id": session_id,
                "student_id": student_id,
                "confidence": confidence,
                "label": "simulated",
                "created_at": now,
            }
        )
        suggestions.append(
            {"student_id": student_id, "name": name, "confidence": confidence, "status": "suggestion", "label": "simulated"}
        )
    if sugg_rows:
        supa().table("suggestions").insert(sugg_rows).execute()

    _audit(session_id, user["id"], "capture.received",
           note="Capture processed for synthetic suggestions; not persisted by application.",
           metadata={"bytes_read": len(data)})
    _audit(session_id, user["id"], "suggestion.generated",
           note="Synthetic suggestions; teacher review required.",
           metadata={"count": len(suggestions), "synthetic": True})

    return {
        "session_id": session_id,
        "simulated": True,
        "message": "Synthetic suggestions only. Review and save attendance manually; no image was stored.",
        "suggestions": suggestions,
    }


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
    if row["status"] != "open":
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
        .select("student_id, status, note, updated_at, profiles(name)")
        .eq("session_id", session_id)
        .eq("student_id", student_id)
        .single()
        .execute()
    )
    result = {**changed.data}
    if isinstance(result.get("profiles"), dict):
        result["name"] = result["profiles"]["name"]
        result.pop("profiles", None)

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
    if row["status"] != "open":
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
        .select("status, note, updated_at, profiles(name, email)")
        .eq("session_id", session_id)
        .order("profiles(name)")
        .execute()
    )
    entries = []
    for e in entries_resp.data or []:
        flat = {**e}
        if isinstance(e.get("profiles"), dict):
            flat["name"] = e["profiles"]["name"]
            flat["email"] = e["profiles"]["email"]
            flat.pop("profiles", None)
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
