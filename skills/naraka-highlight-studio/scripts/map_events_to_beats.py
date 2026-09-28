from __future__ import annotations

import argparse
import json
from pathlib import Path


MAJOR_EVENTS = {"parry", "counter", "clutch", "team_save", "ultimate", "kill", "multi_kill"}


def load_events(path: Path) -> list[dict]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(value, dict):
        value = value.get("events", value.get("event_candidates", []))
    if not isinstance(value, list):
        raise ValueError("events JSON must be a list or an object containing events")
    return [dict(item) for item in value]


def event_types(event: dict) -> set[str]:
    values = event.get("event_types", event.get("labels", []))
    if isinstance(values, str):
        values = [item.strip() for item in values.split(",") if item.strip()]
    return {str(item) for item in values}


def nearest_beat(beats: list[dict], target: float, minimum: float, major: bool) -> dict | None:
    available = [beat for beat in beats if float(beat["time"]) >= minimum]
    if not available:
        return None
    if major:
        strong = [beat for beat in available if bool(beat.get("strong"))]
        if strong:
            available = strong
    return min(available, key=lambda beat: abs(float(beat["time"]) - target))


def main() -> int:
    parser = argparse.ArgumentParser(description="Place event packs on a BGM beat map and create a program timeline.")
    parser.add_argument("events", type=Path)
    parser.add_argument("beatmap", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--gap", type=float, default=0.04)
    args = parser.parse_args()

    events = sorted(load_events(args.events), key=lambda item: float(item.get("start", 0.0)))
    beatmap = json.loads(args.beatmap.read_text(encoding="utf-8"))
    beats = list(beatmap.get("beats", []))
    timeline: list[dict] = []
    cursor = 0.0
    for index, event in enumerate(events, 1):
        source_start = float(event.get("start", 0.0))
        source_end = float(event.get("end", source_start))
        duration = max(0.05, source_end - source_start)
        impact = float(event.get("impact", source_start + duration * 0.5))
        relative_impact = max(0.0, min(duration, impact - source_start))
        types = event_types(event)
        target_impact = cursor + relative_impact
        beat = nearest_beat(beats, target_impact, cursor + relative_impact, bool(types & MAJOR_EVENTS))
        program_impact = float(beat["time"]) if beat else target_impact
        program_start = max(cursor, program_impact - relative_impact)
        program_end = program_start + duration
        timeline.append(
            {
                "program_index": index,
                "source": event.get("source", event.get("source_path")),
                "source_start": round(source_start, 4),
                "source_end": round(source_end, 4),
                "program_start": round(program_start, 4),
                "program_end": round(program_end, 4),
                "impact_source": round(impact, 4),
                "impact_program": round(program_start + relative_impact, 4),
                "event_types": sorted(types),
                "confidence": event.get("confidence"),
                "reason": event.get("reason", ""),
                "beat_index": beat.get("index") if beat else None,
                "beat_time": round(float(beat["time"]), 4) if beat else None,
                "effect_recipe": event.get("effect_recipe", sorted(types)[0] if types else "default"),
            }
        )
        cursor = program_end + args.gap

    result = {
        "schema": "naraka-highlight-program-timeline/v1",
        "beatmap": str(args.beatmap.resolve()),
        "duration": round(cursor, 4),
        "events": timeline,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"events": len(timeline), "duration": result["duration"], "output": str(args.output)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
