#!/usr/bin/env python3
"""Optical Feasibility Experiment Runner.

Evaluates smartphone camera resolution and face detection performance
at varying distances, lenses, and lighting conditions in a 240-seat lecture hall.
"""
from __future__ import annotations

import argparse
import csv
import math
import os
import sys
from pathlib import Path
from typing import Any, Optional

try:
    import cv2
except ImportError:
    cv2 = None

try:
    import numpy as np
except ImportError:
    np = None


def compute_image_metrics(gray_img: Any) -> tuple[float, float]:
    """Compute Laplacian variance (sharpness/blur metric) and mean luminance."""
    if np is None:
        return 0.0, 0.0
    if cv2 is None:
        # A small finite-difference Laplacian keeps the experiment useful in
        # minimal CI images without making OpenCV a hard import requirement.
        image = gray_img.astype(float)
        laplacian = (
            image[:-2, 1:-1] + image[2:, 1:-1] + image[1:-1, :-2] + image[1:-1, 2:]
            - 4 * image[1:-1, 1:-1]
        )
        return round(float(laplacian.var()), 2), round(float(np.mean(gray_img)), 2)
    laplacian_var = float(cv2.Laplacian(gray_img, cv2.CV_64F).var())
    mean_luminance = float(np.mean(gray_img))
    return round(laplacian_var, 2), round(mean_luminance, 2)


def get_default_detector(model_path: Optional[str] = None):
    """Initialize OpenCV YuNet Face Detector or fallback to Haar Cascade."""
    if cv2 is None:
        return None, "none"

    if model_path and Path(model_path).exists():
        detector = cv2.FaceDetectorYN.create(
            model=model_path,
            config="",
            input_size=(320, 320),
            score_threshold=0.5,
            nms_threshold=0.3,
            top_k=5000,
        )
        return detector, "yunet"

    # Fallback to OpenCV built-in Haar Cascade
    cascade_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    if Path(cascade_path).exists():
        cascade = cv2.CascadeClassifier(cascade_path)
        return cascade, "haar"

    return None, "none"


def detect_faces(
    detector: Any,
    detector_type: str,
    img: Any,
) -> list[dict[str, Any]]:
    """Detect faces in image and extract bounding boxes and landmarks if available."""
    if cv2 is None or detector is None:
        return []

    h, w = img.shape[:2]
    faces: list[dict[str, Any]] = []

    if detector_type == "yunet":
        detector.setInputSize((w, h))
        _, detections = detector.detect(img)
        if detections is not None:
            for d in detections:
                box_x, box_y, box_w, box_h = int(d[0]), int(d[1]), int(d[2]), int(d[3])
                conf = float(d[14])
                # YuNet landmark coordinates for right eye (d[4], d[5]) and left eye (d[6], d[7])
                rx, ry = float(d[4]), float(d[5])
                lx, ly = float(d[6]), float(d[7])
                ipd = math.sqrt((rx - lx) ** 2 + (ry - ly) ** 2)
                faces.append({
                    "bbox_x": max(0, box_x),
                    "bbox_y": max(0, box_y),
                    "bbox_w": box_w,
                    "bbox_h": box_h,
                    "confidence": round(conf, 3),
                    "ipd_px": round(ipd, 1),
                })
    elif detector_type == "haar":
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
        rects = detector.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=4,
            minSize=(16, 16),
        )
        for (x, y, bw, bh) in rects:
            # Approximate IPD for frontal face without facial landmark detector (~35-40% of face width)
            approx_ipd = round(bw * 0.38, 1)
            faces.append({
                "bbox_x": int(x),
                "bbox_y": int(y),
                "bbox_w": int(bw),
                "bbox_h": int(bh),
                "confidence": 1.0,  # Haar cascade does not provide calibrated confidence
                "ipd_px": approx_ipd,
            })

    return faces


def diagnose_failure(
    expected_count: int,
    detected_count: int,
    distance_meters: float,
    laplacian_var: float,
    mean_luminance: float,
) -> Optional[str]:
    """Diagnose most probable failure reason when expected faces are missed."""
    if detected_count >= expected_count:
        return None

    if laplacian_var < 35.0:
        return "MOTION_BLUR"
    if mean_luminance < 30.0:
        return "UNDEREXPOSURE"
    if mean_luminance > 225.0:
        return "OVEREXPOSURE"
    if distance_meters >= 12.0:
        return "UNDETECTED_SMALL_SCALE"
    return "OCCLUSION_OR_OFF_ANGLE"


