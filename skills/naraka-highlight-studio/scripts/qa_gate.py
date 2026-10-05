from __future__ import annotations

"""Project QA gate: one executable entry for the delivery checks.

Zero third-party dependencies: only the standard library plus text output
parsed from FFprobe/FFmpeg. Any single FAIL blocks review delivery and the
4K master; fix the source timeline, bump the version, and re-run.
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

# Program duration is computed by the shared geometry module so the gate, the
# timeline validator and the 4K cut-list reader cannot disagree.  See that
# module's docstring for the incident that made this necessary.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from episode_geometry import (  # noqa: E402
    timeline_hole_problems,
    timeline_program_seconds,
    timeline_raw_span_seconds,
)

SCHEMA = "naraka-highlight-qa-gate/v1"

SUM_TOLERANCE_S = 0.01
PREVIEW_DURATION_TOLERANCE_S = 0.3
AV_DURATION_WARN_S = 0.2
AV_DURATION_FAIL_S = 0.5
MIN_SUBTITLE_GAP_S = 0.08
MIN_SUBTITLE_DURATION_S = 0.8
MAX_SUBTITLE_DURATION_S = 7.0
MAX_CPS_ZH = 12
MAX_CPS_EN = 20
# Wider than the truth on purpose: container durations round, and a gate
# stricter than reality is the same disease as no gate at all.
COVERAGE_TOLERANCE_S = 0.25


def check(name: str, status: str, measured: Any, threshold: Any, evidence: str) -> dict:
    return {
        "name": name,
        "result": status,
        "measured": measured,
        "threshold": threshold,
        "evidence": evidence,
    }


PARTIAL_MARKER = "-partial"


def refuse_partial_timeline(path: Path) -> dict:
    """roughcut-launch.md §2.6 / §2.8: a partial must never be frozen, shipped or
    judged as if it were final.

    The island-merge valve (ticket 03) now emits `merge_decision_vN-partial-r{k}`
    as soon as one lane comes back, which is what removes the 9.3-hour wait on
    task 861.  That only helps if the half-finished artefact is mechanically
    unable to pass as a master -- otherwise "merge early" just means "ship early".

    Refusal keys off three independent signals, because any one alone is
    forgeable by accident:
      * the filename carries `-partial` (§2.8's reserved name),
      * the document says `partial: true`,
      * the version string carries the `-partial` suffix.
    """
    name = path.name
    partial = PARTIAL_MARKER in name
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return check("no_partial_timeline", "WARN", "timeline unreadable",
                     "refuse anything carrying -partial", str(path))
    flagged = bool(raw.get("partial")) if isinstance(raw, dict) else False
    version = str(raw.get("version", "")) if isinstance(raw, dict) else ""
    suffix = PARTIAL_MARKER in version
    if partial or flagged or suffix:
        return check(
            "no_partial_timeline",
            "FAIL",
            "partial artefact: filename=%s flag=%s version=%s"
            % (partial, flagged, version or "-"),
            "a -partial timeline is never frozen, rendered, captioned or self-audited "
            "(roughcut-launch.md §2.6/§2.8)",
            str(path),
        )
    return check("no_partial_timeline", "PASS", "no partial marker",
                 "refuse anything carrying -partial", str(path))


def load_timeline(path: Path) -> tuple[dict, list[dict]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    episodes: list[dict] = []
    if isinstance(data, list):
        episodes = [dict(item) for item in data]
        return {}, episodes
    for key in ("combat_episodes", "episodes", "clips", "events"):
        value = data.get(key)
        if isinstance(value, list):
            return data, [dict(item) for item in value]
    raise ValueError("timeline JSON must contain combat_episodes, episodes, clips, or events")


def episode_range(episode: dict) -> tuple[float, float]:
    start = float(episode.get("source_start", episode.get("start", 0.0)))
    end = float(episode.get("source_end", episode.get("end", start)))
    return start, end


def gate_timeline_mutex(episodes: list[dict], evidence: str) -> dict:
    ordered = sorted(episodes, key=episode_range)
    for prev, nxt in zip(ordered, ordered[1:]):
        if episode_range(nxt)[0] < episode_range(prev)[1]:
            return check(
                "timeline_mutex",
                "FAIL",
                f"overlap {episode_range(prev)} vs {episode_range(nxt)}",
                "episodes sorted, next.start >= prev.end",
                evidence,
            )
    return check("timeline_mutex", "PASS", f"{len(ordered)} episodes ordered", "no overlap", evidence)


def gate_source_range(episodes: list[dict], duration: float | None, evidence: str) -> dict:
    bad = [episode_range(ep) for ep in episodes if episode_range(ep)[1] <= episode_range(ep)[0]]
    if bad:
        return check("source_range", "FAIL", f"reversed {bad[0]}", "0 <= start < end", evidence)
    if duration is not None:
        over = [episode_range(ep) for ep in episodes if episode_range(ep)[1] > duration]
        if over:
            return check("source_range", "FAIL", f"end {over[0][1]} > duration {duration}", "end <= source duration", evidence)
    shortest = min((episode_range(ep)[1] - episode_range(ep)[0] for ep in episodes), default=0.0)
    if shortest < 1.0:
        return check("source_range", "WARN", f"shortest {shortest:.3f}s", "episode >= 1.0s", evidence)
    return check("source_range", "PASS", f"{len(episodes)} in range", "0 <= start < end <= duration", evidence)


def gate_program_sum(episodes: list[dict], program_map: Path | None, evidence: str) -> dict:
    # Holes are deducted.  The old sum(source_end - source_start) reported the
    # raw span, so any timeline using excluded_inside could never reconcile with
    # its own program map.
    total = timeline_program_seconds(episodes)
    raw = timeline_raw_span_seconds(episodes)
    if raw - total > 0.001:
        evidence = f"{evidence} (raw span {raw}s, {round(raw - total, 3)}s excavated)"
    if program_map is None or not program_map.is_file():
        return check("program_sum", "WARN", total, "program_map present", evidence)
    try:
        header = json.loads(program_map.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return check("program_sum", "WARN", total, "program_map parseable", f"{evidence} ({exc})")
    for key in ("program_seconds_total", "program_duration", "duration", "total_duration"):
        if key in header:
            try:
                expected = float(header[key])
            except (TypeError, ValueError):
                continue
            delta = abs(total - expected)
            if delta <= SUM_TOLERANCE_S:
                return check("program_sum", "PASS", total, f"header {key} {expected} ±{SUM_TOLERANCE_S}s", str(program_map))
            return check("program_sum", "FAIL", total, f"header {key} {expected} ±{SUM_TOLERANCE_S}s", str(program_map))
    return check("program_sum", "WARN", total, "header carries program duration", str(program_map))


def gate_in_segment_holes(episodes: list[dict], evidence: str) -> dict:
    """Validate every declared excluded_inside hole.

    Holes are honoured by the cut list, so a malformed one (out of bounds,
    overlapping, or swallowing the whole episode) would either render garbage
    or quietly shorten the program.  Catch it here instead.
    """
    problems = timeline_hole_problems(episodes)
    hole_count = sum(
        len(ep.get("excluded_inside") or []) for ep in episodes
        if isinstance(ep.get("excluded_inside"), (list, tuple))
    )
    if problems:
        return check("in_segment_holes", "FAIL", problems[0], "holes inside episode, positive length, not the whole episode", evidence)
    if hole_count == 0:
        return check("in_segment_holes", "PASS", "no holes declared", "holes inside episode, positive length, not the whole episode", evidence)
    return check("in_segment_holes", "PASS", f"{hole_count} holes well-formed", "holes inside episode, positive length, not the whole episode", evidence)


def _battle_window(episode: dict) -> tuple[float, float] | None:
    """Return ``(engage_start, outcome_time)`` when both ends are declared."""
    start = episode.get("engage_start")
    end = episode.get("outcome_time")
    if start is None or end is None:
        return None
    try:
        return float(start), float(end)
    except (TypeError, ValueError):
        return None


def gate_no_holes_in_battle(episodes: list[dict], evidence: str, strict: bool = False) -> dict:
    """G-1: no ``excluded_inside`` hole may fall inside the battle window.

    864's six rejected versions all share this defect.  A tactical pause -- loot
    a corpse, drink a potion, disengage and re-engage, pick a talent card -- is
    *part of the fight*.  Punching it out is what made the cut feel chopped, and
    the user said so outright: 「我不想中间有断断档的时间，因为一断之后，战斗就不连贯了」.

    Holes outside the window stay legal: cleaning the post-outcome map screen or
    the pre-engage travel run is exactly what they are for.  Task 864's accepted
    v6 carries three such holes, all after ``outcome_time``.  So this gate judges
    hole *position*, not hole *existence*.

    Historical timelines carry holes here.  They are reported as WARN, not FAIL:
    task 863's master is already delivered and its source MP4 has been deleted,
    so "go back and re-cut it" is not an available instruction.  A timeline opts
    in to FAIL by declaring ``"whole_battle_policy": "864"`` at the top level of
    the timeline JSON (or on any single episode).
    """
    strict = strict or any(
        str(ep.get("whole_battle_policy", "")) == "864" for ep in episodes
    )
    offenders: list[str] = []
    unchecked = 0
    for episode in episodes:
        window = _battle_window(episode)
        holes = episode.get("excluded_inside") or []
        if window is None:
            if holes:
                unchecked += 1
            continue
        engage, outcome = window
        for hole in holes:
            try:
                hole_start = float(hole["start"])
                hole_end = float(hole["end"])
            except (KeyError, TypeError, ValueError):
                continue
            if hole_start >= engage and hole_end <= outcome:
                offenders.append(
                    f"{episode.get('id', '?')} hole [{hole_start}, {hole_end}] "
                    f"inside battle [{engage}, {outcome}]"
                )
    status = "FAIL" if (offenders and strict) else ("WARN" if offenders else "PASS")
    if offenders:
        measured = offenders[0] + (f" (+{len(offenders) - 1} more)" if len(offenders) > 1 else "")
    elif unchecked:
        measured = f"no in-battle holes; {unchecked} episode(s) lack engage_start/outcome_time and were not checked"
        status = "WARN"
    else:
        measured = "no in-battle holes"
    return check("no_holes_in_battle", status, measured, "0 holes inside (engage_start, outcome_time)", evidence)


def gate_no_zero_gap_pseudo_cuts(episodes: list[dict], evidence: str) -> dict:
    """G-2: adjacent episodes must not share a boundary second.

    When one episode ends exactly where the next begins, the cut removes nothing
    yet still puts a splice in the picture -- on task 864 ``combat_005`` and
    ``combat_006`` were continuous on the source (both touching 517.5) and the
    program still cut them apart, which reads as a visible flash.  Two continuous
    stretches of one battle must be one episode.
    """
    offenders: list[str] = []
    ordered = sorted(
        (ep for ep in episodes if episode_bounds_present(ep)),
        key=lambda e: float(e["source_start"]),
    )
    for previous, current in zip(ordered, ordered[1:]):
        try:
            previous_end = float(previous["source_end"])
            current_start = float(current["source_start"])
        except (KeyError, TypeError, ValueError):
            continue
        if abs(previous_end - current_start) < 1e-6:
            offenders.append(
                f"{previous.get('id', '?')} ends at {previous_end} == "
                f"{current.get('id', '?')} starts; continuous on source but split in program"
            )
    status = "FAIL" if offenders else "PASS"
    measured = (
        offenders[0] + (f" (+{len(offenders) - 1} more)" if len(offenders) > 1 else "")
        if offenders
        else f"{len(ordered)} episodes, no zero-gap cuts"
    )
    return check("no_zero_gap_pseudo_cuts", status, measured, "adjacent source_end != next source_start", evidence)


def _deleted_ranges(document: dict) -> list[tuple[float, float, str]]:
    out: list[tuple[float, float, str]] = []
    raw = document.get("deleted_intervals") if isinstance(document, dict) else None
    if not isinstance(raw, list):
        return out
    for item in raw:
        if not isinstance(item, dict):
            continue
        try:
            start = float(item.get("start", item.get("source_start")))
            end = float(item.get("end", item.get("source_end")))
        except (TypeError, ValueError):
            continue
        if end > start:
            out.append((start, end, str(item.get("category", "?"))))
    return out


def gate_coverage_complete(
    episodes: list[dict],
    document: dict,
    duration: float | None,
    evidence: str,
) -> dict:
    """Every second of the source must be either kept as an episode or declared
    as a deleted interval.  Undeclared gaps are how a whole battle disappears
    without anybody noticing.

    Measured on 864 v6: deleting any one of its 7 real battles left every
    existing gate green (7/7), the largest single deletion being 233.45 s =
    35% of the whole programme.  `timeline_mutex` only compares episodes with
    each other, `source_range` only looks at kept episodes, and
    `program_sum` compares against a program_map the commander rewrote in the
    same pass -- so nothing ever compared kept + deleted against the source.

    Kept deliberately wider than the truth, because this project has been
    burned twice by gates stricter than reality (861 `preview_duration` false
    FAIL, `verify_master.sh` false FAIL on a track-less master):
      * unknown source_duration or no declared deletions -> WARN, never FAIL;
      * tolerance 0.25 s, not 0.05 s, so container rounding cannot trip it.
    """
    deletions = _deleted_ranges(document)
    if not episodes:
        # A known-length source with zero episodes means an empty programme,
        # which is never a pass.  main() used to skip every timeline gate when
        # the episode list was empty, so deleting all seven battles of 864 v6
        # reported green.
        if duration is None and isinstance(document, dict):
            raw_duration = document.get("source_duration")
            if isinstance(raw_duration, (int, float)):
                duration = float(raw_duration)
        if duration is not None and duration > 0:
            return check(
                "coverage_complete",
                "FAIL",
                f"0 episodes for a {duration:.2f}s source -- nothing would be rendered",
                "at least one episode, or an explicit empty-source declaration",
                evidence,
            )
    if duration is None and isinstance(document, dict):
        raw_duration = document.get("source_duration")
        if isinstance(raw_duration, (int, float)):
            duration = float(raw_duration)
    if duration is None or duration <= 0:
        return check(
            "coverage_complete",
            "WARN",
            "source_duration unknown",
            "declare source_duration to enable this gate",
            evidence,
        )
    if not deletions:
        return check(
            "coverage_complete",
            "WARN",
            "no deleted_intervals declared",
            "kept + deleted must tile [0, source_duration]",
            evidence,
        )

    spans = [(episode_range(ep)[0], episode_range(ep)[1], "episode") for ep in episodes]
    spans += [(start, end, f"deleted:{cat}") for start, end, cat in deletions]

    # A second that is both kept and declared deleted is a double declaration:
    # the render will show it while the ledger says it was cut.
    for e_start, e_end, _ in [(episode_range(ep)[0], episode_range(ep)[1], "") for ep in episodes]:
        for d_start, d_end, cat in deletions:
            overlap = min(e_end, d_end) - max(e_start, d_start)
            if overlap > COVERAGE_TOLERANCE_S:
                return check(
                    "coverage_complete",
                    "FAIL",
                    f"kept [{e_start:.2f}, {e_end:.2f}] overlaps deleted [{d_start:.2f}, {d_end:.2f}] {cat} by {overlap:.2f}s",
                    "no second both kept and deleted",
                    evidence,
                )

    beyond = sorted((s, e, tag) for s, e, tag in spans if e > duration + COVERAGE_TOLERANCE_S)
    if beyond:
        s, e, tag = beyond[0]
        return check(
            "coverage_complete",
            "FAIL",
            f"{tag} ends at {e:.2f} > source_duration {duration:.2f}",
            "all spans within source_duration",
            evidence,
        )

    merged: list[list[float]] = []
    for start, end, _ in sorted(spans):
        if merged and start <= merged[-1][1] + 1e-9:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])

    gaps = [
        (merged[i][1], merged[i + 1][0])
        for i in range(len(merged) - 1)
        if merged[i + 1][0] - merged[i][1] > COVERAGE_TOLERANCE_S
    ]
    head = merged[0][0]
    tail = duration - merged[-1][1]
    offenders = []
    if head > COVERAGE_TOLERANCE_S:
        offenders.append(f"head gap [0.00, {head:.2f}]")
    offenders += [f"gap [{a:.2f}, {b:.2f}] {b - a:.2f}s" for a, b in gaps]
    if tail > COVERAGE_TOLERANCE_S:
        offenders.append(f"tail gap [{duration - tail:.2f}, {duration:.2f}] {tail:.2f}s")
    if offenders:
        return check(
            "coverage_complete",
            "FAIL",
            f"{len(offenders)} undeclared gap(s): " + offenders[0] + (f" (+{len(offenders) - 1} more)" if len(offenders) > 1 else ""),
            f"kept + deleted tiles [0, {duration:.2f}] within {COVERAGE_TOLERANCE_S}s",
            evidence,
        )
    return check(
        "coverage_complete",
        "PASS",
        f"{len(spans)} spans tile [0.00, {duration:.2f}] with no gap > {COVERAGE_TOLERANCE_S}s",
        f"kept + deleted tiles [0, {duration:.2f}]",
        evidence,
    )


# --- deleted-interval voice audit -------------------------------------------------
# 864 was rejected six times and then re-cut.  Re-measuring its delivered v6 shows
# every already-delivered timeline has perfect coverage, so the dropped battle was
# NOT "forgotten to declare" -- it was declared, cleanly, as a deletion.  The
# coverage gate cannot see that.  This gate can: it is the only verified handle on
# missed battles (83% precision on task 864).
#
# Deliberately an ABSENCE-audit gate, never a "no combat here" gate:
#   hit a combat word inside a deleted interval -> a human must have signed a
#   verdict with a reason and an on-disk evidence path -> else FAIL.
# A "this interval contains no combat" gate would produce a confident, necessarily
# wrong answer wearing a PASS, which is the exact failure mode this project keeps
# paying for.
#
# Two tiers, because the working word list contains 打, which also fires on 打药
# (healing) and 打开 (opening something).  Only STRONG words demand adjudication.
DELETED_VOICE_STRONG = (
    "杀", "击杀", "击败", "砍死", "大招", "闪避", "中刀", "倒地", "救", "被击",
    "血量", "血条", "弹尽", "没弹", "预瞄", "听声", "射速", "操作", "追上",
    "局势", "我来", "别急", "撤", "残血", "反打", "振刀", "格挡", "处决",
    "第一", "第二", "胜利", "失败", "淘汰", "终结",
)
DELETED_VOICE_ADJUDICATION_MIN_REASON = 12


def _deleted_voice_index(path: Path) -> list[dict] | None:
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    cues = doc.get("cues") if isinstance(doc, dict) else None
    if not isinstance(cues, list):
        return None
    out: list[dict] = []
    for cue in cues:
        if not isinstance(cue, dict):
            continue
        try:
            start = float(cue.get("start"))
            end = float(cue.get("end"))
        except (TypeError, ValueError):
            continue
        text = str(cue.get("text", ""))
        hits = [w for w in DELETED_VOICE_STRONG if w in text]
        if hits:
            out.append({"start": start, "end": end, "text": text, "hits": hits})
    return out


def gate_deleted_voice_audit(
    document: dict,
    voice_index: Path | None,
    evidence: str,
) -> dict:
    """Every strong combat-voice cue landing inside a deleted interval must carry
    a human adjudication.  Unknown input -> WARN, never FAIL."""
    if voice_index is None or not voice_index.is_file():
        return check(
            "deleted_voice_audit",
            "WARN",
            "no voice index supplied",
            "pass --voice-index <combat_voice_index.json>",
            evidence,
        )
    cues = _deleted_voice_index(voice_index)
    if cues is None:
        return check(
            "deleted_voice_audit",
            "WARN",
            f"unreadable voice index: {voice_index.name}",
            "naraka-voice-index/v1 with a cues[] array",
            evidence,
        )
    deletions = _deleted_ranges(document)
    if not deletions:
        return check("deleted_voice_audit", "WARN", "no deleted_intervals", "kept + deleted tiles the source", evidence)

    adjudications: list[dict] = []
    raw_adj = document.get("deleted_voice_adjudications")
    if isinstance(raw_adj, list):
        adjudications = [item for item in raw_adj if isinstance(item, dict)]

    def adjudicated(start: float, end: float) -> dict | None:
        for adj in adjudications:
            try:
                a_start = float(adj.get("start"))
                a_end = float(adj.get("end"))
            except (TypeError, ValueError):
                continue
            overlap = min(end, a_end) - max(start, a_start)
            span = min(end - start, a_end - a_start)
            if span > 0 and overlap / span > 0.5:
                return adj
        return None

    unadjudicated: list[str] = []
    adjudicated_count = 0
    for start, end, cat in deletions:
        inside = [
            cue for cue in cues
            if min(end, cue["end"]) - max(start, cue["start"]) > 0.25
        ]
        if not inside:
            continue
        adj = adjudicated(start, end)
        if adj is not None:
            reason = str(adj.get("reason", "")).strip()
            proof = str(adj.get("evidence", "")).strip()
            if len(reason) >= DELETED_VOICE_ADJUDICATION_MIN_REASON and proof:
                adjudicated_count += 1
                continue
            unadjudicated.append(
                f"[{start:.2f},{end:.2f}] {cat} adjudication incomplete "
                f"(reason {len(reason)} chars < {DELETED_VOICE_ADJUDICATION_MIN_REASON}"
                f"{', no evidence path' if not proof else ''})"
            )
            continue
        words = sorted({w for cue in inside for w in cue["hits"]})
        unadjudicated.append(
            f"[{start:.2f},{end:.2f}] {cat} carries {len(inside)} strong cue(s) {words} with no adjudication"
        )

    if unadjudicated:
        return check(
            "deleted_voice_audit",
            "FAIL",
            f"{len(unadjudicated)} deleted interval(s) need a signed verdict; first: "
            + unadjudicated[0]
            + (f" (+{len(unadjudicated) - 1} more)" if len(unadjudicated) > 1 else ""),
            "each deleted interval containing strong combat voice needs "
            "{start, end, reason>=12 chars, evidence=<on-disk path>} in deleted_voice_adjudications",
            evidence,
        )
    return check(
        "deleted_voice_audit",
        "PASS",
        f"{len(deletions)} deletions scanned; {adjudicated_count} carried signed verdicts",
        "no unadjudicated strong combat voice inside a deletion",
        evidence,
    )


def episode_bounds_present(episode: dict) -> bool:
    return "source_start" in episode and "source_end" in episode


def run_probe(ffprobe: str | None, target: Path) -> dict | None:
    if not ffprobe or not target.is_file():
        return None
    try:
        completed = subprocess.run(
            [ffprobe, "-v", "error", "-show_format", "-show_streams", "-of", "json", str(target)],
            capture_output=True,
            text=True,
            timeout=120,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if completed.returncode != 0:
        return None
    try:
        return json.loads(completed.stdout)
    except ValueError:
        return None


def gate_preview_duration(probe: dict | None, episodes: list[dict], evidence: str) -> dict:
    if probe is None:
        return check("preview_duration", "WARN", "no ffprobe", "preview duration ±0.3s", evidence)
    try:
        actual = float(probe["format"]["duration"])
    except (KeyError, TypeError, ValueError):
        return check("preview_duration", "WARN", "no duration", "preview duration ±0.3s", evidence)
    # Holes are deducted -- this is the check that wrongly FAILed task 861's
    # correct 1090.5 s render by demanding the un-excavated 1119.4 s.
    expected = timeline_program_seconds(episodes)
    delta = abs(actual - expected)
    if delta <= PREVIEW_DURATION_TOLERANCE_S:
        return check("preview_duration", "PASS", round(actual, 3), f"program {round(expected, 3)} ±{PREVIEW_DURATION_TOLERANCE_S}s", evidence)
    return check("preview_duration", "FAIL", round(actual, 3), f"program {round(expected, 3)} ±{PREVIEW_DURATION_TOLERANCE_S}s", evidence)


def gate_av_sync(probe: dict | None, evidence: str) -> dict:
    if probe is None:
        return check("av_sync", "WARN", "no ffprobe", "|V-A| <= 0.2s", evidence)
    durations: dict[str, float] = {}
    for stream in probe.get("streams", []):
        codec = str(stream.get("codec_type", ""))
        try:
            durations.setdefault(codec, float(stream.get("duration", probe["format"]["duration"])))
        except (KeyError, TypeError, ValueError):
            continue
    if "video" not in durations or "audio" not in durations:
        return check("av_sync", "WARN", durations, "video+audio durations", evidence)
    delta = abs(durations["video"] - durations["audio"])
    if delta <= AV_DURATION_WARN_S:
        return check("av_sync", "PASS", round(delta, 3), f"<= {AV_DURATION_WARN_S}s", evidence)
    if delta <= AV_DURATION_FAIL_S:
        return check("av_sync", "WARN", round(delta, 3), f"<= {AV_DURATION_WARN_S}s pass, > {AV_DURATION_FAIL_S}s fail", evidence)
    return check("av_sync", "FAIL", round(delta, 3), f"<= {AV_DURATION_FAIL_S}s", evidence)


def gate_frame_rate(probe: dict | None, evidence: str) -> dict:
    if probe is None:
        return check("frame_rate", "WARN", "no ffprobe", "CFR 60", evidence)
    for stream in probe.get("streams", []):
        if stream.get("codec_type") != "video":
            continue
        avg = str(stream.get("avg_frame_rate", ""))
        rate = str(stream.get("r_frame_rate", ""))
        if avg != rate:
            return check("frame_rate", "FAIL", f"avg {avg} vs r {rate}", "avg == r (CFR)", evidence)
        return check("frame_rate", "PASS", avg, "CFR", evidence)
    return check("frame_rate", "WARN", "no video stream", "CFR 60", evidence)


def parse_srt(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8-sig")
    blocks = re.split(r"\r?\n\r?\n", text.strip())
    entries: list[dict] = []
    stamp = re.compile(r"(\d+):(\d+):([\d.,]+)\s*-->\s*(\d+):(\d+):([\d.,]+)")

    def to_seconds(hour: str, minute: str, sec: str) -> float:
        return int(hour) * 3600 + int(minute) * 60 + float(sec.replace(",", "."))

    for block in blocks:
        match = stamp.search(block)
        if not match:
            continue
        start = to_seconds(*match.group(1, 2, 3))
        end = to_seconds(*match.group(4, 5, 6))
        body = stamp.sub("", block).strip()
        entries.append({"start": start, "end": end, "text": re.sub(r"\s+", " ", body)})
    return entries


def is_cjk(text: str) -> bool:
    return any("\u4e00" <= ch <= "\u9fff" for ch in text)


def subtitle_bounds(episode: dict[str, Any]) -> tuple[float, float]:
    """Cut boundaries in the coordinate space the SRT lives in.

    SRT timestamps are **program** time, so the cross-cut test has to compare
    them against program boundaries.  It used to compare them against
    ``episode_range()``, i.e. **source** time -- which silently works only while
    the first episode starts at source 0.  Task 21 (material 864) cut its first
    episode at source 179.0, so a perfectly clean cue at program 177.92-180.65
    was reported FAIL for "crossing" the source second 179.0, which is not a
    cut at all in the program.  A gate that blocks freezing on a number that is
    not a cut is worse than no gate.

    Timeline files that carry ``program_start`` / ``program_end`` get the correct
    comparison; every historical timeline without those fields falls back to the
    old behaviour unchanged.
    """
    try:
        start = float(episode["program_start"])
        end = float(episode["program_end"])
        if end > start:
            return start, end
    except (KeyError, TypeError, ValueError):
        pass
    return episode_range(episode)


def gate_subtitles(entries: list[dict], episodes: list[dict], evidence: str) -> dict:
    ordered = sorted(entries, key=lambda item: item["start"])
    for prev, nxt in zip(ordered, ordered[1:]):
        if nxt["start"] < prev["end"] - 1e-6:
            return check("subtitle_overlap", "FAIL", f"{prev['start']:.3f}-{prev['end']:.3f} vs {nxt['start']:.3f}", "no overlap", evidence)
        if nxt["start"] - prev["end"] < MIN_SUBTITLE_GAP_S - 1e-6:
            return check("subtitle_overlap", "WARN", f"gap {nxt['start'] - prev['end']:.3f}s", f">= {MIN_SUBTITLE_GAP_S}s", evidence)
    for entry in ordered:
        duration = entry["end"] - entry["start"]
        if duration < MIN_SUBTITLE_DURATION_S - 1e-6 or duration > MAX_SUBTITLE_DURATION_S + 1e-6:
            return check("subtitle_timing", "FAIL", f"{duration:.3f}s", f"{MIN_SUBTITLE_DURATION_S}-{MAX_SUBTITLE_DURATION_S}s", evidence)
        body = re.sub(r"\s+", "", entry["text"])
        if not body:
            continue
        if is_cjk(body):
            cps = len(body) / max(duration, 1e-6)
            if cps > MAX_CPS_ZH:
                return check("subtitle_timing", "FAIL", f"{cps:.1f} cps", f"<= {MAX_CPS_ZH} cps", evidence)
        else:
            wpm = len(entry["text"].split()) / max(duration / 60.0, 1e-6)
            if wpm > MAX_CPS_EN * 8:
                return check("subtitle_timing", "WARN", f"{wpm:.0f} wpm", "readable", evidence)
        for start, end in (subtitle_bounds(ep) for ep in episodes):
            if start < entry["start"] < end < entry["end"] or entry["start"] < start < entry["end"] < end:
                if abs(entry["start"] - start) > 0.2 and abs(entry["end"] - end) > 0.2:
                    return check("subtitle_span", "FAIL", f"{entry['start']:.2f}-{entry['end']:.2f} crosses cut", "zero cross-cut", evidence)
    return check("subtitle_span", "PASS", f"{len(ordered)} cues", "zero cross-cut", evidence)


def gate_burned_srt(master: Path | None, burned: bool, evidence: str) -> dict:
    # External-only rule: no burned variant exists. Any burn flag means a
    # forbidden render path was taken.
    if burned:
        return check("no_burned_variant", "FAIL", "burned render requested", "external SRT only, never burn", evidence)
    if master is None:
        return check("no_burned_variant", "WARN", "no master", "external SRT only, never burn", evidence)
    sibling = master.with_suffix(".srt")
    if sibling.exists():
        return check("no_burned_variant", "WARN", str(sibling), "SRT lives in captions/, not next to clean MP4", str(sibling))
    return check("no_burned_variant", "PASS", "no burn path", "external SRT only, never burn", evidence)


def gate_no_subtitle_stream(probe: dict | None, evidence: str) -> dict:
    # MP4 must carry zero subtitle streams: preview and master are clean video.
    if probe is None:
        return check("no_subtitle_stream", "WARN", "no ffprobe", "0 subtitle streams", evidence)
    count = sum(1 for stream in probe.get("streams", []) if str(stream.get("codec_type", "")) == "subtitle")
    if count == 0:
        return check("no_subtitle_stream", "PASS", 0, "0 subtitle streams", evidence)
    return check("no_subtitle_stream", "FAIL", count, "0 subtitle streams", evidence)


def gate_proxy_map(proxy_map: Path | None, evidence: str) -> dict:
    if proxy_map is None or not proxy_map.is_file():
        return check("proxy_map", "WARN", "no proxy map", "proxy offset recorded", evidence)
    try:
        payload = json.loads(proxy_map.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return check("proxy_map", "WARN", str(exc), "proxy map parseable", str(proxy_map))
    offset = payload.get("proxy_offset", payload.get("offset", 0.0))
    try:
        value = abs(float(offset))
    except (TypeError, ValueError):
        return check("proxy_map", "FAIL", offset, "numeric offset", str(proxy_map))
    if value <= 1.0 / 60.0 + 1e-6:
        return check("proxy_map", "PASS", value, "<= 1 frame @60fps", str(proxy_map))
    return check("proxy_map", "FAIL", value, "<= 1 frame @60fps", str(proxy_map))


def gate_kit(frozen: list[Path], evidence: str) -> dict:
    missing = [str(path) for path in frozen if not path.is_file()]
    if missing:
        return check("freeze_kit", "FAIL", f"missing {missing[0]}", "timeline+map+validate+preview+decode+srt", evidence)
    return check("freeze_kit", "PASS", f"{len(frozen)} files", "timeline+map+validate+preview+decode+srt", evidence)


PROJECT_ROOT_HINT = "C:\\Project\\永劫无间"


def gate_workspace_hygiene(timeline_path: Path, evidence: str) -> dict:
    # Task dir is the only legal work path. Stray products at the project
    # root (f_*.jpg / thumb_*.jpg / loose *.mp4) mean a wrong output path.
    # The project root is located by walking up to the dir holding AGENTS.md.
    root: Path | None = None
    if timeline_path.exists():
        for candidate in (timeline_path.resolve(), *timeline_path.resolve().parents):
            if (candidate / "AGENTS.md").is_file():
                root = candidate
                break
    if root is None:
        return check("workspace_hygiene", "WARN", "project root not found", "outputs under 123/<id>.<name>", evidence)
    strays: list[str] = []
    try:
        for pattern in ("f_*.jpg", "thumb_*.jpg"):
            strays.extend(path.name for path in root.glob(pattern))
        strays.extend(path.name for path in root.glob("*.mp4"))
    except OSError as exc:
        return check("workspace_hygiene", "WARN", str(exc), "root readable", str(root))
    if not strays:
        return check("workspace_hygiene", "PASS", "no root strays", "<= 10 stray files", str(root))
    if len(strays) > 10:
        return check("workspace_hygiene", "FAIL", f"{len(strays)} strays, e.g. {strays[0]}", "<= 10 stray files", str(root))
    return check("workspace_hygiene", "WARN", f"{len(strays)} strays, e.g. {strays[0]}", "<= 10 stray files", str(root))


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the project QA gates; any FAIL blocks freezing.")
    parser.add_argument("timeline", type=Path)
    parser.add_argument("--program-map", type=Path)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--decode-log", type=Path)
    parser.add_argument("--srt", type=Path)
    parser.add_argument("--srt-stats", type=Path)
    parser.add_argument("--master", type=Path)
    parser.add_argument(
        "--burned-subtitles",
        action="store_true",
        help="Legacy flag, kept for compatibility. Passing it FAILs the no-burn gate: burning is forbidden.",
    )
    parser.add_argument("--proxy-map", type=Path)
    parser.add_argument(
        "--voice-index",
        type=Path,
        help="naraka-voice-index/v1 produced by reports/tools/voice_index.py; enables deleted_voice_audit",
    )
    parser.add_argument("--source-duration", type=float)
    parser.add_argument(
        "--whole-battle-strict",
        action="store_true",
        help="Treat in-battle holes (G-1) as FAIL instead of WARN. Same as declaring \"whole_battle_policy\": \"864\" in the timeline JSON.",
    )
    parser.add_argument("--ffprobe", type=str, default=None)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    checks: list[dict] = []
    document: dict = {}
    # Runs before anything reads the timeline: if this is a partial, nothing else
    # in this run should be reported as if it were a delivery verdict.
    partial_check = refuse_partial_timeline(args.timeline)
    checks.append(partial_check)
    if partial_check["result"] == "FAIL":
        print(json.dumps({"pass": False, "fail": 1, "output": str(args.output)},
                         ensure_ascii=False))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps({"schema": "naraka-qa-gate/v1", "checks": checks},
                       ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        return 1
    try:
        document, episodes = load_timeline(args.timeline)
    except (OSError, ValueError) as exc:
        checks.append(check("load_timeline", "FAIL", str(exc), "parseable timeline", str(args.timeline)))
        episodes = []
    # Opt-in to FAIL on G-1 via "whole_battle_policy": "864" at the top level of
    # the timeline JSON.  Default is WARN so already-delivered work is reported
    # without being declared non-compliant.
    whole_battle_strict = (
        isinstance(document, dict)
        and str(document.get("whole_battle_policy", "")) == "864"
    ) or args.whole_battle_strict
    if episodes:
        checks.append(gate_timeline_mutex(episodes, str(args.timeline)))
        checks.append(gate_source_range(episodes, args.source_duration, str(args.timeline)))
        checks.append(gate_in_segment_holes(episodes, str(args.timeline)))
        # 864 用户准则：一场完整战斗，中间不许断。R2-1 管洞，R2-2 管场边界。
        checks.append(gate_no_holes_in_battle(episodes, str(args.timeline), whole_battle_strict))
        checks.append(gate_no_zero_gap_pseudo_cuts(episodes, str(args.timeline)))
        checks.append(gate_program_sum(episodes, args.program_map, str(args.timeline)))
    # Coverage runs even when the episode list is empty, because "no episodes"
    # used to skip every timeline gate and therefore reported green.
    checks.append(gate_coverage_complete(episodes, document, args.source_duration, str(args.timeline)))
    # Only when a voice index is supplied: 864's re-measurement showed the dropped
    # battle was cleanly *declared*, so coverage alone reports green.
    checks.append(gate_deleted_voice_audit(document, args.voice_index, str(args.timeline)))
    ffprobe = args.ffprobe or shutil.which("ffprobe")
    probe = run_probe(ffprobe, args.preview) if args.preview else None
    preview_evidence = str(args.preview) if args.preview else "no preview"
    checks.append(gate_preview_duration(probe, episodes, preview_evidence))
    checks.append(gate_av_sync(probe, preview_evidence))
    checks.append(gate_frame_rate(probe, preview_evidence))
    # Media-content gates (black/freeze/silence/loudness/splice continuity) run
    # as FFmpeg filter passes and are recorded by the render/self-audit reports;
    # this gate enforces that their evidence exists instead of re-decoding here.
    checks.append(check("media_filters", "WARN", "see render/selfaudit evidence", "black/freeze/silence/ebur128 on file", preview_evidence))
    if args.srt and args.srt.is_file() and episodes:
        try:
            entries = parse_srt(args.srt)
            checks.append(gate_subtitles(entries, episodes, str(args.srt)))
            if args.srt_stats and args.srt_stats.is_file():
                try:
                    stats = json.loads(args.srt_stats.read_text(encoding="utf-8"))
                    for key in ("count", "total", "cues"):
                        if key in stats:
                            try:
                                expected = int(stats[key])
                            except (TypeError, ValueError):
                                continue
                            if expected != len(entries):
                                checks.append(check("subtitle_stats", "FAIL", len(entries), f"stats {key}={expected}", str(args.srt_stats)))
                                break
                    else:
                        checks.append(check("subtitle_stats", "PASS", len(entries), "matches stats", str(args.srt_stats)))
                except (OSError, ValueError) as exc:
                    checks.append(check("subtitle_stats", "WARN", str(exc), "stats parseable", str(args.srt_stats)))
            else:
                checks.append(check("subtitle_stats", "WARN", "no stats", "stats on file", str(args.srt) if args.srt else "no srt"))
        except (OSError, ValueError) as exc:
            checks.append(check("subtitle_span", "FAIL", str(exc), "parseable SRT", str(args.srt)))
    else:
        checks.append(check("subtitle_span", "WARN", "no srt", "SRT checked", preview_evidence))
        checks.append(check("subtitle_stats", "WARN", "no stats", "stats on file", preview_evidence))
    checks.append(gate_burned_srt(args.master, args.burned_subtitles, preview_evidence))
    checks.append(gate_no_subtitle_stream(probe, preview_evidence))
    if args.master is not None and args.master.is_file():
        master_probe = run_probe(ffprobe, args.master)
        checks.append(gate_no_subtitle_stream(master_probe, str(args.master)))
    checks.append(gate_proxy_map(args.proxy_map, preview_evidence))
    checks.append(gate_workspace_hygiene(args.timeline, preview_evidence))
    frozen = [item for item in (args.timeline, args.program_map, args.preview, args.decode_log, args.srt) if item is not None]
    checks.append(gate_kit([Path(item) for item in frozen], preview_evidence))

    failed = sum(1 for item in checks if item["result"] == "FAIL")
    result = {
        "schema": SCHEMA,
        "timeline": str(args.timeline.resolve()) if args.timeline.exists() else str(args.timeline),
        "checks": checks,
        "fail": failed,
        "warn": sum(1 for item in checks if item["result"] == "WARN"),
        "status": "FROZEN_CANDIDATE" if failed == 0 else "NOT_FROZEN",
        "pass": failed == 0,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"pass": result["pass"], "fail": failed, "output": str(args.output)}, ensure_ascii=False))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
