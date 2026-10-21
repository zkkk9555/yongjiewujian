from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def check_file(path: Path) -> dict:
    return {"path": str(path), "exists": path.is_file(), "size_bytes": path.stat().st_size if path.is_file() else 0}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_srt_entries(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8-sig")
    blocks = re.split(r"\r?\n\r?\n", text.strip())
    stamp = re.compile(r"(\d+):(\d+):([\d.,]+)\s*-->\s*(\d+):(\d+):([\d.,]+)")

    def to_seconds(hour: str, minute: str, sec: str) -> float:
        return int(hour) * 3600 + int(minute) * 60 + float(sec.replace(",", "."))

    entries: list[dict] = []
    for block in blocks:
        match = stamp.search(block)
        if not match:
            continue
        entries.append(
            {
                "start": to_seconds(*match.group(1, 2, 3)),
                "end": to_seconds(*match.group(4, 5, 6)),
            }
        )
    return entries


def load_episode_ranges(path: Path) -> list[tuple[float, float]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    items: list = []
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        for key in ("combat_episodes", "episodes", "clips", "events"):
            if isinstance(data.get(key), list):
                items = data[key]
                break
    ranges: list[tuple[float, float]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            start = float(item.get("source_start", item.get("start", 0.0)))
            end = float(item.get("source_end", item.get("end", start)))
        except (TypeError, ValueError):
            continue
        if end > start:
            ranges.append((start, end))
    return ranges


def main() -> int:
    parser = argparse.ArgumentParser(description="Run lightweight delivery checks for a numbered Naraka task directory.")
    parser.add_argument("task", type=Path)
    parser.add_argument("--master", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument(
        "--burned-subtitles",
        action="store_true",
        help="Legacy flag, kept for compatibility. Passing it FAILs: burning is forbidden, all subtitles are external.",
    )
    parser.add_argument("--timeline", type=Path, default=None)
    parser.add_argument("--program-map", type=Path, default=None)
    parser.add_argument("--srt", type=Path, default=None)
    parser.add_argument("--srt-stats", type=Path, default=None)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    task = args.task.resolve()
    checks: list[dict] = []
    task_dir_name = task.name
    parent_dir_name = task.parent.name
    numbered_prefix = task_dir_name.split(".", 1)[0] if "." in task_dir_name else ""
    numbered_task_ok = parent_dir_name == "123" and numbered_prefix.isdigit()
    checks.append({"name": "numbered_task_path", "pass": numbered_task_ok})
    for name, path in (("master", args.master), ("preview", args.preview)):
        result = check_file(path)
        result.update({"name": name, "pass": result["exists"] and result["size_bytes"] > 0})
        checks.append(result)

    if args.burned_subtitles:
        checks.append(
            {
                "name": "no_burned_variant",
                "pass": False,
                "detail": "burning is forbidden; all subtitles are external-only",
            }
        )

    if args.srt is not None:
        srt_ok = args.srt.is_file()
        entry: dict = {"name": "subtitle_file_present", "path": str(args.srt), "exists": srt_ok, "pass": srt_ok}
        if srt_ok:
            entry["sha256"] = sha256_file(args.srt)
            entry["cues"] = len(parse_srt_entries(args.srt))
        checks.append(entry)

    if args.srt is not None and args.srt_stats is not None and args.srt.is_file() and args.srt_stats.is_file():
        try:
            stats = json.loads(args.srt_stats.read_text(encoding="utf-8"))
            cues = len(parse_srt_entries(args.srt))
            expected: int | None = None
            for key in ("count", "total", "cues"):
                if key in stats:
                    try:
                        expected = int(stats[key])
                    except (TypeError, ValueError):
                        continue
                    break
            checks.append(
                {
                    "name": "subtitle_stats_match",
                    "path": str(args.srt_stats),
                    "cues": cues,
                    "expected": expected,
                    "pass": expected is not None and expected == cues,
                }
            )
        except (OSError, ValueError) as exc:
            checks.append({"name": "subtitle_stats_match", "path": str(args.srt_stats), "pass": False, "detail": str(exc)})

    if args.srt is not None and args.timeline is not None and args.srt.is_file() and args.timeline.is_file():
        try:
            cues = parse_srt_entries(args.srt)
            ranges = load_episode_ranges(args.timeline)
            crossing = 0
            for cue in cues:
                for start, end in ranges:
                    if start < cue["start"] < end < cue["end"] or cue["start"] < start < cue["end"] < end:
                        if abs(cue["start"] - start) > 0.2 and abs(cue["end"] - end) > 0.2:
                            crossing += 1
                            break
            checks.append(
                {
                    "name": "subtitle_zero_cross_cut",
                    "srt": str(args.srt),
                    "timeline": str(args.timeline),
                    "crossing_cues": crossing,
                    "pass": crossing == 0,
                }
            )
        except (OSError, ValueError) as exc:
            checks.append({"name": "subtitle_zero_cross_cut", "pass": False, "detail": str(exc)})

    if args.program_map is not None:
        checks.append(
            {
                "name": "program_map_present",
                "path": str(args.program_map),
                "exists": args.program_map.is_file(),
                "pass": args.program_map.is_file(),
            }
        )

    result = {
        "schema": "naraka-highlight-delivery/v1",
        "task": str(task),
        "checks": checks,
        "pass": all(bool(item.get("pass")) for item in checks),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": result["pass"], "output": str(args.output)}, ensure_ascii=False))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
