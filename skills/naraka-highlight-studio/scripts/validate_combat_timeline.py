from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Program duration is computed by the shared geometry module so this validator,
# the QA gate and the 4K cut-list reader cannot disagree.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from episode_geometry import (  # noqa: E402
    timeline_hole_problems,
    timeline_program_seconds,
    timeline_raw_span_seconds,
)


def as_float(value: Any, field: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} must be numeric") from exc


def load_episodes(path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return {}, [dict(item) for item in data]
    if not isinstance(data, dict):
        raise ValueError("timeline JSON must be a list or an object")

    for key in ("combat_episodes", "episodes", "clips", "events"):
        value = data.get(key)
        if isinstance(value, list):
            return data, [dict(item) for item in value]
    raise ValueError("timeline JSON must contain combat_episodes, episodes, clips, or events")


def interval(value: Any, label: str) -> tuple[float, float]:
    if not isinstance(value, (list, tuple)) or len(value) != 2:
        raise ValueError(f"{label} must be [start, end]")
    start = as_float(value[0], f"{label}.start")
    end = as_float(value[1], f"{label}.end")
    if not 0 <= start < end:
        raise ValueError(f"{label} must satisfy 0 <= start < end")
    return start, end


def check_deleted_intervals(data: dict[str, Any], episodes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    raw = data.get("deleted_intervals", data.get("gaps", []))
    if raw is None:
        raw = []
    if not isinstance(raw, list):
        return [{"name": "deleted_intervals_shape", "pass": False, "detail": "must be a list"}]

    selected = [(float(item["source_start"]), float(item["source_end"])) for item in episodes if "source_start" in item and "source_end" in item]
    checks: list[dict[str, Any]] = []
    for index, item in enumerate(raw, 1):
        if not isinstance(item, dict):
            checks.append({"name": f"deleted_interval_{index}", "pass": False, "detail": "must be an object"})
            continue
        try:
            start = as_float(item.get("start", item.get("source_start")), f"deleted_intervals[{index}].start")
            end = as_float(item.get("end", item.get("source_end")), f"deleted_intervals[{index}].end")
            category = str(item.get("category", ""))
            overlaps = any(start < selected_end and end > selected_start for selected_start, selected_end in selected)
            checks.append(
                {
                    "name": f"deleted_interval_{index}",
                    "pass": 0 <= start < end and bool(category) and not overlaps,
                    "start": start,
                    "end": end,
                    "category": category,
                    "overlaps_selected": overlaps,
                }
            )
        except ValueError as exc:
            checks.append({"name": f"deleted_interval_{index}", "pass": False, "detail": str(exc)})
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a complete-combat roughcut timeline.")
    parser.add_argument("timeline", type=Path)
    parser.add_argument("--source-duration", type=float)
    parser.add_argument("--proxy-map", type=Path, default=None)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    checks: list[dict[str, Any]] = []
    warnings: list[str] = []
    try:
        data, episodes = load_episodes(args.timeline)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        result = {"schema": "naraka-combat-roughcut-qa/v1", "pass": False, "checks": [{"name": "load_timeline", "pass": False, "detail": str(exc)}], "warnings": []}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"pass": False, "output": str(args.output)}, ensure_ascii=False))
        return 1

    checks.append({"name": "episodes_non_empty", "pass": bool(episodes), "count": len(episodes)})
    previous_end = -1.0
    for index, episode in enumerate(episodes, 1):
        prefix = f"episode_{index:03d}"
        try:
            start = as_float(episode.get("source_start", episode.get("start")), f"{prefix}.source_start")
            end = as_float(episode.get("source_end", episode.get("end")), f"{prefix}.source_end")
            engage = as_float(episode.get("engage_start", start), f"{prefix}.engage_start")
            outcome = as_float(episode.get("outcome_time", end), f"{prefix}.outcome_time")
            complete = bool(episode.get("complete", False))
            needs_review = bool(episode.get("needs_review", False))
            valid_range = 0 <= start < engage <= outcome <= end
            within_source = args.source_duration is None or end <= args.source_duration
            monotonic = start >= previous_end
            status = valid_range and within_source and monotonic and (complete or needs_review)
            checks.append(
                {
                    "name": prefix,
                    "pass": status,
                    "source_start": start,
                    "source_end": end,
                    "engage_start": engage,
                    "outcome_time": outcome,
                    "complete": complete,
                    "needs_review": needs_review,
                    "valid_range": valid_range,
                    "within_source": within_source,
                    "monotonic_non_overlapping": monotonic,
                }
            )
            if needs_review:
                warnings.append(f"{prefix} is marked needs_review")
            previous_end = end
        except (TypeError, ValueError) as exc:
            checks.append({"name": prefix, "pass": False, "detail": str(exc)})

    if args.source_duration is not None:
        checks.append({"name": "source_duration_valid", "pass": args.source_duration > 0, "source_duration": args.source_duration})

    if args.proxy_map is not None:
        try:
            payload = json.loads(args.proxy_map.read_text(encoding="utf-8"))
            offset = float(payload.get("proxy_offset", payload.get("offset", 0.0)))
            checks.append(
                {
                    "name": "proxy_source_offset",
                    "pass": abs(offset) <= 1.0 / 60.0 + 1e-6,
                    "proxy_offset": offset,
                    "threshold": "<= 1 frame @60fps",
                }
            )
        except (OSError, ValueError, TypeError) as exc:
            checks.append({"name": "proxy_source_offset", "pass": False, "detail": str(exc)})

    # Holes are deducted: the program length is what actually gets rendered, so
    # this must agree with qa_gate.py and read_episode_bounds.ps1.  All three
    # go through episode_geometry for exactly that reason.
    program_total = timeline_program_seconds(episodes)
    raw_total = timeline_raw_span_seconds(episodes)
    checks.append({"name": "program_sum_seconds", "pass": program_total > 0, "program_sum": program_total, "threshold": "> 0, matches program_map header ±0.01s"})
    if raw_total - program_total > 0.001:
        hole_count = sum(
            len(item["excluded_inside"])
            for item in episodes
            if isinstance(item.get("excluded_inside"), list)
        )
        checks.append({"name": "in_segment_holes_excavated", "pass": True, "excavated_seconds": round(raw_total - program_total, 3), "raw_span": raw_total, "hole_count": hole_count, "threshold": "informational: holes deducted from the program"})
    hole_problems = timeline_hole_problems(episodes)
    checks.append({"name": "in_segment_holes_valid", "pass": not hole_problems, "problems": hole_problems[:5], "threshold": "each hole inside its episode, positive length, not the whole episode (overlaps are merged, not rejected)"})

    deleted_checks = check_deleted_intervals(data, episodes)
    if deleted_checks:
        checks.extend(deleted_checks)
    else:
        warnings.append("No deleted_intervals/gaps audit was supplied")
        checks.append({"name": "deleted_intervals_audit_present", "pass": False, "count": 0})

    result = {
        "schema": "naraka-combat-roughcut-qa/v1",
        "timeline": str(args.timeline.resolve()),
        "episode_count": len(episodes),
        "checks": checks,
        "warnings": warnings,
        "pass": all(bool(item.get("pass")) for item in checks),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": result["pass"], "episodes": len(episodes), "output": str(args.output)}, ensure_ascii=False))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
