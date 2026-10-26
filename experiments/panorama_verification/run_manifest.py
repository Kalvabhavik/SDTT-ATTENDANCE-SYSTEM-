#!/usr/bin/env python3
"""Run real configured verification on a consented-volunteer local JSON manifest.

Manifest: {"cases":[{"device":"...", "duration_seconds":8.2,
"student_embedding":[...],"lecturer_embedding":[...],
"frames":[{"image":"relative.jpg","offset_seconds":0.0,"heading_degrees":0.0}, ...]}]}
Paths resolve relative to the manifest. The script prints per-rule outcomes by device; it does not upload or copy images. Keep manifest, images and embeddings out of git.
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path

from backend.app.face_engine import YuNetArcFaceEngine
from backend.app.verification_pipeline import analyze_sweep, decide


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--yunet", type=Path, required=True)
    parser.add_argument("--arcface", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    engine = YuNetArcFaceEngine(str(args.yunet), str(args.arcface))
    totals = defaultdict(lambda: defaultdict(lambda: {"pass": 0, "flagged": 0, "fail": 0, "total": 0}))
    lecturer = defaultdict(lambda: {"flagged": 0, "total": 0})
    for case in manifest["cases"]:
        frames = case["frames"]
        payloads = [(args.manifest.parent / item["image"]).read_bytes() for item in frames]
        facts = analyze_sweep(frames, payloads, float(case["duration_seconds"]),
                              case["student_embedding"], case["lecturer_embedding"], engine)
        results = decide(facts["rules"])["rules"]
        device = str(case["device"])
        for name, rule in results.items():
            bucket = "pass" if rule["passed"] is True else "flagged" if rule["passed"] is None else "fail"
            totals[device][name][bucket] += 1
            totals[device][name]["total"] += 1
        lecturer_rule = results.get("lecturer_visible", {})
        lecturer[device]["total"] += 1
        lecturer[device]["flagged"] += lecturer_rule.get("passed") is None
    report = {"model_version": engine.model_version, "devices": {}}
    for device, rules in totals.items():
        report["devices"][device] = {
            "rules": {name: {**counts,
                "pass_rate": round(counts["pass"] / counts["total"], 4),
                "flagged_rate": round(counts["flagged"] / counts["total"], 4),
                "fail_rate": round(counts["fail"] / counts["total"], 4)}
                for name, counts in rules.items()},
            "lecturer_checks_flagged": lecturer[device]["flagged"],
            "lecturer_checks_total": lecturer[device]["total"],
            "lecturer_flagged_share": round(lecturer[device]["flagged"] / lecturer[device]["total"], 4),
        }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
