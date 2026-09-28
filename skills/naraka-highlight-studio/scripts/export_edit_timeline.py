from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from urllib.parse import quote
import xml.etree.ElementTree as ET

import opentimelineio as otio


def load_events(path: Path) -> list[dict]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    default_source = None
    if isinstance(payload, dict):
        default_source = payload.get("source")
        value = None
        for key in ("events", "combat_episodes", "episodes", "clips"):
            if isinstance(payload.get(key), list):
                value = payload[key]
                break
        if value is None:
            value = []
    else:
        value = payload
    if not isinstance(value, list):
        raise ValueError("timeline JSON must be a list or an object containing events, combat_episodes, episodes, or clips")

    events: list[dict] = []
    for item in value:
        event = dict(item)
        if default_source and not event.get("source") and not event.get("source_path"):
            event["source"] = default_source
        if "program_start" not in event and "timeline_start" in event:
            event["program_start"] = event["timeline_start"]
        if "program_end" not in event and "timeline_end" in event:
            event["program_end"] = event["timeline_end"]
        events.append(event)
    return events


def frames(seconds: float, fps: float) -> int:
    return max(0, int(round(float(seconds) * fps)))


def rt(seconds: float, fps: float) -> otio.opentime.RationalTime:
    return otio.opentime.RationalTime(frames(seconds, fps), fps)


def file_url(path: str | None) -> str:
    if not path:
        return ""
    candidate = Path(path)
    if candidate.exists():
        return candidate.resolve().as_uri()
    normalized = str(path).replace("\\", "/")
    return "file://localhost/" + quote(normalized, safe=":/")


def event_label(event: dict) -> str:
    types = event.get("event_types", [])
    if isinstance(types, str):
        return types
    return "+".join(str(value) for value in types) or "event"


def build_otio(events: list[dict], fps: float, name: str, bgm: str | None) -> otio.schema.Timeline:
    timeline = otio.schema.Timeline(name=name)
    timeline.global_start_time = rt(0, fps)
    timeline.metadata["naraka_highlight"] = {"fps": fps, "schema": "naraka-highlight-edit/v1"}
    video = otio.schema.Track(name="V1 Main Gameplay", kind="Video")
    audio_bgm = otio.schema.Track(name="A4 BGM", kind="Audio")
    cursor = 0.0
    total_end = 0.0
    for index, event in enumerate(events, 1):
        source = event.get("source") or event.get("source_path")
        source_start = float(event.get("source_start", event.get("start", 0.0)))
        source_end = float(event.get("source_end", event.get("end", source_start)))
        program_start = float(event.get("program_start", cursor))
        program_end = float(event.get("program_end", program_start + source_end - source_start))
        duration = max(0.0, program_end - program_start)
        if program_start > cursor:
            video.append(otio.schema.Gap(source_range=otio.opentime.TimeRange(duration=rt(program_start - cursor, fps))))
        reference = otio.schema.ExternalReference(target_url=file_url(str(source) if source else None))
        clip = otio.schema.Clip(
            name=f"event_{index:03d}_{event_label(event)}",
            media_reference=reference,
            source_range=otio.opentime.TimeRange(start_time=rt(source_start, fps), duration=rt(source_end - source_start, fps)),
        )
        clip.metadata["naraka_highlight"] = {
            "event_types": event.get("event_types", []),
            "effect_recipe": event.get("effect_recipe", "default"),
            "impact_source": event.get("impact_source"),
            "impact_program": event.get("impact_program"),
            "engage_start": event.get("engage_start"),
            "outcome_time": event.get("outcome_time"),
            "complete": event.get("complete"),
            "needs_review": event.get("needs_review"),
            "reason": event.get("reason", ""),
        }
        clip.markers.append(
            otio.schema.Marker(
                name=event_label(event),
                marked_range=otio.opentime.TimeRange(
                    start_time=rt(float(event.get("impact_source", source_start)) - source_start, fps),
                    duration=rt(1.0 / fps, fps),
                ),
                color="RED",
            )
        )
        video.append(clip)
        cursor = program_end
        total_end = max(total_end, program_end)

    if bgm:
        audio_bgm.append(
            otio.schema.Clip(
                name="BGM",
                media_reference=otio.schema.ExternalReference(target_url=file_url(bgm)),
                source_range=otio.opentime.TimeRange(duration=rt(total_end, fps)),
            )
        )
    timeline.tracks.append(video)
    if bgm:
        timeline.tracks.append(audio_bgm)
    return timeline


def add_text(parent: ET.Element, tag: str, value: object) -> ET.Element:
    child = ET.SubElement(parent, tag)
    child.text = str(value)
    return child


def append_rate(parent: ET.Element, fps: float) -> None:
    rate = ET.SubElement(parent, "rate")
    add_text(rate, "timebase", int(round(fps)))
    add_text(rate, "ntsc", "FALSE")


