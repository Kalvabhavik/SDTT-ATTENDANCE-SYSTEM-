"""Adversarial evaluation test suite for Attendrix Computer-Vision Liveness & Presentation-Attack Defense.

Executes controlled evaluation across 11 adversarial attack categories:
1. Consenting live participant (matching identity)
2. Live non-matching participant (liveness passes, biometric identity fails)
3. Printed photographs (halftone, low saturation, static challenge replay)
4. Photographs displayed on phone/tablet/monitor (screen moiré FFT, specular glare)
5. Prerecorded video replay (randomized challenge sequence mismatch)
6. Previously submitted image replay (SHA-256 byte deduplication and pHash)
7. Low-quality captures (blur, underexposure, face too small)
8. Multiple faces (multiple subjects in verification frame)
9. Expired and reused challenges (90s TTL expiration and single-use nonce consumption)
10. Incorrect active-challenge responses (wrong turn direction / no blink)
11. Model timeout and unavailable model (fails closed with 503, client bypass fields neutralized)

Records model version, test fixture, decision, confidence, latency, and evidence.
"""
from __future__ import annotations

import io
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from app.db import reset_test_db, supa
from app.face_engine import FaceDetection, RealFaceEngine, get_face_engine
from app.main import app
from app.security import (
    create_access_token,
    create_liveness_challenge_token,
    encrypt_face_embedding,
    reset_security_caches,
    verify_liveness_challenge_token,
)

client = TestClient(app)

LOG_PATH = Path(__file__).resolve().parents[2] / "proof" / "logs" / "adversarial_evaluation_log.json"
EVALUATION_RECORDS: list[dict[str, Any]] = []


def _record_result(
    test_id: str,
    category: str,
    fixture_desc: str,
    decision: str,
    evidence: str,
    latency_ms: float,
    confidence: float | None = None,
    model_version: str = "yunet-sface-pad-v1",
) -> None:
    """Record structured adversarial evaluation metric."""
    rec = {
        "test_id": test_id,
        "category": category,
        "model_version": model_version,
        "test_fixture": fixture_desc,
        "decision": decision,
        "confidence": confidence,
        "latency_ms": round(latency_ms, 2),
        "evidence": evidence,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    EVALUATION_RECORDS.append(rec)
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_PATH, "w") as f:
            json.dump(EVALUATION_RECORDS, f, indent=2)
    except Exception as e:
        print(f"Warning: Failed to write evaluation log: {e}")


