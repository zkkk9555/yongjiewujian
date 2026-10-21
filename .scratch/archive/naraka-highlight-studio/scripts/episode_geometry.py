"""Episode geometry: the single source of truth for program duration.

Zero third-party dependencies (standard library only), so both the QA gate and
the timeline validator can import it without pulling anything in.

WHY THIS MODULE EXISTS
----------------------
The timeline schema has always carried ``excluded_inside`` -- the holes punched
inside one combat episode to drop an in-combat pause, a loot panel, a menu.
The spec (``references/complete-combat-roughcut.md`` section 3.3) makes leaving
such a pause un-excavated a delivery-blocking violation.

But no project code ever read the field.  The program duration was computed six
separate times as ``sum(source_end - source_start)``, always ignoring the holes.
The result on task 861: a *correct* 1090.5 s render was reported FAIL because
the gate expected 1119.4 s -- exactly the 28.9 s of declared holes.

So the formula lives here, once:

    program_seconds = sum over episodes of
        (source_end - source_start) - sum over holes of (hole.end - hole.start)

Holes are expressed in SOURCE time coordinates, the same space as
``source_start`` / ``source_end``.  An episode with holes expands into several
contiguous cut segments; the renderer concatenates those in order.

Cross-language note: ``scripts/read_episode_bounds.ps1`` implements this same
rule independently, because the 4K master path is deliberately Python-free.
``scripts/test_insegment_holes.sh`` runs both implementations against one
fixture and asserts they agree, so the two copies cannot drift apart silently.
"""

from __future__ import annotations

from typing import Any, Iterable, Sequence

# An episode shorter than this after hole removal is treated as "the hole ate
# the whole episode" -- a malformed timeline, not a legitimate cut.
MIN_SEGMENT_SECONDS = 0.0

# Rounding used when reporting totals so float noise does not show up as a
# spurious gate failure.  Matches the 0.01 s tolerance the gates already use.
ROUND_DIGITS = 3


def episode_bounds(episode: dict[str, Any]) -> tuple[float, float]:
    """Return ``(source_start, source_end)`` for one episode."""
    start = float(episode.get("source_start", episode.get("start", 0.0)))
    end = float(episode.get("source_end", episode.get("end", start)))
    return start, end


def episode_holes(episode: dict[str, Any]) -> list[tuple[float, float]]:
    """Return the episode's holes as sorted ``(start, end)`` pairs.

    Accepts the schema shape ``[{"start": x, "end": y}, ...]``.  Malformed
    entries are skipped here and reported by :func:`hole_problems`, so a bad
    hole cannot silently corrupt the duration arithmetic.
    """
    raw = episode.get("excluded_inside") or []
    if not isinstance(raw, (list, tuple)):
        return []
    holes: list[tuple[float, float]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        try:
            start = float(item["start"])
            end = float(item["end"])
        except (KeyError, TypeError, ValueError):
            continue
        holes.append((start, end))
    return sorted(holes)


def hole_problems(episode: dict[str, Any]) -> list[str]:
    """Return human-readable problems with one episode's holes.

    An empty list means the holes are usable.  Checked:

    * ``start < end`` (a zero- or negative-length hole is nonsense)
    * the hole lies inside ``[source_start, source_end]``
    * the holes do not consume the entire episode

    Overlapping and adjacent holes are deliberately **not** a problem: the union
    is unambiguous, so they are merged (see :func:`episode_segments`) rather than
    rejected.  Rejecting them here used to make the QA gate FAIL a timeline that
    ``read_episode_bounds.ps1`` merged and rendered happily -- a false alarm in
    the same class as the original bug.  scripts/test_insegment_holes.sh locks
    the two implementations together on exactly this case.
    """
    episode_id = str(episode.get("id", "?"))
    start, end = episode_bounds(episode)
    problems: list[str] = []

    for hole_start, hole_end in episode_holes(episode):
        label = f"{episode_id} hole [{hole_start}, {hole_end}]"
        if hole_end <= hole_start:
            problems.append(f"{label}: end <= start (non-positive length)")
            continue
        if hole_start < start or hole_end > end:
            problems.append(
                f"{label}: outside episode bounds [{start}, {end}]"
            )

    merged: list[list[float]] = []
    for hole_start, hole_end in episode_holes(episode):
        if merged and hole_start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], hole_end)
        else:
            merged.append([hole_start, hole_end])

    if merged:
        covered = sum(h_end - h_start for h_start, h_end in merged)
        if covered >= (end - start) - MIN_SEGMENT_SECONDS:
            problems.append(
                f"{episode_id}: holes cover the whole episode "
                f"[{start}, {end}] -- nothing would be left to render"
            )
    return problems


