"""Automated QA & Integration Tests: Teacher Dashboard, Report Consistency, and Excel Exports.

Tests Category 10:
1. Session summary statistics and mathematical consistency.
2. Master campus analytics report Excel (.xlsx) streaming generation and cell accuracy.
3. Session-specific Excel report export and cell formatting.
4. Lecturer manual review, status override, and audit trail generation.
5. Role scoping: teachers receive only owned analytics; students forbidden.
"""
from __future__ import annotations

import io
import os
import sys
from pathlib import Path
from typing import Any

import openpyxl
import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"

from app.main import app
from app.db import supa, reset_test_db
from app.security import create_access_token

client = TestClient(app)

TEACHER_ID = "00000000-0000-0000-0000-000000000001"
STUDENT_1_ID = "00000000-0000-0000-0000-000000000002"
STUDENT_2_ID = "00000000-0000-0000-0000-000000000003"
STUDENT_3_ID = "00000000-0000-0000-0000-000000000004"
CLASS_ID = "c0000000-0000-0000-0000-000000000001"
SESSION_ID = "s0000000-0000-0000-0000-000000000001"


@pytest.fixture(autouse=True)
def setup_dashboard_suite():
    reset_test_db()
    db = supa()

    # Seed profiles
    db.table("profiles").insert([
        {
            "id": TEACHER_ID,
            "name": "Prof. Alan Turing",
            "email": "teacher@demo.edu",
            "role": "teacher",
            "is_active": True,
        },
        {
            "id": STUDENT_1_ID,
            "name": "Alice Smith",
            "email": "alice@demo.edu",
            "roll_number": "CS-001",
            "role": "student",
            "is_active": True,
        },
        {
            "id": STUDENT_2_ID,
            "name": "Bob Jones",
            "email": "bob@demo.edu",
            "roll_number": "CS-002",
            "role": "student",
            "is_active": True,
        },
        {
            "id": STUDENT_3_ID,
            "name": "Charlie Brown",
            "email": "charlie@demo.edu",
            "roll_number": "CS-003",
            "role": "student",
            "is_active": True,
        },
    ]).execute()

    # Seed class owned by Teacher
    db.table("classes").insert({
        "id": CLASS_ID,
        "name": "Distributed Systems",
        "code": "CS-401",
        "teacher_id": TEACHER_ID,
        "capacity": 60,
    }).execute()

    # Enroll students
    db.table("class_enrollments").insert([
        {"class_id": CLASS_ID, "student_id": STUDENT_1_ID},
        {"class_id": CLASS_ID, "student_id": STUDENT_2_ID},
        {"class_id": CLASS_ID, "student_id": STUDENT_3_ID},
    ]).execute()

    # Seed open session
    db.table("sessions").insert({
        "id": SESSION_ID,
        "class_id": CLASS_ID,
        "status": "open",
        "created_by": TEACHER_ID,
        "starts_at": "2026-10-27T10:00:00Z",
        "ends_at": "2026-10-27T10:30:00Z",
    }).execute()

    # Seed initial attendance: Alice is present, Bob is pending review, Charlie is absent
    db.table("attendance").insert([
        {
            "session_id": SESSION_ID,
            "student_id": STUDENT_1_ID,
            "status": "present",
            "note": "Biometric ArcFace match (92%)",
            "attempted": True,
        },
        {
            "session_id": SESSION_ID,
            "student_id": STUDENT_2_ID,
            "status": "pending",
            "note": "Ambiguous match (41%) - flagged for lecturer review",
            "attempted": True,
        },
        {
            "session_id": SESSION_ID,
            "student_id": STUDENT_3_ID,
            "status": "absent",
            "note": "Unexcused absence - did not scan",
            "attempted": False,
        },
    ]).execute()


