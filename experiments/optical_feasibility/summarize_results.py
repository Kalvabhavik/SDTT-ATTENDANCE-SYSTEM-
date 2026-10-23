#!/usr/bin/env python3
"""Optical Feasibility Results Summarizer.

Reads raw experiment output and aggregates detection rate, face resolution,
blur, and failure modes across distance, lens, and lighting conditions.
"""
from __future__ import annotations

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


def load_raw_results(csv_path: Path) -> list[dict[str, Any]]:
    if not csv_path.exists():
        raise FileNotFoundError(f"Results CSV not found: {csv_path}")

    records = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append({
                "image_id": row["image_id"],
                "device_model": row.get("device_model", "unknown"),
                "lens_type": row.get("lens_type", "normal"),
                "distance_meters": float(row.get("distance_meters", 0.0)),
                "lighting_condition": row.get("lighting_condition", "ambient"),
                "lux_level": float(row.get("lux_level", 0.0)),
                "img_width": int(row.get("img_width", 0)),
                "img_height": int(row.get("img_height", 0)),
                "laplacian_var": float(row.get("laplacian_var", 0.0)),
                "mean_luminance": float(row.get("mean_luminance", 0.0)),
                "expected_faces": int(row.get("expected_faces", 1)),
                "detected_faces": int(row.get("detected_faces", 0)),
                "detection_rate": float(row.get("detection_rate", 0.0)),
                "face_idx": int(row.get("face_idx", 0)),
                "bbox_w": int(row.get("bbox_w", 0)),
                "bbox_h": int(row.get("bbox_h", 0)),
                "ipd_px": float(row.get("ipd_px", 0.0)),
                "confidence": float(row.get("confidence", 0.0)),
                "failure_reason": row.get("failure_reason") or "",
            })
    return records