def append_file(root: ET.Element, source: str, file_id: str, fps: float) -> ET.Element:
    file_node = ET.SubElement(root, "file", {"id": file_id})
    add_text(file_node, "name", Path(source).name)
    add_text(file_node, "pathurl", file_url(source))
    file_media = ET.SubElement(file_node, "media")
    video = ET.SubElement(file_media, "video")
    sample = ET.SubElement(video, "samplecharacteristics")
    append_rate(sample, fps)
    add_text(sample, "width", 3840)
    add_text(sample, "height", 2160)
    add_text(sample, "pixelaspectratio", "Square")
    audio = ET.SubElement(file_media, "audio")
    add_text(audio, "samplecharacteristics", "48000")
    return file_node


def write_fcp_xml(events: list[dict], fps: float, name: str, bgm: str | None, output: Path) -> None:
    root = ET.Element("xmeml", {"version": "5"})
    sequence = ET.SubElement(root, "sequence", {"id": "sequence-1"})
    add_text(sequence, "name", name)
    total_end = max((float(item.get("program_end", 0.0)) for item in events), default=0.0)
    add_text(sequence, "duration", frames(total_end, fps))
    append_rate(sequence, fps)
    media = ET.SubElement(sequence, "media")
    video_media = ET.SubElement(media, "video")
    format_node = ET.SubElement(video_media, "format")
    sample = ET.SubElement(format_node, "samplecharacteristics")
    append_rate(sample, fps)
    add_text(sample, "width", 3840)
    add_text(sample, "height", 2160)
    video_track = ET.SubElement(video_media, "track")
    file_ids: dict[str, str] = {}
    for index, event in enumerate(events, 1):
        source = str(event.get("source") or event.get("source_path") or "")
        if source not in file_ids:
            file_ids[source] = f"file-{len(file_ids) + 1}"
            append_file(sequence, source, file_ids[source], fps)
        item = ET.SubElement(video_track, "clipitem", {"id": f"clipitem-{index}"})
        add_text(item, "name", f"event_{index:03d}_{event_label(event)}")
        append_rate(item, fps)
        source_start = float(event.get("source_start", event.get("start", 0.0)))
        source_end = float(event.get("source_end", event.get("end", source_start)))
        program_start = float(event.get("program_start", 0.0))
        program_end = float(event.get("program_end", program_start + source_end - source_start))
        add_text(item, "start", frames(program_start, fps))
        add_text(item, "end", frames(program_end, fps))
        add_text(item, "in", frames(source_start, fps))
        add_text(item, "out", frames(source_end, fps))
        add_text(item, "file", file_ids[source])
        marker = ET.SubElement(item, "marker")
        add_text(marker, "name", event_label(event))
        add_text(marker, "in", frames(float(event.get("impact_program", program_start)), fps))
        add_text(marker, "out", frames(float(event.get("impact_program", program_start)) + 1.0 / fps, fps))
    if bgm:
        audio_media = ET.SubElement(media, "audio")
        audio_track = ET.SubElement(audio_media, "track")
        item = ET.SubElement(audio_track, "clipitem", {"id": "bgm-1"})
        add_text(item, "name", "BGM")
        append_rate(item, fps)
        add_text(item, "start", 0)
        add_text(item, "end", frames(total_end, fps))
        add_text(item, "in", 0)
        add_text(item, "out", frames(total_end, fps))
        add_text(item, "file", "file-bgm")
        append_file(sequence, bgm, "file-bgm", fps)
    for event in events:
        marker = ET.SubElement(sequence, "marker")
        add_text(marker, "name", event_label(event))
        impact = float(event.get("impact_program", event.get("program_start", 0.0)))
        add_text(marker, "in", frames(impact, fps))
        add_text(marker, "out", frames(impact + 1.0 / fps, fps))
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=True)


def write_markers(events: list[dict], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["program_time", "source", "source_time", "event_types", "effect_recipe", "confidence", "reason"])
        writer.writeheader()
        for event in events:
            types = event.get("event_types", [])
            writer.writerow(
                {
                    "program_time": event.get("impact_program", event.get("program_start", 0.0)),
                    "source": event.get("source", event.get("source_path", "")),
                    "source_time": event.get("impact_source", event.get("source_start", 0.0)),
                    "event_types": "+".join(types) if isinstance(types, list) else types,
                    "effect_recipe": event.get("effect_recipe", "default"),
                    "confidence": event.get("confidence", ""),
                    "reason": event.get("reason", ""),
                }
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Export an event timeline to OTIO, Premiere XML, and marker CSV.")
    parser.add_argument("timeline", type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--name", default="Naraka Highlight")
    parser.add_argument("--fps", type=float, default=60.0)
    parser.add_argument("--bgm", type=Path)
    args = parser.parse_args()

    events = load_events(args.timeline)
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    timeline = build_otio(events, args.fps, args.name, str(args.bgm) if args.bgm else None)
    otio_path = output_dir / "master.otio"
    otio.adapters.write_to_file(timeline, str(otio_path))
    write_fcp_xml(events, args.fps, args.name, str(args.bgm) if args.bgm else None, output_dir / "premiere.xml")
    write_markers(events, output_dir / "markers.csv")
    (output_dir / "timeline_manifest.json").write_text(
        json.dumps({"schema": "naraka-highlight-edit/v1", "fps": args.fps, "events": len(events), "duration": timeline.duration().to_seconds(), "otio": str(otio_path)}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"events": len(events), "duration": timeline.duration().to_seconds(), "output_dir": str(output_dir)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