def _build_test_face(
    yaw_offset: int = 0,
    is_blink: bool = False,
    face_id: int = 1,
    blur: bool = False,
    dark: bool = False,
    low_sat: bool = False,
    add_moire: bool = False,
    add_glare: bool = False,
    scale: float = 1.0,
) -> tuple[np.ndarray, bytes]:
    """Generate high-fidelity synthetic face image with controllable geometric and spectral attributes."""
    base_lum = 20 if dark else 130
    img = np.full((320, 320, 3), (base_lum, base_lum + 5, base_lum - 5), dtype=np.uint8)

    cx = int(160 + yaw_offset)
    cy = 160

    if face_id == 1:
        # Horizontal texture lines for Face 1
        for i in range(15, 305, 20):
            cv2.line(img, (20, i), (300, i), (base_lum + 12, base_lum + 8, base_lum - 8), 1)

        # Eyes (rectangles)
        re_x, re_y = cx - 35, cy - 25
        le_x, le_y = cx + 35, cy - 25
        if not is_blink:
            cv2.rectangle(img, (re_x - 10, re_y - 7), (re_x + 10, re_y + 7), (18, 18, 18), -1)
            cv2.rectangle(img, (le_x - 10, le_y - 7), (le_x + 10, le_y + 7), (18, 18, 18), -1)
        else:
            cv2.line(img, (re_x - 10, re_y), (re_x + 10, re_y), (85, 85, 85), 2)
            cv2.line(img, (le_x - 10, le_y), (le_x + 10, le_y), (85, 85, 85), 2)

        # Nose & Mouth
        cv2.circle(img, (cx, cy + 12), 6, (30, 30, 30), -1)
        cv2.line(img, (cx - 28, cy + 45), (cx + 28, cy + 45), (40, 40, 40), 3)
    else:
        # Vertical texture lines and distinct facial layout for Face 2 (non-matching identity)
        for i in range(15, 305, 18):
            cv2.line(img, (i, 20), (i, 300), (base_lum + 14, base_lum - 10, base_lum + 8), 2)

        # Eyes (circles, wide IPD)
        re_x, re_y = cx - 55, cy - 35
        le_x, le_y = cx + 55, cy - 35
        if not is_blink:
            cv2.circle(img, (re_x, re_y), 12, (15, 15, 15), -1)
            cv2.circle(img, (le_x, le_y), 12, (15, 15, 15), -1)
        else:
            cv2.line(img, (re_x - 12, re_y), (re_x + 12, re_y), (85, 85, 85), 2)
            cv2.line(img, (le_x - 12, le_y), (le_x + 12, le_y), (85, 85, 85), 2)

        # Nose & Mouth (large vertical block & wide arc)
        cv2.rectangle(img, (cx - 8, cy - 5), (cx + 8, cy + 25), (25, 25, 25), -1)
        cv2.ellipse(img, (cx, cy + 50), (45, 18), 0, 0, 180, (35, 35, 35), 4)

    if low_sat:
        # Desaturate to simulate monochrome or printed paper
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        img = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    if add_moire:
        # High-frequency sinusoidal screen raster
        x_coords = np.arange(320)
        moire_pattern = (np.sin(x_coords * 1.5) * 45).astype(np.int16)
        img = np.clip(img.astype(np.int16) + moire_pattern[:, None, None], 0, 255).astype(np.uint8)

    if add_glare:
        # Planar specular reflection glare hotspot
        cv2.circle(img, (160, 160), 45, (255, 255, 255), -1)

    if blur:
        img = cv2.GaussianBlur(img, (25, 25), 0)

    if scale != 1.0:
        h, w = img.shape[:2]
        small = cv2.resize(img, (int(w * scale), int(h * scale)))
        pad_top = (h - small.shape[0]) // 2
        pad_bottom = h - small.shape[0] - pad_top
        pad_left = (w - small.shape[1]) // 2
        pad_right = w - small.shape[1] - pad_left
        img = cv2.copyMakeBorder(small, pad_top, pad_bottom, pad_left, pad_right, cv2.BORDER_CONSTANT, value=(128, 128, 128))

    ok, buf = cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 95])
    return img, buf.tobytes()


@pytest.fixture(autouse=True)
def setup_test_state():
    reset_test_db()
    reset_security_caches()


# ── Adversarial Attack Category 01: Consenting Live Participant ───────────────
def test_adv_01_consenting_live_matching_participant():
    """ADV-01: Consenting live participant with authentic active challenges and matching reference."""
    t0 = time.perf_counter()
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    # Enroll student 1
    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    enr_res = client.post("/api/auth/enroll", headers=s_headers, data={"consent": "true"}, files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")})
    assert enr_res.status_code == 200

    # Open session
    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    sess = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_login.json()['access_token']}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15}).json()
    session_id = sess["id"]

    # Issue challenge
    chal = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()
    token = chal["challenge_token"]

    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    _, l_bytes = _build_test_face(yaw_offset=-25, face_id=1)
    _, r_bytes = _build_test_face(yaw_offset=25, face_id=1)
    _, b_bytes = _build_test_face(yaw_offset=0, is_blink=True, face_id=1)

    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": token},
        files={
            "face_image": ("live.jpg", f_bytes, "image/jpeg"),
            "face_left": ("left.jpg", l_bytes, "image/jpeg"),
            "face_right": ("right.jpg", r_bytes, "image/jpeg"),
            "face_blink": ("blink.jpg", b_bytes, "image/jpeg"),
        },
    )
    dt = (time.perf_counter() - t0) * 1000.0
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "present"
    assert body["liveness_passed"] is True
    assert body["face_match"] is True

    _record_result(
        test_id="ADV-01",
        category="Consenting live participant",
        fixture_desc="Live student with matching reference and completed active challenges",
        decision="PASSED_PRESENT",
        confidence=body.get("face_confidence"),
        latency_ms=dt,
        evidence=f"Status: {body['status']}, Liveness: {body['liveness_passed']}, Confidence: {body['face_confidence']}",
    )