def generate_synthetic_test_image(
    distance_meters: float,
    lighting_lux: float,
    blur_level: float = 0.0,
) -> Any:
    """Generate controlled synthetic test image with known face geometry for testing."""
    if cv2 is None or np is None:
        return None

    # Base canvas: 1920x1080
    w, h = 1920, 1080
    bg_val = int(min(255, max(15, (lighting_lux / 500.0) * 180)))
    img = np.full((h, w, 3), bg_val, dtype=np.uint8)

    # Face size inversely proportional to distance (simulating perspective projection)
    # At 3m: ~120px wide; at 24m: ~15px wide
    face_w = int(max(12, round(360.0 / max(1.0, distance_meters))))
    face_h = int(round(face_w * 1.3))

    cx, cy = w // 2, h // 2
    x1 = cx - face_w // 2
    y1 = cy - face_h // 2

    # Draw oval face target with skin tone
    cv2.ellipse(img, (cx, cy), (face_w // 2, face_h // 2), 0, 0, 360, (180, 200, 230), -1)
    # Draw eyes
    eye_r = max(1, face_w // 14)
    eye_offset = face_w // 4
    cv2.circle(img, (cx - eye_offset, cy - face_h // 6), eye_r, (40, 40, 40), -1)
    cv2.circle(img, (cx + eye_offset, cy - face_h // 6), eye_r, (40, 40, 40), -1)

    if blur_level > 0:
        ksize = int(math.ceil(blur_level * 3))
        if ksize % 2 == 0:
            ksize += 1
        ksize = max(3, ksize)
        img = cv2.GaussianBlur(img, (ksize, ksize), blur_level)

    return img


def process_manifest(
    manifest_path: Path,
    output_csv_path: Path,
    base_dir: Path,
    model_path: Optional[str] = None,
) -> list[dict[str, Any]]:
    """Process all entries in a CSV manifest and write detection results."""
    detector, detector_type = get_default_detector(model_path)
    records: list[dict[str, Any]] = []

    with open(manifest_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            image_id = row["image_id"]
            rel_path = row["relative_path"]
            device = row.get("device_model", "unknown")
            lens = row.get("lens_type", "normal")
            dist = float(row.get("distance_meters", 0.0))
            lighting = row.get("lighting_condition", "ambient")
            lux = float(row.get("lux_level", 400.0))
            expected = int(row.get("expected_faces", 1))

            full_path = base_dir / rel_path
            if not full_path.exists():
                print(f"[WARN] Image file not found: {full_path}. Logging as MISSING_FILE.")
                records.append({
                    "image_id": image_id,
                    "device_model": device,
                    "lens_type": lens,
                    "distance_meters": dist,
                    "lighting_condition": lighting,
                    "lux_level": lux,
                    "img_width": 0,
                    "img_height": 0,
                    "laplacian_var": 0.0,
                    "mean_luminance": 0.0,
                    "expected_faces": expected,
                    "detected_faces": 0,
                    "detection_rate": 0.0,
                    "face_idx": 0,
                    "bbox_x": 0,
                    "bbox_y": 0,
                    "bbox_w": 0,
                    "bbox_h": 0,
                    "ipd_px": 0.0,
                    "confidence": 0.0,
                    "failure_reason": "MISSING_FILE",
                })
                continue

            img = cv2.imread(str(full_path))
            if img is None:
                continue

            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            lap_var, mean_lum = compute_image_metrics(gray)
            detected = detect_faces(detector, detector_type, img)
            rate = round(min(1.0, len(detected) / max(1, expected)), 2)
            fail_diag = diagnose_failure(expected, len(detected), dist, lap_var, mean_lum)

            if not detected:
                records.append({
                    "image_id": image_id,
                    "device_model": device,
                    "lens_type": lens,
                    "distance_meters": dist,
                    "lighting_condition": lighting,
                    "lux_level": lux,
                    "img_width": img.shape[1],
                    "img_height": img.shape[0],
                    "laplacian_var": lap_var,
                    "mean_luminance": mean_lum,
                    "expected_faces": expected,
                    "detected_faces": 0,
                    "detection_rate": 0.0,
                    "face_idx": 0,
                    "bbox_x": 0,
                    "bbox_y": 0,
                    "bbox_w": 0,
                    "bbox_h": 0,
                    "ipd_px": 0.0,
                    "confidence": 0.0,
                    "failure_reason": fail_diag or "UNDETECTED",
                })
            else:
                for idx, face in enumerate(detected):
                    records.append({
                        "image_id": image_id,
                        "device_model": device,
                        "lens_type": lens,
                        "distance_meters": dist,
                        "lighting_condition": lighting,
                        "lux_level": lux,
                        "img_width": img.shape[1],
                        "img_height": img.shape[0],
                        "laplacian_var": lap_var,
                        "mean_luminance": mean_lum,
                        "expected_faces": expected,
                        "detected_faces": len(detected),
                        "detection_rate": rate,
                        "face_idx": idx + 1,
                        "bbox_x": face["bbox_x"],
                        "bbox_y": face["bbox_y"],
                        "bbox_w": face["bbox_w"],
                        "bbox_h": face["bbox_h"],
                        "ipd_px": face["ipd_px"],
                        "confidence": face["confidence"],
                        "failure_reason": None,
                    })

    output_csv_path.parent.mkdir(parents=True, exist_ok=True)
    if records:
        fieldnames = list(records[0].keys())
        with open(output_csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(records)

    return records


def run_synthetic_benchmark(output_csv_path: Path) -> list[dict[str, Any]]:
    """Run synthetic feasibility simulation across standardized distances and lighting."""
    detector, detector_type = get_default_detector()
    distances = [3.0, 6.0, 12.0, 18.0, 24.0]
    lighting_presets = [
        ("ambient_full", 450.0),
        ("dimmed_projection", 80.0),
        ("dimmed_blur", 80.0),
    ]

    records: list[dict[str, Any]] = []
    for dist in distances:
        for light_name, lux in lighting_presets:
            blur = 3.5 if "blur" in light_name else 0.0
            img = generate_synthetic_test_image(dist, lux, blur_level=blur)
            if img is None:
                # Preserve benchmark output shape in environments without
                # OpenCV; this result is explicitly a no-detector baseline.
                gray = np.full((1080, 1920), int(min(255, max(15, (lux / 500.0) * 180))), dtype=np.uint8)
            else:
                gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            lap_var, mean_lum = compute_image_metrics(gray)
            detected = detect_faces(detector, detector_type, img) if img is not None else []
            expected = 1
            rate = 1.0 if detected else 0.0
            fail_diag = diagnose_failure(expected, len(detected), dist, lap_var, mean_lum)

            if not detected:
                records.append({
                    "image_id": f"SYN_{dist}m_{light_name}",
                    "device_model": "SyntheticCamera",
                    "lens_type": "normal",
                    "distance_meters": dist,
                    "lighting_condition": light_name,
                    "lux_level": lux,
                    "img_width": 1920,
                    "img_height": 1080,
                    "laplacian_var": lap_var,
                    "mean_luminance": mean_lum,
                    "expected_faces": expected,
                    "detected_faces": 0,
                    "detection_rate": 0.0,
                    "face_idx": 0,
                    "bbox_x": 0,
                    "bbox_y": 0,
                    "bbox_w": 0,
                    "bbox_h": 0,
                    "ipd_px": 0.0,
                    "confidence": 0.0,
                    "failure_reason": fail_diag or "UNDETECTED",
                })
            else:
                for idx, face in enumerate(detected):
                    records.append({
                        "image_id": f"SYN_{dist}m_{light_name}",
                        "device_model": "SyntheticCamera",
                        "lens_type": "normal",
                        "distance_meters": dist,
                        "lighting_condition": light_name,
                        "lux_level": lux,
                        "img_width": 1920,
                        "img_height": 1080,
                        "laplacian_var": lap_var,
                        "mean_luminance": mean_lum,
                        "expected_faces": expected,
                        "detected_faces": len(detected),
                        "detection_rate": rate,
                        "face_idx": idx + 1,
                        "bbox_x": face["bbox_x"],
                        "bbox_y": face["bbox_y"],
                        "bbox_w": face["bbox_w"],
                        "bbox_h": face["bbox_h"],
                        "ipd_px": face["ipd_px"],
                        "confidence": face["confidence"],
                        "failure_reason": None,
                    })

    output_csv_path.parent.mkdir(parents=True, exist_ok=True)
    if records:
        fieldnames = list(records[0].keys())
        with open(output_csv_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(records)

    return records


def main():
    parser = argparse.ArgumentParser(description="Optical Feasibility Experiment Runner")
    parser.add_argument("--manifest", type=str, help="Path to manifest CSV file")
    parser.add_argument("--output", type=str, default="experiments/optical_feasibility/results/raw_results.csv", help="Output results CSV")
    parser.add_argument("--model-path", type=str, default=None, help="Path to YuNet ONNX face detection model")
    parser.add_argument("--synthetic-test", action="store_true", help="Run benchmark with synthetic targets for validation")
    args = parser.parse_args()

    out_path = Path(args.output)
    if args.synthetic_test:
        print("[INFO] Running synthetic target optical experiment...")
        records = run_synthetic_benchmark(out_path)
        print(f"[INFO] Processed {len(records)} test instances. Output written to: {out_path}")
    elif args.manifest:
        man_path = Path(args.manifest)
        if not man_path.exists():
            print(f"[ERROR] Manifest file does not exist: {man_path}")
            sys.exit(1)
        records = process_manifest(man_path, out_path, man_path.parent, args.model_path)
        print(f"[INFO] Manifest processed ({len(records)} entries written to {out_path})")
    else:
        print("[ERROR] Please provide --manifest <path> or use --synthetic-test.")
        sys.exit(1)


if __name__ == "__main__":
    main()
