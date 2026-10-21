"""Run the 4K delivery chain once the user has granted it, and never before.

What this is not
----------------
It is NOT auto-render.  Measured 2026-10-06 on this box, 30 s of real source:
720p preview 25.70 s, 4K 108.65 s -- 4.2x, i.e. roughly 47 minutes for a
13-minute master.  The user rejected auto-render precisely because every re-render
after an edit would cost that: 「改一点就得重渲」.

So the grant stays manual, per batch, exactly as `docs\粗剪提示词.md:174` already
requires.  What was broken is only what happens *after* the grant.

The 6.57 hours
--------------
Measured: "frozen -> 4K actually rendering" idled 6.57 h across two tasks
(864 4.97 h, 863 1.60 h) with every gate green and the machine idle.  After the
grant, the whole chain takes 16-25 min (863 16.5, 864 24.5), so >=85% of that
wait was dead time with the grant already in hand -- no record of it, no
orchestration, no watchdog.

So this module does three things and refuses a fourth:

  1. records the grant on disk, WITH a timestamp (research 07 found the existing
     record carried no time, which made the wait unprovable either way);
  2. runs render -> verify -> cleanup unattended once granted;
  3. halts and names the failure if any step fails;

  and refuses: touching anything before the grant.  That is the red line, and it
  is why every command here is a no-op until `grant` has been called.

The authorisation phrase is the project's own, taken from
`docs\粗剪提示词.md:174` ("除非我已经明确说过「输出 4K 成片」这句话") and
`references/deliverables-and-qa.md:105`.  It is not invented here, and a
paraphrase does not count -- the point of a written grant rule is that it cannot
be satisfied by accident.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from orchestrator_state import (  # noqa: E402
    _blank,
    _now,
    load as load_state,
    save as save_state,
)

# The phrase the project's own rules name as the authorisation.
GRANT_PHRASE = "输出 4K 成片"

# AGENTS.md §7.1: the 4K master lives in exactly one place.
MASTER_DIR = r"E:\Cujian导出"

# §2.8 / §7.1 order.  verify before cleanup is not cosmetic: cleanup_after_master
# is the step that deletes preview/, cache/, shots/ and audio/, so running it
# before verification would delete the evidence that verification needed.
STEPS = ("render", "verify", "cleanup")


def _auth(doc: dict[str, Any]) -> dict[str, Any]:
    a = doc.get("authorization")
    if not isinstance(a, dict):
        a = {}
        doc["authorization"] = a
    a.setdefault("granted", False)
    a.setdefault("granted_at", None)
    a.setdefault("phrase_seen", None)
    a.setdefault("chain_state", "not-requested")
    a.setdefault("chain_started_at", None)
    a.setdefault("chain_finished_at", None)
    a.setdefault("chain_error", None)
    a.setdefault("steps", [])
    return a


def verdict(doc: dict[str, Any], phrase: str | None = None) -> str:
    a = _auth(doc)
    if a["granted"]:
        return "run-chain"
    if phrase is not None:
        return "granted" if phrase.strip() == GRANT_PHRASE else "not-granted"
    return "needs-grant"


def grant(doc: dict[str, Any], phrase: str, at: float | None = None) -> dict[str, Any]:
    """Record the grant.  A paraphrase is refused and changes nothing."""
    a = _auth(doc)
    if phrase.strip() != GRANT_PHRASE:
        a["chain_error"] = "phrase not accepted: %r" % phrase
        return a
    a["granted"] = True
    a["granted_at"] = float(at if at is not None else time.time())
    a["phrase_seen"] = phrase.strip()
    a["chain_state"] = "granted"
    a["chain_error"] = None
    return a


def can_run(doc: dict[str, Any], step: str) -> str:
    """Three refusals, in the order they matter."""
    a = _auth(doc)
    if step not in STEPS:
        return "unknown-step"
    if not a["granted"]:
        return "blocked"          # the red line
    if a["chain_error"]:
        return "blocked-after-failure"
    done = list(a.get("steps") or [])
    if step in done:
        return "already-done"
    idx = STEPS.index(step)
    for earlier in STEPS[:idx]:
        if earlier not in done:
            return "blocked-out-of-order"
    return "ok"


def run_step(doc: dict[str, Any], step: str, result: str = "ok",
             detail: str | None = None) -> dict[str, Any]:
    a = _auth(doc)
    if can_run(doc, step) != "ok":
        return a
    if step == "render":
        a["chain_state"] = "rendering"
        a["chain_started_at"] = a["chain_started_at"] or time.time()
    a["steps"] = list(a.get("steps") or []) + [step]
    if result == "failed":
        a["chain_state"] = "halted"
        a["chain_error"] = detail or "%s failed" % step
        return a
    if step == STEPS[-1]:
        a["chain_state"] = "done"
        a["chain_finished_at"] = time.time()
    else:
        a["chain_state"] = "%s-done" % step
    return a


def plan_output(master_exists: bool = False) -> str:
    """Never overwrite an existing master.  A second render in the same batch is
    a sign the first one should be checked, not silently replaced."""
    return "refuse-overwrite" if master_exists else "write-new"


def main() -> int:
    ap = argparse.ArgumentParser(description="Run the 4K chain once granted; never before.")
    ap.add_argument("state", type=Path)
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("grant-status")

    p = sub.add_parser("grant")
    p.add_argument("--phrase", required=True)
    p.add_argument("--at", type=float, default=None)

    p = sub.add_parser("run-step")
    p.add_argument("--step", required=True, choices=STEPS)
    p.add_argument("--result", default="ok")
    p.add_argument("--detail", default=None)

    args = ap.parse_args()
    doc = load_state(args.state)

    if args.cmd == "grant-status":
        a = _auth(doc)
        print(json.dumps({"verdict": verdict(doc), "authorization": a},
                         ensure_ascii=False))
        return 0
    if args.cmd == "grant":
        grant(doc, args.phrase, args.at)
    elif args.cmd == "run-step":
        run_step(doc, args.step, args.result, args.detail)

    doc["next_action"] = {
        "needs-grant": "wait for the user to say 「%s」" % GRANT_PHRASE,
        "run-chain": "run the 4K chain unattended: render -> verify -> cleanup",
        "granted": "run the 4K chain unattended: render -> verify -> cleanup",
    }.get(verdict(doc), "inspect the chain state")
    save_state(args.state, doc)
    a = _auth(doc)
    print(json.dumps({"verdict": verdict(doc), "chain_state": a["chain_state"],
                      "steps": a.get("steps"), "chain_error": a.get("chain_error")},
                     ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
