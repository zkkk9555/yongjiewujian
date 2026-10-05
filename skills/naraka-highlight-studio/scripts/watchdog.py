"""Watchdog: notice a lane that will not come back, and do something about it.

Why this exists
---------------
Task 861 dispatched 29 lanes.  Three were swallowed by a service restart and
**nobody noticed, nobody re-dispatched, nobody degraded** -- 7.5 hours of idle
waiting.  The dispatch ledger could not even answer "is lane 12 wedged?": its
header has five columns (route, name, status, owner, summary) and 33 of its cells
hold the literal string "T0".  Per-lane dispatch and recycle times were never
recorded, so no threshold could recover them.  `orchestrator_state.py` is what
makes the question answerable; this module is what acts on the answer.

The threshold
-------------
    clamp(3 x p50(this wave's recycle latency), 60, 240) minutes

* **p50 of observed latencies**, not a configured constant.  A fixed timeout is
  wrong on both ends: too tight kills lanes that are merely slow, too loose
  reproduces the 7.5 h wait.
* **3x p50** tolerates a lane that is 3x slower than typical without being dead.
* **60/240 clamp** keeps the rule sane on a project whose p50 is either a couple
  of minutes or most of a day.

Two rules that are not tuning
-----------------------------
* **Never fire below 50% recycled.**  Early in a wave the p50 is computed from a
  handful of fast lanes and every slow lane looks like a corpse.  This floor is
  what makes the statistic trustworthy at all.
* **A stuck lane is only fired once it is genuinely overdue**, i.e. its wait
  exceeds the threshold -- not merely because it has not returned.

Degradation is explicit
-----------------------
When a lane hits `MAX_ATTEMPT` it is moved to `withheld`, never silently
dropped.  A lane that quietly disappears is the failure this whole project keeps
paying for: on 861 three lanes vanished and the ledger still read as if all 29
were accounted for.

This module is a pure reader.  It loads the state, decides, writes back.  It
never talks to a lane, so its own crash cannot disturb work in flight.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from orchestrator_state import (  # noqa: E402
    MAX_ATTEMPT,
    load as _load_state,
    save as _save_state,
    _now,
)

MIN_REPORT_MINUTES = 60.0
MAX_REPORT_MINUTES = 240.0
MULTIPLIER = 3.0
MIN_RECYCLE_FRACTION = 0.5


def load_state(path: Path) -> dict[str, Any]:
    return _load_state(path)


def _live_lanes(doc: dict[str, Any]) -> list[dict]:
    return [r for r in doc.get("lanes") or [] if isinstance(r, dict)]


def observed_latencies(doc: dict[str, Any], now: float) -> list[float]:
    """Minutes each recycled lane took, dispatched -> recycled.

    Negative spans are dropped rather than clamped to zero.  A recycled lane
    cannot have gone back in time, so a negative span means the record is
    inconsistent -- usually an injected clock that set recycled_at *before*
    dispatched_at -- and silently coercing that to 0 would hand the p50 a
    fabricated population of instant lanes.
    """
    out: list[float] = []
    for row in _live_lanes(doc):
        sent, back = row.get("dispatched_at"), row.get("recycled_at")
        if not (isinstance(sent, (int, float)) and isinstance(back, (int, float))):
            continue
        span = back - sent
        if span >= 0:
            out.append(span / 60.0)
    return out


def threshold_minutes(doc: dict[str, Any], now: float) -> float | None:
    """None means 'not enough evidence to fire at all'."""
    lanes = _live_lanes(doc)
    total = doc.get("lanes_total") or len(lanes)
    recycled = sum(1 for r in lanes if r.get("status") == "recycled")
    if total <= 0 or recycled < total * MIN_RECYCLE_FRACTION:
        return None
    lat = observed_latencies(doc, now)
    if not lat:
        return None
    raw = MULTIPLIER * statistics.median(lat)
    return max(MIN_REPORT_MINUTES, min(MAX_REPORT_MINUTES, raw))


def evaluate(doc: dict[str, Any], now: float | None = None) -> dict[str, Any]:
    """Decide which lanes to fire and which to withhold.  Writes nothing."""
    now = _now() if now is None else now
    limit = threshold_minutes(doc, now)
    fire: list[dict[str, Any]] = []
    withhold: list[int] = []

    if limit is None:
        return {"threshold_minutes": None, "p50_minutes": None, "fire": [],
                "withhold": [], "silent_reason": "below-50-floor"}

    lat = observed_latencies(doc, now)
    p50 = statistics.median(lat) if lat else None

    for row in _live_lanes(doc):
        if row.get("status") != "in-flight":
            continue
        sent = row.get("dispatched_at")
        if not isinstance(sent, (int, float)):
            continue
        waited_min = (now - sent) / 60.0
        if waited_min <= limit:
            continue  # slow, not dead
        if row.get("attempt", 0) >= MAX_ATTEMPT:
            withhold.append(row["id"])
            continue
        fire.append({
            "lane": row["id"],
            "waited_minutes": round(waited_min, 1),
            "threshold_minutes": round(limit, 1),
            "reason": "stuck",
        })

    return {"threshold_minutes": round(limit, 1),
            "p50_minutes": None if p50 is None else round(p50, 1),
            "fire": fire, "withhold": withhold, "silent_reason": None}


def apply(path: Path, now: float | None = None) -> dict[str, Any]:
    """Evaluate, then write back: re-dispatch or withhold, and log each action."""
    now = _now() if now is None else now
    doc = load_state(path)
    res = evaluate(doc, now=now)
    if res["threshold_minutes"] is None:
        print(json.dumps({"action": "silent", "why": res["silent_reason"],
                          "state": str(path)}, ensure_ascii=False))
        return res

    doc.setdefault("watchdog", {})["last_check_at"] = now
    doc["watchdog"]["threshold_minutes"] = res["threshold_minutes"]
    doc["watchdog"]["p50_minutes"] = res["p50_minutes"]

    fired = []
    for item in res["fire"]:
        row = next(r for r in doc["lanes"] if r["id"] == item["lane"])
        row["attempt"] += 1
        row["dispatched_at"] = now
        row["recycled_at"] = None
        row["status"] = "in-flight"
        row["last_error"] = "re-dispatched by watchdog after %.0f min (threshold %.0f min)" % (
            item["waited_minutes"], item["threshold_minutes"])
        fired.append(item["lane"])
        doc.setdefault("history", []).append({
            "at": now,
            "entry": "watchdog re-dispatched lane %d (attempt %d) after %.0f min"
                     % (row["id"], row["attempt"], item["waited_minutes"]),
        })

    withheld = []
    for lane_id in res["withhold"]:
        row = next(r for r in doc["lanes"] if r["id"] == lane_id)
        row["status"] = "withheld"
        row["last_error"] = (
            "WITHHELD after %d attempts, still no report %.0f min past a %.0f min "
            "threshold; no route swap available -- a human must decide whether to "
            "re-dispatch by hand or accept the coverage gap"
            % (MAX_ATTEMPT, res["threshold_minutes"] and (now - row.get("dispatched_at", now)) / 60.0 or 0.0,
               res["threshold_minutes"]))
        row["withheld_at"] = now
        withheld.append(lane_id)
        doc.setdefault("history", []).append({
            "at": now,
            "entry": "watchdog WITHHELD lane %d after %d attempts; needs a human decision"
                     % (lane_id, MAX_ATTEMPT),
        })

    if fired:
        doc["lanes_fired"] = sum(1 for r in doc["lanes"] if r.get("last_error"))
    if withheld:
        doc["lanes_withheld"] = sum(1 for r in doc["lanes"] if r.get("status") == "withheld")
    doc["lanes_dispatched"] = sum(1 for r in doc["lanes"] if r.get("dispatched_at"))
    doc["lanes_recycled"] = sum(1 for r in doc["lanes"] if r.get("status") == "recycled")
    if withheld:
        doc["next_action"] = "resolve %d withheld lane(s) before merging" % len(withheld)
    _save_state(path, doc)
    del doc["history"][:-200]

    print(json.dumps({"action": "applied",
                      "threshold_minutes": res["threshold_minutes"],
                      "p50_minutes": res["p50_minutes"],
                      "re_dispatched": fired, "withheld": withheld,
                      "state": str(path)}, ensure_ascii=False))
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description="Watchdog: fire or withhold stuck lanes.")
    ap.add_argument("state", type=Path)
    ap.add_argument("--now", type=float, default=None,
                    help="inject the clock (epoch seconds) instead of reading it")
    ap.add_argument("--dry-run", action="store_true", help="evaluate without writing")
    args = ap.parse_args()

    now = args.now if args.now is not None else _now()
    if args.dry_run:
        res = evaluate(load_state(args.state), now=now)
        print(json.dumps(res, ensure_ascii=False, indent=1))
        return 0
    apply(args.state, now=now)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
