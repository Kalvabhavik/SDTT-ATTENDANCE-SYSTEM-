from __future__ import annotations

import cv2
import numpy as np

from app.verification_pipeline import analyze_sweep, decide, hash_distance
from app.verification_config import DEFAULTS


class DeterministicTestEngine:
    """Test-only fake; production constructs YuNetArcFaceEngine from licensed ONNX files."""
    model_version = "unit-test-model"
    def __init__(self, lecturer_face=True, lecturer_identifiable=True, blur=100.0,
                 width=640, height=480, brightness=120.0, self_embedding=None):
        self.index = 0
        self.lecturer_face = lecturer_face
        self.lecturer_identifiable = lecturer_identifiable
        self.blur = blur
        self.width = width
        self.height = height
        self.brightness = brightness
        self.self_embedding = self_embedding or [1, 0, 0]
    def analyze(self, _image_bytes):
        index = self.index
        self.index += 1
        faces = []
        if index <= 2:
            faces = [
                {"bbox": [30, 30, 40, 50], "embedding": self.self_embedding, "inter_pupil_pixels": 36, "quality": 0.95},
                {"bbox": [85, 35, 25, 35], "embedding": [0, 1, 0], "inter_pupil_pixels": 21, "quality": 0.90},
            ]
        elif index >= 10 and self.lecturer_face:
            faces = [{"bbox": [80, 30, 45, 55], "embedding": [0, 0, 1],
                      "inter_pupil_pixels": 36 if self.lecturer_identifiable else 12, "quality": 0.9}]
        return {"width": self.width, "height": self.height, "brightness": self.brightness,
                "laplacian_variance": self.blur, "faces": faces, "person_detected": bool(faces)}


def frames():
    rng = np.random.default_rng(19)
    image = rng.integers(0, 256, (240, 320), dtype=np.uint8)
    ok, encoded = cv2.imencode(".jpg", image)
    assert ok
    raw = encoded.tobytes()
    inputs = [{"offset_seconds": i * (10 / 12), "heading_degrees": i * 15} for i in range(13)]
    return inputs, [raw] * 13


def run(engine):
    inputs, data = frames()
    facts = analyze_sweep(inputs, data, 10, [1, 0, 0], [0, 0, 1], engine)
    return facts, decide(facts["rules"])


def test_pipeline_accepts_all_ordered_rules_only_when_each_passes():
    facts, decision = run(DeterministicTestEngine())
    assert decision["status"] == "verified"
    assert facts["rules"]["image_quality"].passed is True
    assert facts["rules"]["self_match"].passed is True
    assert facts["rules"]["neighbours"].passed is True
    assert facts["rules"]["lecturer_visible"].passed is True
    assert set(("frame_count", "duration", "heading_monotonic", "heading_gap", "heading_span", "visual_continuity")) <= facts["rules"].keys()


def test_pipeline_flags_a_visible_but_unidentifiable_lecturer():
    facts, decision = run(DeterministicTestEngine(lecturer_identifiable=False))
    assert facts["rules"]["lecturer_visible"].reason_code == "review.lecturer_face_too_small"
    assert decision["status"] == "flagged"


def test_pipeline_rejects_missing_lecturer_and_asks_retake_for_low_quality():
    missing, rejected = run(DeterministicTestEngine(lecturer_face=False))
    assert missing["rules"]["lecturer_visible"].reason_code == "reject.lecturer_not_visible"
    assert rejected["status"] == "rejected"
    low_quality, flagged = run(DeterministicTestEngine(blur=2.0))
    assert low_quality["rules"]["image_quality"].reason_code == "review.image_quality_retake"
    assert flagged["status"] == "flagged"


def test_phash_distance_duplicate_signal_threshold_inputs():
    assert hash_distance("11110000", "11110000") == 0
    assert hash_distance("11110000", "00001111") == 8
    assert DEFAULTS.minimum_inter_pupil_pixels == 30


def test_pipeline_flags_self_match_uncertainty_and_retake_quality_bounds():
    uncertain_embedding = [0.65, (1 - 0.65 ** 2) ** 0.5, 0]
    uncertain, decision = run(DeterministicTestEngine(self_embedding=uncertain_embedding))
    assert uncertain["rules"]["self_match"].reason_code == "review.self_match_uncertain"
    assert decision["status"] == "flagged"
    for engine in (
        DeterministicTestEngine(width=200),
        DeterministicTestEngine(height=180),
        DeterministicTestEngine(brightness=20),
        DeterministicTestEngine(brightness=235),
    ):
        facts, outcome = run(engine)
        assert facts["rules"]["image_quality"].passed is None
        assert facts["rules"]["image_quality"].reason_code == "review.image_quality_retake"
        assert outcome["status"] == "flagged"
