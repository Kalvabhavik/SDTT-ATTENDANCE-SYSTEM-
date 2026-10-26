"""Frame-by-frame sweep analysis using server-side YuNet/ArcFace results."""
from __future__ import annotations

import cv2
import numpy as np
from typing import Any

from .face_engine import cosine_similarity
from .verification import RuleResult, evaluate_sweep
from .verification_config import DEFAULTS, VerificationConfig


def _rule(passed: bool | None, code: str, detail: str) -> RuleResult:
    return RuleResult(passed, code, detail)


def perceptual_hash(image_bytes: bytes) -> str:
    image = cv2.imdecode(np.frombuffer(image_bytes, np.uint8), cv2.IMREAD_GRAYSCALE)
    if image is None:
        raise ValueError("invalid_image")
    resized = cv2.resize(image, (32, 32), interpolation=cv2.INTER_AREA).astype(np.float32)
    dct = cv2.dct(resized)[:8, :8]
    cutoff = float(np.median(dct[1:, 1:]))
    return "".join("1" if value > cutoff else "0" for value in dct.flatten())


def hash_distance(left: str, right: str) -> int:
    if len(left) != len(right):
        return max(len(left), len(right))
    return sum(a != b for a, b in zip(left, right))


def _continuity(previous: bytes, current: bytes) -> bool:
    first = cv2.imdecode(np.frombuffer(previous, np.uint8), cv2.IMREAD_GRAYSCALE)
    second = cv2.imdecode(np.frombuffer(current, np.uint8), cv2.IMREAD_GRAYSCALE)
    if first is None or second is None:
        return False
    first = cv2.resize(first, (256, 144))
    second = cv2.resize(second, (256, 144))
    orb = cv2.ORB_create(nfeatures=250)
    kp1, des1 = orb.detectAndCompute(first, None)
    kp2, des2 = orb.detectAndCompute(second, None)
    if des1 is None or des2 is None:
        return False
    matches = cv2.BFMatcher(cv2.NORM_HAMMING).knnMatch(des1, des2, k=2)
    good = sum(1 for pair in matches if len(pair) == 2 and pair[0].distance < 0.75 * pair[1].distance)
    return good >= 5