def episode_segments(episode: dict[str, Any]) -> list[tuple[float, float]]:
    """Expand one episode into the cut segments that actually get rendered.

    With no holes this is ``[(source_start, source_end)]`` -- byte-for-byte the
    old behaviour, so timelines that never used ``excluded_inside`` are
    completely unaffected.
    """
    start, end = episode_bounds(episode)
    holes = episode_holes(episode)
    if not holes:
        return [(start, end)]

    merged: list[list[float]] = []
    for hole_start, hole_end in sorted(holes):
        if hole_end <= hole_start:
            continue
        if merged and hole_start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], hole_end)
        else:
            merged.append([hole_start, hole_end])

    segments: list[tuple[float, float]] = []
    cursor = start
    for hole_start, hole_end in merged:
        if hole_start > cursor:
            segments.append((cursor, hole_start))
        cursor = max(cursor, hole_end)
    if cursor < end:
        segments.append((cursor, end))
    return [(seg_start, seg_end) for seg_start, seg_end in segments
            if seg_end - seg_start > MIN_SEGMENT_SECONDS]


def episode_program_seconds(episode: dict[str, Any]) -> float:
    """Effective rendered length of one episode, holes deducted."""
    return sum(seg_end - seg_start for seg_start, seg_end in episode_segments(episode))


def raw_span_seconds(episode: dict[str, Any]) -> float:
    """``source_end - source_start`` -- what the buggy code used to report."""
    start, end = episode_bounds(episode)
    return end - start


def timeline_program_seconds(episodes: Iterable[dict[str, Any]]) -> float:
    """Total program length, holes deducted.  The number every gate must use."""
    return round(
        sum(episode_program_seconds(ep) for ep in episodes), ROUND_DIGITS
    )


def timeline_raw_span_seconds(episodes: Iterable[dict[str, Any]]) -> float:
    """Total ``source_end - source_start``, holes NOT deducted.

    Kept only for reporting: showing both numbers makes an unexplained
    difference between the timeline's raw span and the rendered program
    self-explanatory instead of looking like a bug.
    """
    return round(sum(raw_span_seconds(ep) for ep in episodes), ROUND_DIGITS)


def timeline_cut_segments(episodes: Sequence[dict[str, Any]]) -> list[tuple[float, float]]:
    """Every cut segment across the whole timeline, in program order."""
    segments: list[tuple[float, float]] = []
    for episode in episodes:
        segments.extend(episode_segments(episode))
    return segments


def timeline_hole_problems(episodes: Iterable[dict[str, Any]]) -> list[str]:
    """Problems with the holes of every episode, in timeline order."""
    problems: list[str] = []
    for episode in episodes:
        problems.extend(hole_problems(episode))
    return problems


def expand_events_for_holes(events: Sequence[dict[str, Any]]) -> list[dict[str, Any]]:
    """Split event dicts around any ``excluded_inside`` holes, in place order.

    The event schema (``event_candidates.json``) is a different shape from
    ``combat_episodes`` but can carry the same field, and the downstream
    exporters (OTIO / Premiere XML / beat map) add clips one per event.  An event
    with an un-honoured hole would put the pause straight into the NLE.

    An event with no holes is passed through **unchanged**, so existing inputs
    (the only event file on disk has zero holes) keep byte-identical behaviour.
    Only when holes are present are program times recomputed, because the
    program timeline compresses across a hole.
    """
    expanded: list[dict[str, Any]] = []
    for event in events:
        if not isinstance(event, dict) or not event.get("excluded_inside"):
            expanded.append(event)
            continue
        for index, (seg_start, seg_end) in enumerate(episode_segments(event)):
            piece = dict(event)
            piece["source_start"] = seg_start
            piece["source_end"] = seg_end
            piece["excluded_inside"] = []
            # A hole shortens the program, so every program timestamp after it
            # shifts left.  Recompute from the event's own program_start.
            program_start = float(event.get("program_start", 0.0))
            piece["program_start"] = program_start
            piece["program_end"] = program_start + (seg_end - seg_start)
            for key in ("impact_program",):
                if key in event and event[key] is not None:
                    # Keep the marker on the segment that actually contains it;
                    # drop it if the hole swallowed it.
                    impact = float(event[key])
                    if seg_start <= impact < seg_end:
                        piece[key] = program_start + (impact - seg_start)
                    else:
                        piece.pop(key, None)
            piece["_hole_split_part"] = index
            expanded.append(piece)
    return expanded