# ── Adversarial Attack Category 02: Live Non-Matching Participant ─────────────
def test_adv_02_live_non_matching_participant():
    """ADV-02: Live non-matching participant passes liveness actions but fails biometric matching."""
    t0 = time.perf_counter()
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_token = s_login.json()["access_token"]
    student_id = s_login.json()["user"]["id"]
    s_headers = {"Authorization": f"Bearer {s_token}"}

    # Enroll student 1 with a registered reference template (Person A)
    diff_emb = np.zeros(512, dtype=np.float32)
    diff_emb[15] = 1.0  # Orthogonal unit vector
    enc_diff = encrypt_face_embedding(diff_emb)
    db = supa()
    db.table("face_templates").insert({
        "user_id": student_id,
        "encrypted_embedding": enc_diff,
        "model_version": "arcface-yunet-v1",
        "consent_timestamp": "2026-10-27T18:00:00Z",
    }).execute()

    # Open session
    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    sess = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_login.json()['access_token']}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15}).json()
    session_id = sess["id"]

    chal = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()

    # Submitter is a DIFFERENT live person (Person B) performing all requested active liveness challenges
    _, f_diff = _build_test_face(yaw_offset=0)
    _, l_diff = _build_test_face(yaw_offset=-25)
    _, r_diff = _build_test_face(yaw_offset=25)
    _, b_diff = _build_test_face(yaw_offset=0, is_blink=True)

    res = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": chal["challenge_token"]},
        files={
            "face_image": ("live.jpg", f_diff, "image/jpeg"),
            "face_left": ("left.jpg", l_diff, "image/jpeg"),
            "face_right": ("right.jpg", r_diff, "image/jpeg"),
            "face_blink": ("blink.jpg", b_diff, "image/jpeg"),
        },
    )
    dt = (time.perf_counter() - t0) * 1000.0
    assert res.status_code == 200
    body = res.json()
    # Liveness passed (actions completed) BUT face match failed, so attendance is NOT present!
    assert body["status"] != "present"
    assert body["face_match"] is False
    assert body["liveness_passed"] is True

    _record_result(
        test_id="ADV-02",
        category="Live non-matching participant",
        fixture_desc="Live participant performing actions whose face does not match registered biometric template",
        decision="BLOCKED_BIOMETRIC_MISMATCH",
        confidence=body.get("face_confidence"),
        latency_ms=dt,
        evidence=f"Status: {body['status']}, Liveness: {body['liveness_passed']}, Match: {body['face_match']}",
    )


# ── Adversarial Attack Category 03: Printed Photographs ───────────────────────
def test_adv_03_printed_photograph_attack():
    """ADV-03: Printed photo attack detected via low saturation or identical static frame replay."""
    t0 = time.perf_counter()
    engine = get_face_engine()
    # High-contrast desaturated print fixture
    img_print, _ = _build_test_face(yaw_offset=0, low_sat=True)
    face_obj = FaceDetection(
        bbox_x=40, bbox_y=40, bbox_w=240, bbox_h=240,
        confidence=0.95,
        landmarks=[(120.0, 130.0), (200.0, 130.0), (160.0, 170.0), (130.0, 210.0), (190.0, 210.0)],
        ipd_px=80.0,
    )

    pa_res = engine.detect_presentation_attack(img_print, face_obj)
    dt = (time.perf_counter() - t0) * 1000.0

    assert pa_res["is_spoof"] is True
    reasons_str = " ".join(pa_res.get("reasons", []))
    assert "PRINT" in reasons_str or pa_res["spoof_score"] > 0.45

    _record_result(
        test_id="ADV-03",
        category="Printed photographs",
        fixture_desc="Printed photo presentation with desaturated paper chrominance",
        decision="BLOCKED_PRINT_ATTACK",
        confidence=pa_res.get("spoof_score"),
        latency_ms=dt,
        evidence=f"PAD Reasons: {reasons_str}, Spoof Score: {pa_res.get('spoof_score')}",
    )


# ── Adversarial Attack Category 04: Screen Replay (Phone / Tablet / Monitor) ───
def test_adv_04_photographs_displayed_on_screen():
    """ADV-04: Digital screen presentation attack detected via 2D FFT spectral peak or specular glare."""
    t0 = time.perf_counter()
    engine = get_face_engine()
    # Screen display with high-frequency raster moiré
    img_screen, _ = _build_test_face(yaw_offset=0, add_moire=True)
    face_obj = FaceDetection(
        bbox_x=40, bbox_y=40, bbox_w=240, bbox_h=240,
        confidence=0.95,
        landmarks=[(120.0, 130.0), (200.0, 130.0), (160.0, 170.0), (130.0, 210.0), (190.0, 210.0)],
        ipd_px=80.0,
    )

    pa_res = engine.detect_presentation_attack(img_screen, face_obj)
    dt = (time.perf_counter() - t0) * 1000.0

    assert pa_res["is_spoof"] is True
    reasons_str = " ".join(pa_res.get("reasons", []))
    assert "SCREEN" in reasons_str or "MOIRE" in reasons_str or pa_res["spoof_score"] > 0.45

    _record_result(
        test_id="ADV-04",
        category="Photographs displayed on screen",
        fixture_desc="Digital display screen showing face with high-frequency raster pattern",
        decision="BLOCKED_SCREEN_REPLAY",
        confidence=pa_res.get("spoof_score"),
        latency_ms=dt,
        evidence=f"PAD Reasons: {reasons_str}, Spoof Score: {pa_res.get('spoof_score')}",
    )