def analyze_sweep(frame_inputs: list[dict[str, Any]], frame_bytes: list[bytes], duration_seconds: float,
                  student_embedding: list[float], lecturer_embedding: list[float],
                  engine: Any, config: VerificationConfig = DEFAULTS) -> dict[str, Any]:
    if len(frame_inputs) != len(frame_bytes):
        raise ValueError("frame metadata count mismatch")
    analyzed = [engine.analyze(data) for data in frame_bytes]
    facts: dict[str, Any] = {"rules": {}, "model_version": engine.model_version}
    rules = facts["rules"]
    frame_count = len(frame_bytes)
    rules["limits"] = _rule(
        0 < frame_count <= config.maximum_frames,
        "reject.frame_count_limit" if not 0 < frame_count <= config.maximum_frames else "ok",
        f"Received {frame_count} frames; allowed maximum is {config.maximum_frames}.",
    )
    quality_good = True
    for item in analyzed:
        if (item["width"] < config.minimum_width or item["height"] < config.minimum_height
                or item["laplacian_variance"] < config.minimum_laplacian_variance
                or not config.minimum_brightness <= item["brightness"] <= config.maximum_brightness):
            quality_good = False
    rules["image_quality"] = _rule(
        True if quality_good else None, "review.image_quality_retake" if not quality_good else "ok",
        "Resolution, blur and brightness checked per frame.",
    )
    ordered_pairs = sorted(enumerate(frame_inputs), key=lambda pair: float(pair[1]["offset_seconds"]))
    ordered_meta = [meta for _, meta in ordered_pairs]
    start_heading = float(ordered_meta[0]["heading_degrees"]) if ordered_meta else 0.0
    sweep_frames = []
    for index, (source_index, meta) in enumerate(ordered_pairs):
        previous_index = ordered_pairs[index - 1][0] if index else source_index
        sweep_frames.append({
            "offset_seconds": meta["offset_seconds"],
            "heading_degrees": meta["heading_degrees"],
            "continuity_ok": True if index == 0 else _continuity(frame_bytes[previous_index], frame_bytes[source_index]),
        })
    rules.update(evaluate_sweep(sweep_frames, duration_seconds, config))

    early = []
    late = []
    for idx, (meta, image) in enumerate(zip(frame_inputs, analyzed)):
        angle = abs(((float(meta["heading_degrees"]) - start_heading + 180) % 360) - 180)
        if angle <= 30:
            early.extend((idx, face) for face in image["faces"])
        if angle >= config.minimum_heading_span_degrees:
            late.extend((idx, face) for face in image["faces"])
    best_self = max(early, key=lambda pair: pair[1].get("quality", 0), default=None)
    self_similarity = cosine_similarity(best_self[1]["embedding"], student_embedding) if best_self else -1.0
    if self_similarity >= config.self_pass_similarity:
        rules["self_match"] = _rule(True, "ok", f"Self match similarity {self_similarity:.3f}.")
    elif self_similarity >= config.self_review_similarity:
        rules["self_match"] = _rule(None, "review.self_match_uncertain", f"Self match similarity {self_similarity:.3f}.")
    else:
        rules["self_match"] = _rule(False, "reject.self_not_matched", f"Self match similarity {self_similarity:.3f}.")

    student_face = best_self[1] if best_self else None
    neighbours: list[dict[str, Any]] = []
    if student_face:
        sx, sy, sw, sh = student_face["bbox"]
        for _, face in early:
            if face is student_face:
                continue
            x, y, w, h = face["bbox"]
            close = abs((x + w / 2) - (sx + sw / 2)) <= config.maximum_neighbour_distance_face_widths * sw
            if close and cosine_similarity(face["embedding"], student_face["embedding"]) < 0.72:
                if all(cosine_similarity(face["embedding"], existing["embedding"]) < 0.72 for existing in neighbours):
                    neighbours.append(face)
    neighbours_ok = len(neighbours) >= config.minimum_neighbours
    rules["neighbours"] = _rule(neighbours_ok,
        "reject.neighbour_not_visible" if not neighbours_ok else "ok",
        f"Detected {len(neighbours)} distinct nearby faces.")

    identifiable = [face for _, face in late if face["inter_pupil_pixels"] >= config.minimum_inter_pupil_pixels]
    small = [face for _, face in late if face["inter_pupil_pixels"] < config.minimum_inter_pupil_pixels]
    if identifiable:
        lecturer_score = max(cosine_similarity(face["embedding"], lecturer_embedding) for face in identifiable)
        rules["lecturer_visible"] = _rule(lecturer_score >= config.self_pass_similarity,
            "reject.lecturer_not_matched" if lecturer_score < config.self_pass_similarity else "ok",
            f"Lecturer face match similarity {lecturer_score:.3f}.")
    elif small:
        rules["lecturer_visible"] = _rule(None, "review.lecturer_face_too_small",
            "A face is visible, but it is too small to identify reliably.")
    else:
        rules["lecturer_visible"] = _rule(False, "reject.lecturer_not_visible", "No face/person was detected in late sweep frames.")

    facts["metrics"] = {
        "self_similarity": self_similarity,
        "neighbour_count": len(neighbours),
        "late_identifiable_face_count": len(identifiable),
        "late_small_face_count": len(small),
        "frame_count": frame_count,
    }
    facts["key_frame_indices"] = sorted(set([best_self[0]] if best_self else []) | set(idx for idx, _ in late))
    facts["perceptual_hashes"] = [perceptual_hash(data) for data in frame_bytes]
    return facts


def decide(rules: dict[str, RuleResult]) -> dict[str, Any]:
    from dataclasses import asdict
    hard = [result for result in rules.values() if result.passed is False]
    uncertain = [result for result in rules.values() if result.passed is None]
    if hard:
        status, reason = "rejected", hard[0].reason_code
    elif uncertain:
        status, reason = "flagged", uncertain[0].reason_code
    else:
        status, reason = "verified", "verified"
    return {"status": status, "reason_code": reason,
            "rules": {name: asdict(result) for name, result in rules.items()}}
