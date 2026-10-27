"""Tests for Active Liveness Detection: Turn Left, Turn Right, and Eye Blink."""
from __future__ import annotations

import io
import os
import sys
from pathlib import Path
import numpy as np

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))
os.environ["ATTENDANCE_ENV"] = "test"
os.environ["SUPABASE_JWT_SECRET"] = "test_jwt_secret_must_be_at_least_32_chars_long"
os.environ["ATTENDANCE_SECRET_KEY"] = "test_biometric_encryption_key_32_chars!"

from app.face_engine import RealFaceEngine, FaceDetection
from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def _create_mock_face(yaw_offset: int = 0, is_blink: bool = False) -> np.ndarray:
    """Create a 320x320 mock image with distinct face geometry."""
    img = np.full((320, 320, 3), 120, dtype=np.uint8)
    # Head contour
    cx, cy = 160 + yaw_offset, 160
    # Eyes
    re_x, re_y = cx - 40, cy - 30
    le_x, le_y = cx + 40, cy - 30
    # Nose
    nose_x, nose_y = cx, cy + 10
    # Mouth
    m1_x, m1_y = cx - 30, cy + 50
    m2_x, m2_y = cx + 30, cy + 50

    if not is_blink:
        # High contrast eyes
        img[re_y-8:re_y+8, re_x-12:re_x+12] = 20
        img[le_y-8:le_y+8, le_x-12:le_x+12] = 20
    else:
        # Closed eyes (smooth skin)
        img[re_y-2:re_y+2, re_x-12:re_x+12] = 90
        img[le_y-2:le_y+2, le_x-12:le_x+12] = 90

    # Nose texture
    img[nose_y-5:nose_y+5, nose_x-5:nose_x+5] = 40
    # Mouth texture
    img[m1_y-4:m1_y+4, m1_x:m2_x] = 50
    return img


def test_active_liveness_engine():
    engine = RealFaceEngine()

    frontal = _create_mock_face(yaw_offset=0, is_blink=False)
    turn_left = _create_mock_face(yaw_offset=-25, is_blink=False)
    turn_right = _create_mock_face(yaw_offset=25, is_blink=False)
    blink = _create_mock_face(yaw_offset=0, is_blink=True)

    res = engine.verify_active_liveness(
        frontal_img=frontal,
        left_img=turn_left,
        right_img=turn_right,
        blink_img=blink,
    )

    assert "liveness_passed" in res
    assert "frontal_detected" in res
    assert "left_turn_detected" in res
    assert "right_turn_detected" in res
    assert "blink_detected" in res
    assert res["frontal_detected"] is True