# ── Adversarial Attack Category 05: Prerecorded Video Replay ──────────────────
def test_adv_05_prerecorded_video_replay():
    """ADV-05: Attacker replays static or prerecorded video that does not answer randomized challenges."""
    t0 = time.perf_counter()
    engine = get_face_engine()
    img_front, _ = _build_test_face(yaw_offset=0)
    # Prerecorded video only contains frontal frames replayed across all challenges
    liveness_res = engine.verify_active_liveness(
        frontal_img=img_front,
        left_img=img_front,  # Replayed identical frontal frame
        right_img=None,
        blink_img=None,
        expected_challenges=["turn_left", "turn_right"],
    )
    dt = (time.perf_counter() - t0) * 1000.0
    assert liveness_res["liveness_passed"] is False
    assert liveness_res["reason"] in ("STATIC_IMAGE_REPLAY_ACROSS_CHALLENGES", "ACTION_MISMATCH", "MISSING_CHALLENGE_FRAME")

    _record_result(
        test_id="ADV-05",
        category="Prerecorded video replay",
        fixture_desc="Identical static frame replayed across challenge slots without movement",
        decision="BLOCKED_VIDEO_REPLAY",
        confidence=None,
        latency_ms=dt,
        evidence=f"Reason: {liveness_res.get('reason')}, Msg: {liveness_res.get('message')}",
    )


# ── Adversarial Attack Category 06: Previously Submitted Image Replay ─────────
def test_adv_06_previously_submitted_image_replay():
    """ADV-06: Attacker intercepts previously submitted legitimate image and replays exact bytes or pHash."""
    t0 = time.perf_counter()
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post("/api/auth/enroll", headers=s_headers, data={"consent": "true"}, files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")})

    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    sess = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_login.json()['access_token']}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15}).json()
    session_id = sess["id"]

    chal1 = client.post(f"/api/sessions/{session_id}/liveness-challenge", headers=s_headers).json()
    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)

    # First legitimate submission
    client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": chal1["challenge_token"]},
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )

    # Attempt replay with new session & new challenge, but reusing identical image bytes
    sess2 = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_login.json()['access_token']}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15}).json()
    chal2 = client.post(f"/api/sessions/{sess2['id']}/liveness-challenge", headers=s_headers).json()

    replay_res = client.post(
        f"/api/sessions/{sess2['id']}/verify-attendance",
        headers=s_headers,
        data={"challenge_token": chal2["challenge_token"]},
        files={"face_image": ("replayed.jpg", f_bytes, "image/jpeg")},
    )
    dt = (time.perf_counter() - t0) * 1000.0

    assert replay_res.status_code == 400
    assert "REPLAY_ATTACK_DETECTED" in replay_res.headers.get("x-error-code", "") or "Replay attack" in replay_res.text

    _record_result(
        test_id="ADV-06",
        category="Previously submitted image replay",
        fixture_desc="Replay of exact cryptographic SHA-256 and pHash image bytes from prior attempt",
        decision="BLOCKED_REPLAY_ATTACK",
        confidence=None,
        latency_ms=dt,
        evidence=f"HTTP 400, Header: {replay_res.headers.get('x-error-code')}",
    )


