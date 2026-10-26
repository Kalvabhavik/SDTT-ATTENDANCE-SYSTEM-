"""Pure verification rules. Sensor headings are supporting evidence only."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timedelta
from typing import Any, Protocol

from .verification_config import DEFAULTS, VerificationConfig


@dataclass(frozen=True)
class RuleResult:
    passed: bool | None
    reason_code: str
    detail: str


class FaceEngine(Protocol):
    """Production face-analysis boundary; never accepts client identity claims."""

    model_version: str

    def analyze(self, image_bytes: bytes) -> dict[str, Any]: ...


def inside_submission_window(status: str, ends_at: datetime, received_at: datetime,
                            grace_seconds: int = DEFAULTS.submission_grace_seconds) -> bool:
    """Compare server timestamps only; `closed` remains submit-eligible during grace."""
    return status in ("open", "closed") and received_at <= ends_at + timedelta(seconds=grace_seconds)


def evaluate_sweep(frames: list[dict[str, Any]], duration_seconds: float,
                   config: VerificationConfig = DEFAULTS) -> dict[str, RuleResult]:
    ordered = sorted(frames, key=lambda frame: float(frame.get("offset_seconds", -1)))
    headings = [float(frame["heading_degrees"]) % 360 for frame in ordered
                if frame.get("heading_degrees") is not None]
    results: dict[str, RuleResult] = {}
    results["frame_count"] = RuleResult(
        len(ordered) >= config.minimum_frames,
        "sweep.too_few_frames" if len(ordered) < config.minimum_frames else "ok",
        f"Received {len(ordered)} frames; minimum is {config.minimum_frames}.",
    )
    duration_ok = config.capture_min_seconds <= duration_seconds <= config.capture_max_seconds
    results["duration"] = RuleResult(
        duration_ok,
        "sweep.duration_out_of_range" if not duration_ok else "ok",
        f"Capture duration was {duration_seconds:.2f} seconds.",
    )
    deltas = [((b - a + 180) % 360) - 180 for a, b in zip(headings, headings[1:])]
    monotonic = bool(deltas) and (all(delta >= -3 for delta in deltas) or all(delta <= 3 for delta in deltas))
    results["heading_monotonic"] = RuleResult(
        monotonic, "sweep.heading_not_monotonic" if not monotonic else "ok",
        "Client headings are supporting evidence and can be spoofed.",
    )
    gap_ok = bool(deltas) and all(abs(delta) <= config.maximum_heading_gap_degrees for delta in deltas)
    results["heading_gap"] = RuleResult(
        gap_ok, "sweep.heading_gap_too_large" if not gap_ok else "ok",
        f"Largest angular gap is {max((abs(d) for d in deltas), default=360):.1f} degrees.",
    )
    span = max((abs(((h - headings[0] + 180) % 360) - 180) for h in headings), default=0.0) if headings else 0.0
    span_ok = span >= config.minimum_heading_span_degrees
    results["heading_span"] = RuleResult(
        span_ok, "sweep.heading_span_too_small" if not span_ok else "ok",
        f"Observed client heading span is {span:.1f} degrees; this is not proof of physical movement.",
    )
    continuity_values = [frame.get("continuity_ok") for frame in ordered[1:]]
    continuity_ok = bool(continuity_values) and all(continuity_values)
    results["visual_continuity"] = RuleResult(
        continuity_ok, "sweep.visual_discontinuity" if not continuity_ok else "ok",
        "Consecutive-frame visual continuity check.",
    )
    return results


def build_decision(results: dict[str, RuleResult], facts: dict[str, Any],
                   config: VerificationConfig = DEFAULTS) -> dict[str, Any]:
    """Apply the ordered decision policy to server-side analysis facts."""
    ordered = dict(results)
    for key in ("jwt", "class_enrollment", "session_window", "idempotency", "limits",
                "image_quality", "frame_count", "duration", "heading_monotonic",
                "heading_gap", "heading_span", "visual_continuity", "self_match",
                "neighbours", "lecturer_visible", "duplicate_signal"):
        if key in facts.get("rules", {}):
            ordered[key] = facts["rules"][key]

    rules_json = {name: asdict(rule) for name, rule in ordered.items()}
    hard_failures = [rule for rule in ordered.values() if rule.passed is False and rule.reason_code.startswith("reject.")]
    flagged = [rule for rule in ordered.values() if rule.passed is None or rule.reason_code.startswith("review.")]
    if hard_failures:
        status = "rejected"
        reason = hard_failures[0].reason_code
    elif flagged:
        status = "flagged"
        reason = flagged[0].reason_code
    else:
        status = "verified"
        reason = "verified"
    return {"status": status, "reason_code": reason, "rules": rules_json,
            "model_version": facts.get("model_version")}
