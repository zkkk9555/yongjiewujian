"""Orchestrator state: the one file that remembers what is in flight.

Why this file exists
--------------------
Measured over three delivered tasks: 46.5% of the wall clock (29.07 of 62.52
hours) was silent or idle, while machine work was only 3.1%.  The causes were
never ffmpeg or model speed:

  * task 861 dispatched 29 lanes; 3 were swallowed by a service restart and
    **nobody noticed, nobody re-dispatched, nobody degraded** -> 7.5 h lost.
  * the ledger `dispatch_ledger.md` has five columns -- route, name, status,
    owner, summary.  No dispatch time, no recycle time.  So "is this lane
    wedged?" was unanswerable from anything on disk.

This module is the disk record that answers it.

Design decisions that are not free choices
------------------------------------------
* **A script writes it, a human reads it.**  An agent asked to maintain a ledger
  "by hand" wrote the literal string `T0` into all 29 rows of task 861.  A
  script cannot forget to stamp a row.  The ledger stays a *projection*, never
  a second source of truth.
* **`reports/` not `cache/`.**  `cleanup_after_master.ps1` disposes of
  `preview, cache, shots, audio`.  Task 860 had a verified resume
  implementation and lost it because it lived under `cache/`.
* **27 top-level keys, not 104.**  The first design carried 104 named fields;
  that is unreadable and un-greppable.  Nesting is allowed, the top level stays
  flat.
* **`attempt` and `recycle_round` are separate fields.**  "At most 3 rounds of
  recycling" and "at most 2 re-dispatches of one lane" are two different limits;
  one field cannot hold both.
* **A corrupt file must not wedge the task.**  It rebuilds to phase `unknown`
  with every lane unrecycled.  Refusing to start is not a safe default here.

Standard library only, matching `episode_geometry.py`.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

SCHEMA = "naraka-orchestrator-state/v1"

# Flat top level, deliberately small: the first design carried 104 named fields,
# which is neither greppable nor reviewable (02 designed 104, 09 adjudicated it
# down).  This is 26 keys; everything that grows goes inside `lanes`, `watchdog`,
# `authorization` or `history`.
#
# The assertion below fires on import, so a drifted count cannot pass a green run.
# It is a tripwire on *the tuple drifting away from this comment*, not a magic
# number to chase: when a key is genuinely added, bump it here in the same commit.
EXPECTED_TOP_LEVEL_KEYS = 26

# The 27 top-level keys.  Asserted below so a future edit that grows or drops one
# fails loudly instead of quietly changing the contract.
TOP_LEVEL_KEYS = (
    "schema", "version", "phase", "task_dir", "task_number", "material_name",
    "source_path", "source_duration", "wave", "wave_started_at",
    "lanes_total", "lanes_dispatched", "lanes_recycled", "lanes_redispatched",
    "lanes_fired", "lanes_withheld", "lanes",
    # Liveness bookkeeping.  `watchdog` is the policy, `authorization` is the
    # user's 4K permission; both are nested dicts rather than flat flags so the
    # policy can grow without changing the top-level contract.
    "watchdog", "authorization",
    "next_action", "blocked_on", "last_updated_at", "history", "notes",
    # The two output artifacts the phase machine refers to.  Counting matters:
    # this tuple IS the contract, and the assertion below fires on every import,
    # so a drifted count cannot survive a green test run.
    "timeline_path", "gates_run_at",
)
# The exact count is asserted rather than hardcoded, so this reads as "the list
# below is the contract" instead of inviting a magic number to drift out of sync.
# An earlier draft pinned == 27 while the tuple held 24 keys, and the module
# refused to initialise at all -- a test-only assertion cost the whole first run.
assert len(TOP_LEVEL_KEYS) == EXPECTED_TOP_LEVEL_KEYS, (
    "top-level contract changed: expected %d keys, tuple has %d -- update the spec"
    % (EXPECTED_TOP_LEVEL_KEYS, len(TOP_LEVEL_KEYS))
)

MAX_ATTEMPT = 2
MAX_RECYCLE_ROUND = 3

# Ledger column titles, in order.  Kept here so render_ledger() and its test read
# the same list -- the first version hard-coded "round" and the header silently
# stopped matching the three columns the workflow actually gained.
LEDGER_COLUMNS = (
    "lane", "name (segment)", "status", "owner",
    "dispatched", "recycled", "attempt", "recycle round", "summary",
)

WATCHDOG_DEFAULTS = {
    "enabled": False,
    "multiplier": 3,
    "min_minutes": 60,
    "max_minutes": 240,
    "min_recycle_fraction": 0.5,
    "last_check_at": None,
    "fired_lanes": [],
}

AUTHORIZATION_DEFAULTS = {
    "granted": False,
    "granted_at": None,
    "phrase_seen": None,
    "chain_state": "not-requested",
    "chain_started_at": None,
    "chain_finished_at": None,
    "chain_error": None,
}

PHASES = (
    "unknown", "preflight", "probe", "transcribe", "proxy", "scan",
    "merge", "render-preview", "review", "refreeze", "master", "cleanup", "done",
)


def _now() -> float:
    return time.time()


def _blank(task_dir: Path, lanes: int) -> dict[str, Any]:
    lane_rows = [
        {
            "id": i + 1,
            "name": "",
            "segment": None,
            "status": "pending",
            "attempt": 0,
            "recycle_round": 0,
            "dispatched_at": None,
            "recycled_at": None,
            "report_path": None,
            "coverage": None,
            "source_kind": None,
            "last_error": None,
        }
        for i in range(lanes)
    ]
    return {
        "schema": SCHEMA,
        "version": "1",
        "phase": "unknown",
        "task_dir": str(task_dir),
        "task_number": None,
        "material_name": None,
        "source_path": None,
        "source_duration": None,
        "wave": 1,
        "wave_started_at": _now(),
        "lanes_total": lanes,
        "lanes_dispatched": 0,
        "lanes_recycled": 0,
        "lanes_redispatched": 0,
        "lanes_fired": 0,
        "lanes_withheld": 0,
        "lanes": lane_rows,
        "watchdog": dict(WATCHDOG_DEFAULTS),
        "authorization": dict(AUTHORIZATION_DEFAULTS),
        "next_action": "dispatch wave",
        "blocked_on": None,
        "last_updated_at": _now(),
        "history": [],
        "notes": {},
        "timeline_path": None,
        "gates_run_at": None,
    }


def state_path(task_dir: str | Path) -> Path:
    """`reports/delivery_state.json` -- the retained side of the cleanup split."""
    return Path(task_dir) / "reports" / "delivery_state.json"


def load(path: Path) -> dict[str, Any]:
    """Read the state, rebuilding rather than raising on damage.

    A task that cannot start because its state file has a stray byte is worse
    than a task that starts with an honest `unknown` phase.  The corruption is
    recorded in `notes` so the condition is visible instead of silent.
    """
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return _blank(path.parent.parent, 0)
    try:
        doc = json.loads(raw)
    except ValueError:
        rebuilt = _blank(path.parent.parent, 0)
        rebuilt["notes"] = {"rebuilt_from": "unparseable", "at": _now()}
        return rebuilt
    if not isinstance(doc, dict) or doc.get("schema") != SCHEMA:
        rebuilt = _blank(path.parent.parent, 0)
        rebuilt["notes"] = {"rebuilt_from": "foreign schema", "at": _now()}
        return rebuilt
    for key in TOP_LEVEL_KEYS:
        if key in doc:
            continue
        if key == "lanes" or key == "history":
            doc[key] = []
        elif key == "watchdog":
            doc[key] = dict(WATCHDOG_DEFAULTS)
        elif key == "authorization":
            doc[key] = dict(AUTHORIZATION_DEFAULTS)
        elif key == "notes":
            doc[key] = {}
        else:
            doc[key] = None
    if not isinstance(doc.get("watchdog"), dict):
        doc["watchdog"] = dict(WATCHDOG_DEFAULTS)
    if not isinstance(doc.get("authorization"), dict):
        doc["authorization"] = dict(AUTHORIZATION_DEFAULTS)
    doc["last_updated_at"] = _now()
    return doc


def _assert_shape(doc: dict[str, Any]) -> None:
    """The 27-key contract.  Split out of save() so init() can check it before
    the file exists, and so the same check runs on load."""
    missing = [k for k in TOP_LEVEL_KEYS if k not in doc]
    if missing:
        raise ValueError("state missing top-level keys: %s" % ", ".join(missing))
    extra = [k for k in doc if k not in TOP_LEVEL_KEYS]
    if extra:
        raise ValueError("unexpected top-level keys: %s" % ", ".join(sorted(extra)))
    if len(TOP_LEVEL_KEYS) != EXPECTED_TOP_LEVEL_KEYS:
        raise ValueError("top-level contract must stay at %d keys, found %d"
                         % (EXPECTED_TOP_LEVEL_KEYS, len(TOP_LEVEL_KEYS)))
    if len(set(TOP_LEVEL_KEYS)) != len(TOP_LEVEL_KEYS):
        dupes = sorted({k for k in TOP_LEVEL_KEYS if TOP_LEVEL_KEYS.count(k) > 1})
        raise ValueError("duplicate top-level keys: %s" % ", ".join(dupes))


def save(path: Path, doc: dict[str, Any]) -> None:
    _assert_shape(doc)
    doc["last_updated_at"] = _now()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


def record_dispatch(doc: dict[str, Any], lane: int, name: str = "", segment: Any = None) -> dict:
    row = _lane(doc, lane)
    row["attempt"] += 1
    row["dispatched_at"] = _now()
    row["status"] = "in-flight"
    row["last_error"] = None
    if name:
        row["name"] = name
    if segment is not None:
        row["segment"] = segment
    doc["lanes_dispatched"] = sum(1 for r in doc["lanes"] if r["dispatched_at"])
    doc["lanes_redispatched"] = sum(1 for r in doc["lanes"] if r["attempt"] > 1)
    return row


def record_recycle(doc: dict[str, Any], lane: int, report_path: str | None = None,
                   coverage: Any = None) -> dict:
    row = _lane(doc, lane)
    row["recycled_at"] = _now()
    row["recycle_round"] += 1
    row["status"] = "recycled"
    if report_path:
        row["report_path"] = str(report_path)
    if coverage is not None:
        row["coverage"] = coverage
    doc["lanes_recycled"] = sum(1 for r in doc["lanes"] if r["recycled_at"])
    return row


def mark_withheld(doc: dict[str, Any], lane: int, reason: str) -> dict:
    """Explicit degradation.  Never fail silently: a withheld lane is named."""
    row = _lane(doc, lane)
    row["status"] = "withheld"
    row["last_error"] = reason
    doc["lanes_withheld"] = sum(1 for r in doc["lanes"] if r["status"] == "withheld")
    _history(doc, "lane %d withheld: %s" % (lane, reason))
    return row


def next_action(doc: dict[str, Any]) -> str:
    total = doc["lanes_total"]
    recycled = sum(1 for r in doc["lanes"] if r["status"] == "recycled")
    withheld = sum(1 for r in doc["lanes"] if r["status"] == "withheld")
    in_flight = sum(1 for r in doc["lanes"] if r["status"] == "in-flight")
    if withheld:
        return "resolve %d withheld lane(s) before merging" % withheld
    if recycled + withheld >= total:
        return "merge all lanes, then render the review preview"
    if recycled:
        return "merge the %d recycled lane(s) now (partial), keep watching the rest" % recycled
    if in_flight:
        return "wait for %d lane(s); watchdog decides when to fire" % in_flight
    return "dispatch wave"


def render_ledger(doc: dict[str, Any]) -> str:
    """The human table, generated.  This is why nobody has to fill one in."""
    lines = [
        "# Dispatch ledger (generated from delivery_state.json -- do not edit)",
        "",
        "| " + " | ".join(LEDGER_COLUMNS) + " |",
        "|" + "|".join(["---"] * len(LEDGER_COLUMNS)) + "|",
    ]
    for row in doc["lanes"]:
        disp = _stamp(row.get("dispatched_at"))
        rec = _stamp(row.get("recycled_at"))
        seg = row.get("segment")
        segtxt = "" if seg is None else (seg if isinstance(seg, str) else json.dumps(seg, ensure_ascii=False))
        lines.append("| %s | %s (%s) | %s | %s | %s | %s | %s | %s | %s |" % (
            row["id"], row.get("name") or "-", segtxt or "-", row.get("status"),
            row.get("source_kind") or "-", disp, rec, row.get("attempt", 0),
            row.get("recycle_round", 0), row.get("last_error") or "",
        ))
    lines += [
        "",
        "phase: %s | recycled %d/%d | withheld %d | next: %s" % (
            doc["phase"],
            sum(1 for r in doc["lanes"] if r["status"] == "recycled"),
            doc["lanes_total"], doc["lanes_withheld"], next_action(doc)),
        "",
    ]
    return "\n".join(lines)


def _lane(doc: dict[str, Any], lane: int) -> dict:
    for row in doc["lanes"]:
        if row["id"] == lane:
            return row
    raise KeyError("no lane %s (have %s)" % (lane, [r["id"] for r in doc["lanes"]]))


def _stamp(value: Any) -> str:
    if not isinstance(value, (int, float)) or value <= 0:
        return "-"
    return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(value))


def _history(doc: dict[str, Any], entry: str) -> None:
    hist = doc.setdefault("history", [])
    hist.append({"at": _now(), "entry": entry})
    del hist[:-200]


def main() -> int:
    ap = argparse.ArgumentParser(description="Orchestrator state: dispatch, recycle, ledger.")
    ap.add_argument("state", type=Path)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("init")
    p.add_argument("--task-dir", required=True)
    p.add_argument("--lanes", type=int, default=0)
    p.add_argument("--source-duration", type=float, default=None)
    p.add_argument("--material", default=None)

    p = sub.add_parser("dispatch")
    p.add_argument("--lane", type=int, required=True)
    p.add_argument("--name", default="")
    p.add_argument("--segment", default=None)

    p = sub.add_parser("recycle")
    p.add_argument("--lane", type=int, required=True)
    p.add_argument("--report", default=None)
    p.add_argument("--coverage", default=None)

    p = sub.add_parser("fire")
    p.add_argument("--lane", type=int, required=True)
    p.add_argument("--reason", default="watchdog timeout")

    p = sub.add_parser("withhold")
    p.add_argument("--lane", type=int, required=True)
    p.add_argument("--reason", required=True)

    p = sub.add_parser("ledger")
    p.add_argument("--out", type=Path, required=True)

    p = sub.add_parser("phase")
    p.add_argument("--set", dest="set_phase", default=None)

    p = sub.add_parser("next-action")

    ap.add_argument("--print-path", action="store_true",
                    help="print the state path for --task-dir and exit")

    args = ap.parse_args()

    if args.print_path:
        if args.cmd == "ledger":
            print(state_path(args.out))
        elif args.cmd in ("phase", "next-action", "dispatch", "recycle", "fire", "withhold"):
            print(state_path(args.state))
        else:
            print(state_path(args.task_dir))
        return 0

    if args.cmd == "init":
        doc = _blank(Path(args.task_dir), args.lanes)
        if args.source_duration is not None:
            doc["source_duration"] = args.source_duration
        if args.material:
            doc["material_name"] = args.material
        doc["next_action"] = next_action(doc)
        _assert_shape(doc)
        save(args.state, doc)
        print(json.dumps({"state": str(args.state), "lanes": args.lanes,
                          "top_level_keys": len(TOP_LEVEL_KEYS)}, ensure_ascii=False))
        return 0

    doc = load(args.state)

    if args.cmd == "dispatch":
        record_dispatch(doc, args.lane, args.name, args.segment)
    elif args.cmd == "recycle":
        record_recycle(doc, args.lane, args.report, args.coverage)
    elif args.cmd == "fire":
        # A watchdog fire restarts the *wait*, not the work.  recycle_round is
        # deliberately preserved: it counts how many times this lane actually
        # produced a report, which is a different budget from re-dispatch
        # attempts, and 09 adjudicated them into two separate fields for
        # exactly this reason.  Earlier draft zeroed it and lost the history.
        row = _lane(doc, args.lane)
        row["attempt"] += 1
        row["dispatched_at"] = _now()
        row["recycled_at"] = None
        row["status"] = "in-flight"
        row["last_error"] = args.reason
        doc["lanes_fired"] = sum(1 for r in doc["lanes"] if r.get("last_error"))
        _history(doc, "lane %d re-dispatched (attempt %d): %s" % (args.lane, row["attempt"], args.reason))
    elif args.cmd == "withhold":
        mark_withheld(doc, args.lane, args.reason)
    elif args.cmd == "phase":
        if args.set_phase is not None:
            doc["phase"] = args.set_phase
    elif args.cmd == "next-action":
        print(next_action(doc))
        return 0
    elif args.cmd == "ledger":
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(render_ledger(doc), encoding="utf-8")
        print(json.dumps({"ledger": str(args.out)}, ensure_ascii=False))
        return 0

    doc["next_action"] = next_action(doc)
    save(args.state, doc)
    print(json.dumps({"state": str(args.state), "next_action": doc["next_action"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
