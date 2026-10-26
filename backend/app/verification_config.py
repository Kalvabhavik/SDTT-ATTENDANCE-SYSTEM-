"""Documented defaults for the ordered classroom sweep checks.

These are operational thresholds, not claims of biometric accuracy. Keep them
centralized so deployments can tune them using consented device evidence.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class VerificationConfig:
    minimum_frames: int = 12
    capture_min_seconds: float = 4.0
    capture_max_seconds: float = 15.0
    maximum_heading_gap_degrees: float = 25.0
    minimum_heading_span_degrees: float = 150.0
    self_pass_similarity: float = 0.72
    self_review_similarity: float = 0.50
    minimum_neighbours: int = 1
    maximum_neighbour_distance_face_widths: float = 3.0
    minimum_inter_pupil_pixels: float = 30.0
    submission_grace_seconds: int = 5
    maximum_attempts_per_student: int = 3
    flagged_evidence_retention_days: int = 7
    maximum_upload_bytes: int = 20 * 1024 * 1024
    maximum_frames: int = 90
    minimum_width: int = 320
    minimum_height: int = 240
    minimum_laplacian_variance: float = 45.0
    minimum_brightness: float = 35.0
    maximum_brightness: float = 220.0


DEFAULTS = VerificationConfig()