def test_session_summary_mathematical_consistency():
    """Verify session summary counts accurately match attendance records and sum to total enrolled."""
    token = create_access_token(TEACHER_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")
    res = client.get(f"/api/sessions/{SESSION_ID}", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    counts = data.get("summary", {})

    assert counts.get("present") == 1  # Ada Lovelace
    assert counts.get("pending") == 1  # Grace Hopper
    assert counts.get("absent") == 1   # Third student
    assert counts.get("total") == 3
    assert counts["present"] + counts["pending"] + counts["absent"] == counts["total"]


def test_master_analytics_excel_export_format_and_data_integrity():
    """Verify master analytics Excel export streams valid .xlsx with sheets and correct cell counts."""
    token = create_access_token(TEACHER_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")
    res = client.get("/api/reports/analytics/excel", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    # Verify content headers
    assert "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" in res.headers["content-type"]
    assert "attachment" in res.headers.get("content-disposition", "")

    # Verify binary ZIP header
    content = res.content
    assert content.startswith(b"PK\x03\x04"), "Excel file must have standard PK ZIP signature"

    # Load with openpyxl and verify sheets
    wb = openpyxl.load_workbook(io.BytesIO(content))
    sheet_names = wb.sheetnames
    assert "Executive Summary" in sheet_names
    assert "Student Roster Analytics" in sheet_names
    assert "System Audit Trail" in sheet_names

    # Check Executive Summary sheet
    ws_exec = wb["Executive Summary"]
    assert ws_exec["A1"].value == "CAMPUS ATTENDANCE MASTER ANALYTICS & AUDIT REPORT"

    # Scan KPI metrics in Executive Summary
    kpi_values = {}
    for row in range(4, 15):
        k = ws_exec.cell(row=row, column=1).value
        v = ws_exec.cell(row=row, column=2).value
        if k:
            kpi_values[k] = v

    assert kpi_values.get("Verified Present Count") == 1
    assert kpi_values.get("Unexcused Absent Count") == 1
    assert kpi_values.get("Flagged for Review") == 1


def test_session_specific_excel_export():
    """Verify session-specific Excel export generates formatted student attendance ledger."""
    token = create_access_token(TEACHER_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")
    res = client.get(f"/api/sessions/{SESSION_ID}/export/excel", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    assert res.content.startswith(b"PK\x03\x04")

    wb = openpyxl.load_workbook(io.BytesIO(res.content))
    ws = wb.active
    assert "Attendance Analytics" in ws.title

    # Data rows start at row 8: col 2 is Roll Number, col 3 is Student Name, col 5 is Status
    student_rows = {}
    for r in range(8, 20):
        roll = ws.cell(row=r, column=2).value
        name = ws.cell(row=r, column=3).value
        status = ws.cell(row=r, column=5).value
        if name:
            student_rows[name] = {"roll": roll, "status": status}

    assert "Ada Lovelace" in student_rows
    assert student_rows["Ada Lovelace"]["status"] == "PRESENT"


def test_teacher_manual_override_reconciliation_and_audit():
    """Verify lecturer can manually override attendance, updating status and creating audit log."""
    token = create_access_token(TEACHER_ID, "teacher@demo.edu", "teacher", "Prof. Alan Turing")

    # Override Grace Hopper (STUDENT_2_ID) from pending to present
    patch_res = client.patch(
        f"/api/sessions/{SESSION_ID}/attendance/{STUDENT_2_ID}",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "status": "present",
            "note": "Lecturer manual review: Student verified in front row seat 12",
        },
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["status"] == "present"

    # Verify session API immediately reflects the change
    sum_res = client.get(f"/api/sessions/{SESSION_ID}", headers={"Authorization": f"Bearer {token}"})
    assert sum_res.status_code == 200
    sum_data = sum_res.json()
    counts = sum_data.get("summary", {})
    assert counts["present"] == 2  # Ada Lovelace + Grace Hopper
    assert counts["pending"] == 0  # Grace Hopper cleared from pending

    # Verify audit log recorded the lecturer override
    audit_res = client.get("/api/audit", headers={"Authorization": f"Bearer {token}"})
    assert audit_res.status_code == 200
    audits = audit_res.json()
    override_entries = [a for a in audits if "manual" in a.get("note", "").lower() or "override" in a.get("note", "").lower() or a.get("action") == "attendance.status_updated"]
    assert len(override_entries) > 0




def test_student_forbidden_from_dashboard_and_export():
    """Verify student role is strictly rejected with HTTP 403 from lecturer exports and overrides."""
    s_token = create_access_token(STUDENT_1_ID, "alice@demo.edu", "student", "Alice Smith")
    s_headers = {"Authorization": f"Bearer {s_token}"}

    # 1. Excel export forbidden
    res_export = client.get("/api/reports/analytics/excel", headers=s_headers)
    assert res_export.status_code == 403

    # 2. Session excel export forbidden
    res_sess_export = client.get(f"/api/sessions/{SESSION_ID}/export/excel", headers=s_headers)
    assert res_sess_export.status_code == 403

    # 3. Manual override forbidden
    res_override = client.patch(
        f"/api/sessions/{SESSION_ID}/attendance/{STUDENT_2_ID}",
        headers=s_headers,
        json={"status": "present"},
    )
    assert res_override.status_code == 403