def summarize_by_distance(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    # Group by image first to avoid skewing detection rate by multiple face rows
    images_by_dist = defaultdict(dict)
    faces_by_dist = defaultdict(list)

    for r in records:
        dist = r["distance_meters"]
        img_id = r["image_id"]
        if img_id not in images_by_dist[dist]:
            images_by_dist[dist][img_id] = {
                "expected": r["expected_faces"],
                "detected": r["detected_faces"],
                "detection_rate": r["detection_rate"],
            }
        if r["bbox_w"] > 0:
            faces_by_dist[dist].append(r)

    summary = []
    for dist in sorted(images_by_dist.keys()):
        img_dict = images_by_dist[dist]
        total_images = len(img_dict)
        tot_expected = sum(v["expected"] for v in img_dict.values())
        tot_detected = sum(v["detected"] for v in img_dict.values())
        overall_rate = round((tot_detected / max(1, tot_expected)) * 100, 1)

        faces = faces_by_dist[dist]
        avg_w = round(sum(f["bbox_w"] for f in faces) / len(faces), 1) if faces else 0.0
        avg_h = round(sum(f["bbox_h"] for f in faces) / len(faces), 1) if faces else 0.0
        avg_ipd = round(sum(f["ipd_px"] for f in faces) / len(faces), 1) if faces else 0.0
        min_w = min((f["bbox_w"] for f in faces), default=0)
        max_w = max((f["bbox_w"] for f in faces), default=0)

        summary.append({
            "distance_m": dist,
            "images_count": total_images,
            "expected_faces": tot_expected,
            "detected_faces": tot_detected,
            "detection_rate_pct": overall_rate,
            "avg_bbox_w_px": avg_w,
            "avg_bbox_h_px": avg_h,
            "avg_ipd_px": avg_ipd,
            "min_bbox_w_px": min_w,
            "max_bbox_w_px": max_w,
        })
    return summary


def summarize_by_lighting(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    images_by_light = defaultdict(dict)
    for r in records:
        light = r["lighting_condition"]
        img_id = r["image_id"]
        if img_id not in images_by_light[light]:
            images_by_light[light][img_id] = {
                "expected": r["expected_faces"],
                "detected": r["detected_faces"],
                "laplacian_var": r["laplacian_var"],
                "luminance": r["mean_luminance"],
            }

    summary = []
    for light, img_dict in sorted(images_by_light.items()):
        tot_expected = sum(v["expected"] for v in img_dict.values())
        tot_detected = sum(v["detected"] for v in img_dict.values())
        rate = round((tot_detected / max(1, tot_expected)) * 100, 1)
        avg_blur = round(sum(v["laplacian_var"] for v in img_dict.values()) / len(img_dict), 1)
        avg_lum = round(sum(v["luminance"] for v in img_dict.values()) / len(img_dict), 1)

        summary.append({
            "lighting_condition": light,
            "total_images": len(img_dict),
            "expected_faces": tot_expected,
            "detected_faces": tot_detected,
            "detection_rate_pct": rate,
            "avg_laplacian_var": avg_blur,
            "avg_luminance": avg_lum,
        })
    return summary


def summarize_by_lens(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    images_by_lens = defaultdict(dict)
    faces_by_lens = defaultdict(list)

    for r in records:
        lens = r["lens_type"]
        img_id = r["image_id"]
        if img_id not in images_by_lens[lens]:
            images_by_lens[lens][img_id] = {
                "expected": r["expected_faces"],
                "detected": r["detected_faces"],
            }
        if r["bbox_w"] > 0:
            faces_by_lens[lens].append(r)

    summary = []
    for lens, img_dict in sorted(images_by_lens.items()):
        tot_expected = sum(v["expected"] for v in img_dict.values())
        tot_detected = sum(v["detected"] for v in img_dict.values())
        rate = round((tot_detected / max(1, tot_expected)) * 100, 1)
        faces = faces_by_lens[lens]
        avg_w = round(sum(f["bbox_w"] for f in faces) / len(faces), 1) if faces else 0.0

        summary.append({
            "lens_type": lens,
            "total_images": len(img_dict),
            "expected_faces": tot_expected,
            "detected_faces": tot_detected,
            "detection_rate_pct": rate,
            "avg_bbox_w_px": avg_w,
        })
    return summary


def failure_mode_breakdown(records: list[dict[str, Any]]) -> dict[str, int]:
    failures = defaultdict(int)
    seen_images = set()
    for r in records:
        img_id = r["image_id"]
        reason = r["failure_reason"]
        if reason and img_id not in seen_images:
            failures[reason] += 1
            seen_images.add(img_id)
    return dict(failures)


def format_markdown_report(
    dist_summary: list[dict[str, Any]],
    light_summary: list[dict[str, Any]],
    lens_summary: list[dict[str, Any]],
    failures: dict[str, int],
) -> str:
    lines = [
        "# Optical Feasibility Experiment — Summary Report",
        "",
        "## 1. Distance Degradation Metrics",
        "",
        "| Distance (m) | Images | Expected | Detected | Detection Rate (%) | Avg Face Width (px) | Avg IPD (px) |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ]
    for s in dist_summary:
        lines.append(f"| {s['distance_m']}m | {s['images_count']} | {s['expected_faces']} | {s['detected_faces']} | {s['detection_rate_pct']}% | {s['avg_bbox_w_px']} px | {s['avg_ipd_px']} px |")

    lines.extend([
        "",
        "## 2. Lighting & Environmental Robustness",
        "",
        "| Lighting Condition | Images | Expected | Detected | Detection Rate (%) | Avg Sharpness (Laplacian) | Avg Luminance (0-255) |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ])
    for s in light_summary:
        lines.append(f"| {s['lighting_condition']} | {s['total_images']} | {s['expected_faces']} | {s['detected_faces']} | {s['detection_rate_pct']}% | {s['avg_laplacian_var']} | {s['avg_luminance']} |")

    lines.extend([
        "",
        "## 3. Lens Comparison",
        "",
        "| Lens Type | Images | Expected | Detected | Detection Rate (%) | Avg Face Width (px) |",
        "| :--- | :--- | :--- | :--- | :--- | :--- |",
    ])
    for s in lens_summary:
        lines.append(f"| {s['lens_type']} | {s['total_images']} | {s['expected_faces']} | {s['detected_faces']} | {s['detection_rate_pct']}% | {s['avg_bbox_w_px']} px |")

    lines.extend([
        "",
        "## 4. Failure Mode Breakdown",
        "",
        "| Primary Failure Mode | Count | Probable Cause |",
        "| :--- | :--- | :--- |",
    ])
    for reason, count in sorted(failures.items()):
        lines.append(f"| {reason} | {count} | Environmental/scale limit |")

    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Optical Feasibility Results Summarizer")
    parser.add_argument("--input-csv", type=str, default="experiments/optical_feasibility/results/raw_results.csv", help="Input results CSV")
    parser.add_argument("--output-md", type=str, default="experiments/optical_feasibility/results/summary_report.md", help="Output summary report Markdown")
    parser.add_argument("--output-csv", type=str, default="experiments/optical_feasibility/results/summary_distance.csv", help="Output distance summary CSV")
    args = parser.parse_args()

    in_path = Path(args.input_csv)
    if not in_path.exists():
        print(f"[ERROR] Input CSV does not exist: {in_path}")
        sys.exit(1)

    records = load_raw_results(in_path)
    dist_sum = summarize_by_distance(records)
    light_sum = summarize_by_lighting(records)
    lens_sum = summarize_by_lens(records)
    failures = failure_mode_breakdown(records)

    md_report = format_markdown_report(dist_sum, light_sum, lens_sum, failures)
    print(md_report)

    out_md = Path(args.output_md)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text(md_report, encoding="utf-8")

    out_csv = Path(args.output_csv)
    if dist_sum:
        with open(out_csv, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(dist_sum[0].keys()))
            writer.writeheader()
            writer.writerows(dist_sum)

    print(f"\n[INFO] Summary written to {out_md} and {out_csv}")


if __name__ == "__main__":
    main()