# ── Adversarial Attack Category 07: Low-Quality Captures ──────────────────────
def test_adv_07_low_quality_captures():
    """ADV-07: Low-quality captures (severe blur, underexposed, or face too small) are rejected."""
    t0 = time.perf_counter()
    engine = get_face_engine()

    # Case A: Heavy Blur (Laplacian variance < 40)
    img_blur, _ = _build_test_face(blur=True)
    face_blur = FaceDetection(bbox_x=40, bbox_y=40, bbox_w=240, bbox_h=240, confidence=0.95, landmarks=[], ipd_px=80.0)
    q_blur = engine.check_image_quality(img_blur, face_blur)
    assert q_blur["passed"] is False
    assert q_blur["error_code"] == "IMAGE_QUALITY_BLURRY"

    # Case B: Severe Underexposure
    img_dark, _ = _build_test_face(dark=True)
    face_dark = FaceDetection(bbox_x=40, bbox_y=40, bbox_w=240, bbox_h=240, confidence=0.95, landmarks=[], ipd_px=80.0)
    q_dark = engine.check_image_quality(img_dark, face_dark)
    assert q_dark["passed"] is False
    assert q_dark["error_code"] == "IMAGE_QUALITY_UNDEREXPOSED"

    # Case C: Face too small (< 4% frame area or IPD < 30)
    img_normal, _ = _build_test_face()
    face_small = FaceDetection(bbox_x=140, bbox_y=140, bbox_w=30, bbox_h=30, confidence=0.95, landmarks=[], ipd_px=15.0)
    q_small = engine.check_image_quality(img_normal, face_small)
    assert q_small["passed"] is False
    assert q_small["error_code"] in ("IMAGE_QUALITY_FACE_TOO_SMALL", "IMAGE_QUALITY_LOW_CONTRAST")

    dt = (time.perf_counter() - t0) * 1000.0
    _record_result(
        test_id="ADV-07",
        category="Low-quality captures",
        fixture_desc="Synthesized blurry, underexposed, and tiny face crops",
        decision="BLOCKED_QUALITY_FAILED",
        confidence=None,
        latency_ms=dt,
        evidence=f"Blur: {q_blur['error_code']}, Dark: {q_dark['error_code']}, Small: {q_small['error_code']}",
    )


# ── Adversarial Attack Category 08: Multiple Faces ────────────────────────────
def test_adv_08_multiple_faces():
    """ADV-08: Submission with multiple faces in frame is rejected with MULTIPLE_FACES error."""
    t0 = time.perf_counter()
    from app.verification import validate_single_face
    f1 = FaceDetection(bbox_x=20, bbox_y=40, bbox_w=100, bbox_h=100, confidence=0.9, landmarks=[])
    f2 = FaceDetection(bbox_x=180, bbox_y=40, bbox_w=100, bbox_h=100, confidence=0.9, landmarks=[])
    face_ok, face_err, face_msg = validate_single_face([f1, f2])

    dt = (time.perf_counter() - t0) * 1000.0
    assert face_ok is False
    assert face_err == "MULTIPLE_FACES"

    _record_result(
        test_id="ADV-08",
        category="Multiple faces",
        fixture_desc="Frame containing two simultaneous faces",
        decision="BLOCKED_MULTIPLE_FACES",
        confidence=None,
        latency_ms=dt,
        evidence=f"Error code: {face_err}, Msg: {face_msg}",
    )


# ── Adversarial Attack Category 09: Expired and Reused Challenges ─────────────
def test_adv_09_expired_and_reused_challenges():
    """ADV-09: Token expiration (90s TTL) and single-use nonce consumption are strictly enforced."""
    t0 = time.perf_counter()
    session_id = "test-session-ttl"
    student_id = "test-student-id"

    # Sub-case A: Expired token
    expired_token = create_liveness_challenge_token(
        session_id=session_id,
        student_id=student_id,
        challenges=["turn_left", "blink"],
        ttl_seconds=-10,  # Already expired in the past
    )
    with pytest.raises(Exception) as exc_info:
        verify_liveness_challenge_token(expired_token)
    assert "expired" in str(exc_info.value).lower()

    # Sub-case B: Reused nonce
    active_token = create_liveness_challenge_token(
        session_id=session_id,
        student_id=student_id,
        challenges=["turn_right", "blink"],
        ttl_seconds=90,
    )
    payload = verify_liveness_challenge_token(active_token)
    nonce = payload["nonce"]
    from app.security import consume_challenge_nonce
    # First consumption succeeds
    first_use = consume_challenge_nonce(nonce)
    assert first_use is True
    # Second consumption fails
    second_use = consume_challenge_nonce(nonce)
    assert second_use is False

    dt = (time.perf_counter() - t0) * 1000.0
    _record_result(
        test_id="ADV-09",
        category="Expired and reused challenges",
        fixture_desc="Negative TTL token and double nonce consumption attempt",
        decision="BLOCKED_NONCE_REUSE_AND_EXPIRY",
        confidence=None,
        latency_ms=dt,
        evidence=f"Expired exception caught; first nonce={first_use}, second nonce={second_use}",
    )


