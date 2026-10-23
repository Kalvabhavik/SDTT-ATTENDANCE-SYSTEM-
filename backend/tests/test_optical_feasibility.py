"""Tests for Phase 2 Optical Feasibility Experiment Scripts."""
import csv
import sys
from pathlib import Path

import numpy as np
import pytest

# Add experiments/optical_feasibility to path
EXP_DIR = Path(__file__).resolve().parents[2] / "experiments" / "optical_feasibility"
sys.path.insert(0, str(EXP_DIR))

import run_experiment
import summarize_results


def test_compute_image_metrics():
    # Uniform gray image should have variance 0 and mean equal to its value
    gray = np.full((100, 100), 128, dtype=np.uint8)
    lap_var, mean_lum = run_experiment.compute_image_metrics(gray)
    assert lap_var == 0.0
    assert mean_lum == 128.0

    # Image with high frequency checkerboard pattern should have high laplacian variance
    checker = np.indices((100, 100)).sum(axis=0) % 2 * 255
    checker = checker.astype(np.uint8)
    lap_var_ch, _ = run_experiment.compute_image_metrics(checker)
    assert lap_var_ch > 1000.0


def test_diagnose_failure():
    # Detected == expected -> None
    assert run_experiment.diagnose_failure(1, 1, 10.0, 100.0, 120.0) is None

    # Motion blur when laplacian_var < 35.0
    assert run_experiment.diagnose_failure(1, 0, 5.0, 20.0, 120.0) == "MOTION_BLUR"

    # Underexposure when luminance < 30.0
    assert run_experiment.diagnose_failure(1, 0, 5.0, 100.0, 15.0) == "UNDEREXPOSURE"

    # Small scale when distance >= 12.0
    assert run_experiment.diagnose_failure(1, 0, 15.0, 100.0, 120.0) == "UNDETECTED_SMALL_SCALE"


def test_synthetic_benchmark_execution(tmp_path):
    out_csv = tmp_path / "synthetic_results.csv"
    records = run_experiment.run_synthetic_benchmark(out_csv)

    assert len(records) > 0
    assert out_csv.exists()

    # Verify CSV headers and content
    with open(out_csv, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        assert len(rows) == len(records)
        first = rows[0]
        assert "image_id" in first
        assert "distance_meters" in first
        assert "lighting_condition" in first
        assert "expected_faces" in first
        assert "detected_faces" in first
        assert "bbox_w" in first
        assert "bbox_h" in first
        assert "ipd_px" in first


def test_summarize_results_pipeline(tmp_path):
    # Create sample results CSV
    sample_csv = tmp_path / "sample_results.csv"
    with open(sample_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "image_id", "device_model", "lens_type", "distance_meters",
            "lighting_condition", "lux_level", "img_width", "img_height",
            "laplacian_var", "mean_luminance", "expected_faces",
            "detected_faces", "detection_rate", "face_idx", "bbox_w",
            "bbox_h", "ipd_px", "confidence", "failure_reason"
        ])
        writer.writeheader()
        # Row 1: Detected face at 3m
        writer.writerow({
            "image_id": "IMG_3M", "device_model": "CamA", "lens_type": "normal",
            "distance_meters": 3.0, "lighting_condition": "ambient", "lux_level": 400.0,
            "img_width": 1920, "img_height": 1080, "laplacian_var": 120.0,
            "mean_luminance": 140.0, "expected_faces": 1, "detected_faces": 1,
            "detection_rate": 1.0, "face_idx": 1, "bbox_w": 120, "bbox_h": 150,
            "ipd_px": 45.0, "confidence": 0.95, "failure_reason": ""
        })
        # Row 2: Undetected face at 24m
        writer.writerow({
            "image_id": "IMG_24M", "device_model": "CamA", "lens_type": "normal",
            "distance_meters": 24.0, "lighting_condition": "ambient", "lux_level": 400.0,
            "img_width": 1920, "img_height": 1080, "laplacian_var": 100.0,
            "mean_luminance": 130.0, "expected_faces": 1, "detected_faces": 0,
            "detection_rate": 0.0, "face_idx": 0, "bbox_w": 0, "bbox_h": 0,
            "ipd_px": 0.0, "confidence": 0.0, "failure_reason": "UNDETECTED_SMALL_SCALE"
        })

    records = summarize_results.load_raw_results(sample_csv)
    assert len(records) == 2

    dist_summary = summarize_results.summarize_by_distance(records)
    assert len(dist_summary) == 2
    assert dist_summary[0]["distance_m"] == 3.0
    assert dist_summary[0]["detection_rate_pct"] == 100.0
    assert dist_summary[0]["avg_bbox_w_px"] == 120.0
    assert dist_summary[1]["distance_m"] == 24.0
    assert dist_summary[1]["detection_rate_pct"] == 0.0

    light_summary = summarize_results.summarize_by_lighting(records)
    assert len(light_summary) == 1
    assert light_summary[0]["lighting_condition"] == "ambient"

    failures = summarize_results.failure_mode_breakdown(records)
    assert failures.get("UNDETECTED_SMALL_SCALE") == 1

    md_report = summarize_results.format_markdown_report(dist_summary, light_summary, [], failures)
    assert "# Optical Feasibility Experiment — Summary Report" in md_report
    assert "UNDETECTED_SMALL_SCALE" in md_report
