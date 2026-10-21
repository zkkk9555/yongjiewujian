"""Merge available lanes into a PARTIAL timeline -- roughcut-launch.md §2.8.

Why this exists
---------------
The island-merge escape valve has been written into the rules since the g upgrade,
but four tasks never used it (zero `merge_decision_v*-partial*` files on disk).
The reason is §2.8's own three clauses:

    §2.3 last line   partial never becomes final
    §2.8 island def  island = a closed run of consecutive recycled lanes
    §2.6            a draft carries `-partial`, is never frozen, and is refused
                     by the subtitle / render / self-audit stages

Those clauses are what *stopped* it working: nobody implemented a merge that
emits a partial, so the valve had no handle.  Task 861 then waited 9.3 hours with
26 of 29 lanes back and nothing on disk.

§2.8 is the authority for every decision here.  Nothing in this module invents a
merge policy; it implements what the rule already says.

What it does NOT do
-------------------
* It does not relax the "partial never becomes final" rule.  It emits partials
  under the exact names the rule reserves, and the gates reject them by name.
* It does not decide *whether* two lanes' 5-second overlap bands agree.  §2.8
  gives that judgement to a single arbiter (the line-repairer) with
  double-sided independent evidence; a script that invented a verdict would be
  exactly the "automated the thing that must not be automated" mistake this
  project keeps paying for.  It records the seam and names who must resolve it.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
from orchestrator_state import load as load_state, save as save_state  # noqa: E402

# §2.8: internal 5-second overlap must be corroborated by both sides
OVERLAP_S = 5.0

# §2.8: partial artefacts are named merge_decision_vN-partial-r{k}
PARTIAL_MARK = "-partial"

# §2.6: these stages refuse anything carrying PARTIAL_MARK
PARTIAL_REFUSING_STAGES = ("subtitle", "render", "selfaudit", "freeze")


def lane_report(doc: dict[str, Any], lane_id: int) -> dict[str, Any] | None:
    for row in doc.get("lanes") or []:
        if row.get("id") == lane_id:
            return row
    return None


def recycled_lanes(doc: dict[str, Any]) -> list[int]:
    return [r["id"] for r in doc.get("lanes") or []
            if r.get("status") == "recycled" and r.get("report_path")]


def islands(lanes: list[int]) -> list[list[int]]:
    """Consecutive runs, in lane order.  §2.8's "closed set of consecutive
    recycled lanes"; gaps split islands rather than bridging them."""
    out: list[list[int]] = []
    for lane in lanes:
        if out and lane == out[-1][-1] + 1:
            out[-1].append(lane)
        else:
            out.append([lane])
    return out


def seams_for(isl: list[int], total: int) -> list[dict[str, Any]]:
    """`SEAM-<missing lane>L/R` for every missing lane adjacent to the island.

    §2.8: "no conclusion is asserted across a missing lane; only the seam is
    recorded".  So a seam names the lane that is missing and which side of this
    island it borders -- it never guesses what lies beyond it.
    """
    lo, hi = min(isl), max(isl)
    seams = []
    for missing in range(lo - 1, 0, -1):
        seams.append({"seam": "SEAM-%dL" % missing, "at": missing, "side": "L",
                      "island": isl[0]})
    for missing in range(hi + 1, total + 1):
        seams.append({"seam": "SEAM-%dR" % missing, "at": missing, "side": "R",
                      "island": isl[-1]})
    return seams


def _episodes_from(row: dict[str, Any]) -> list[dict[str, Any]]:
    """Lane reports carry candidate episodes; tolerate the field names that have
    actually appeared on disk (`episodes`, `combat_episodes`, `candidates`)."""
    for key in ("episodes", "combat_episodes", "candidates"):
        value = row.get(key)
        if isinstance(value, list):
            return [e for e in value if isinstance(e, dict)]
    return []


def build_partial(doc: dict[str, Any], isl: list[int], parent_version: str,
                  round_index: int) -> dict[str, Any]:
    """One island's PARTIAL: its episodes, its seams, and an explicit not-final
    marker that the refusing stages key off."""
    episodes: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    for lane_id in isl:
        row = lane_report(doc, lane_id)
        if row is None:
            continue
        for ep in _episodes_from(row):
            enriched = dict(ep)
            enriched.setdefault("source_lane", lane_id)
            episodes.append(enriched)
        unresolved.append({
            "lane": lane_id,
            "needs": "§2.8 single arbiter, dual-sided independent evidence for the "
                     "5-second overlap bands; a script must not decide this",
            "status": "needs-arbitration",
        })

    episodes.sort(key=lambda e: float(e.get("source_start", 0.0)))
    seams = seams_for(isl, doc.get("lanes_total") or len(doc.get("lanes") or []))

    return {
        "schema": doc.get("schema", "naraka-combat-roughcut-timeline/v1"),
        "version": "%s-partial-r%d" % (parent_version, round_index),
        "partial": True,
        "partial_reason": "island %s; lanes %s recycled, %d still missing"
                          % ("+".join(str(i) for i in isl),
                             ",".join(str(i) for i in isl),
                             sum(1 for s in seams)),
        "island": isl,
        "parent_version": parent_version,
        "seams": seams,
        "needs_arbitration": unresolved,
        "source": doc.get("source_path"),
        "source_duration": doc.get("source_duration"),
        "combat_episodes": episodes,
        "generated_at": time.time(),
    }


def refuse_partial(name: str) -> bool:
    """§2.6: a `-partial` artefact must be refused by the stages that ship or
    judge it.  Returns True when the name must be rejected."""
    return PARTIAL_MARK in name


def merge_available(state_path: Path, out_dir: Path, parent_version: str = "vN",
                    dry_run: bool = False) -> dict[str, Any]:
    """Emit one PARTIAL per island.  Never a FROZEN candidate."""
    doc = load_state(state_path)
    lanes = recycled_lanes(doc)
    if not lanes:
        return {"islands": [], "written": [], "dry_run": dry_run,
                "why": "no recycled lane yet"}

    groups = islands(lanes)
    written: list[str] = []
    written_docs: list[dict[str, Any]] = []
    for k, isl in enumerate(groups, 1):
        partial = build_partial(doc, isl, parent_version, k)
        written_docs.append(partial)
        if dry_run:
            continue
        out_dir.mkdir(parents=True, exist_ok=True)
        # §2.8 reserves exactly this name: merge_decision_vN-partial-r{k}
        target = out_dir / ("merge_decision_%s-partial-r%d.json" % (parent_version, k))
        target.write_text(json.dumps(partial, ensure_ascii=False, indent=1) + "\n",
                          encoding="utf-8")
        written.append(str(target))

    if not dry_run and written_docs:
        doc["next_action"] = ("merge %d recycled lane(s) now (partial); %d still missing"
                              % (len(lanes), (doc.get("lanes_total") or 0) - len(lanes)))
        doc["phase"] = "merge-partial"
        save_state(state_path, doc)

    return {"islands": groups, "written": written, "dry_run": dry_run,
            "lanes_recycled": len(lanes),
            "lanes_missing": (doc.get("lanes_total") or 0) - len(lanes)}


def main() -> int:
    ap = argparse.ArgumentParser(description="Island merge (§2.8); emits PARTIAL only.")
    ap.add_argument("state", type=Path)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--parent-version", default="vN")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    res = merge_available(args.state, args.out_dir, args.parent_version, args.dry_run)
    print(json.dumps(res, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