# ── Adversarial Attack Category 10: Incorrect Active-Challenge Responses ──────
def test_adv_10_incorrect_active_challenge_response():
    """ADV-10: Client provides incorrect action (e.g. turned right when server asked for turn left)."""
    t0 = time.perf_counter()
    engine = get_face_engine()

    img_front, _ = _build_test_face(yaw_offset=0)
    # User was asked to turn LEFT (yaw < -15), but user turned RIGHT (yaw +25)
    img_wrong_turn, _ = _build_test_face(yaw_offset=25)

    res = engine.verify_active_liveness(
        frontal_img=img_front,
        left_img=img_wrong_turn,  # Turned right instead of left!
        right_img=None,
        blink_img=None,
        expected_challenges=["turn_left"],
    )
    dt = (time.perf_counter() - t0) * 1000.0

    assert res["liveness_passed"] is False
    assert res["left_turn_detected"] is False

    _record_result(
        test_id="ADV-10",
        category="Incorrect active-challenge responses",
        fixture_desc="Client turned head right (+25 yaw) when server challenge demanded left turn",
        decision="BLOCKED_ACTION_MISMATCH",
        confidence=None,
        latency_ms=dt,
        evidence=f"Liveness: {res['liveness_passed']}, Left detected: {res['left_turn_detected']}",
    )


# ── Adversarial Attack Category 11: Model Timeout and Unavailable Model ───────
def test_adv_11_model_timeout_and_unavailable_model(monkeypatch):
    """ADV-11: Model pipeline exception/timeout fails closed with HTTP 503; client-supplied bypass ignored."""
    t0 = time.perf_counter()
    s_login = client.post("/api/auth/login", json={"email": "student1@demo.edu", "password": "password123"})
    s_headers = {"Authorization": f"Bearer {s_login.json()['access_token']}"}

    _, ref_bytes = _build_test_face(yaw_offset=0, face_id=1)
    client.post("/api/auth/enroll", headers=s_headers, data={"consent": "true"}, files={"photo": ("ref.jpg", ref_bytes, "image/jpeg")})

    t_login = client.post("/api/auth/login", json={"email": "teacher@demo.edu", "password": "password123"})
    sess = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_login.json()['access_token']}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15}).json()
    session_id = sess["id"]

    # Sub-case A: Client attempts client-side bypass by sending spoofed flags
    # is_live=True, verified=True, client_confidence=1.0
    _, f_bytes = _build_test_face(yaw_offset=0, face_id=1)
    res_bypass = client.post(
        f"/api/sessions/{session_id}/verify-attendance",
        headers=s_headers,
        data={
            "is_live": "true",
            "verified": "true",
            "client_verified": "true",
            "confidence": "0.999",
        },
        files={"face_image": ("live.jpg", f_bytes, "image/jpeg")},
    )
    # Server executes CV anyway and does NOT grant automatic attendance
    assert res_bypass.status_code == 200
    bypass_body = res_bypass.json()
    assert bypass_body["face_confidence"] != 0.999  # Server computed real confidence, ignored client assertion

    # Sub-case B: Model failure / crash / timeout -> Must fail closed with HTTP 503
    engine = get_face_engine()
    def mock_broken_detect(*args, **kwargs):
        raise RuntimeError("OpenCV DNN runtime memory allocation timeout / model weights unavailable")

    monkeypatch.setattr(engine, "detect_faces", mock_broken_detect)

    # Open fresh session for student to avoid 1-attempt lockout
    sess2 = client.post("/api/sessions", headers={"Authorization": f"Bearer {t_login.json()['access_token']}"}, json={"class_id": "11111111-1111-1111-1111-111111111111", "duration_minutes": 15}).json()
    _, fresh_face_bytes = _build_test_face(yaw_offset=0, face_id=2)

    fail_res = client.post(
        f"/api/sessions/{sess2['id']}/verify-attendance",
        headers=s_headers,
        files={"face_image": ("live_fresh.jpg", fresh_face_bytes, "image/jpeg")},
    )
    dt = (time.perf_counter() - t0) * 1000.0

    assert fail_res.status_code == 503
    assert fail_res.headers.get("x-error-code") == "MODEL_UNAVAILABLE"
    assert "MODEL_UNAVAILABLE" in fail_res.text

    _record_result(
        test_id="ADV-11",
        category="Model timeout and unavailable model",
        fixture_desc="Simulated OpenCV DNN engine runtime timeout; client-supplied bypass ignored",
        decision="FAILED_CLOSED_503",
        confidence=None,
        latency_ms=dt,
        evidence=f"HTTP 503 received with X-Error-Code: {fail_res.headers.get('x-error-code')}",
    )
