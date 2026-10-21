r"""Squad-state meter: is each member's own armour/health bar full, per second.

Pure ASCII source; non-ASCII fragments come from \\u escapes.

Why this exists
---------------
Task 28 cut a fight with source_start at 286.0, and the first delivered frame
already had the teammate's armour depleted (it drops at ~284.6).  The rule that
covers this ("teammate hit first means the fight already started") was already in
complete-combat-roughcut.md 2.1, but nothing could SEE it: every lane, every gate
and every reviewer was reading the ENEMY's red bar, the damage numbers and the
lock-on line -- all three describe the PLAYER's engagement.  Nothing read the
squad's own bars, so "this episode opens with the team already hurt" was invisible
to the whole apparatus.  Wrong instrument, not wrong rule.

The metric
----------
The right few pixels of a bar slot are the discriminator: a full bar reaches the
slot's right edge, a depleted bar leaves that stretch empty.  Measuring total fill
instead is polluted by the name badge, the portrait and bright scenery behind the
panel -- on task 28 the total fill of the teammate's armour was constant across
278-284 while the right edge correctly showed the 284.6 drop.

The revival realm / underworld swaps the armour palette from purple to gold; both
are accepted, otherwise those fights are reported as "armour missing".

Usage
-----
    # one pass, 4K HUD band at 1 fps (frames land mid-bucket: stamp N = source N-0.5)
    ffmpeg -i <source> -vf "crop=460:350:0:1760,fps=1" -q:v 2 <task>\cache\squadband\s%04d.jpg

    python squad_state.py --band <task>\cache\squadband --out <task>\analysis\squad_state.json
    python squad_state.py --band ... --out ... --timeline <task>\timeline\combat_episodes_vN.json

The crop is layout-dependent: EYEBALL THE BAND ONCE before trusting the numbers.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

import numpy as np

W_DEFAULT, H_DEFAULT = 460, 350
TAIL_X_DEFAULT = (430, 460)
# (member label, armour band rows, health band rows) in the cropped band
ROWS_DEFAULT = [("mate2", (104, 112), (123, 137)), ("self", (284, 292), (300, 316))]
FFMPEG_CANDIDATES = (
    r"C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe",
    "ffmpeg",
)


def ffmpeg() -> str:
    for candidate in FFMPEG_CANDIDATES:
        if candidate == "ffmpeg" or os.path.exists(candidate):
            return candidate
    return "ffmpeg"


def load(path: str, width: int, height: int):
    out = subprocess.run(
        [ffmpeg(), "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True,
    ).stdout
    if len(out) < width * height * 3:
        return None
    return (np.frombuffer(out, dtype=np.uint8, count=width * height * 3)
            .reshape(height, width, 3).astype(np.int16))


def measure(path: str, width: int, height: int, rows, tail) -> dict | None:
    img = load(path, width, height)
    if img is None:
        return None
    r, g, b = img[:, :, 0], img[:, :, 1], img[:, :, 2]
    purple = (b > 150) & (r > 110) & (r < 215) & (g < 150) & (b > g + 40)
    gold = (r > 170) & (g > 140) & (b < 130) & (r > b + 70)
    upper = purple | gold
    white = (r > 215) & (g > 215) & (b > 215)
    readable = bool(upper[rows[0][1][0]:rows[0][1][1]].any()
                    or white[rows[0][2][0]:rows[0][2][1]].any()
                    or upper[rows[-1][1][0]:rows[-1][1][1]].any()
                    or white[rows[-1][2][0]:rows[-1][2][1]].any())
    entry = {"hud_readable": readable}
    for name, armour_rows, health_rows in rows:
        entry[name + "_armour_full"] = (
            bool(upper[armour_rows[0]:armour_rows[1], tail[0]:tail[1]].any()) if readable else None)
        entry[name + "_health_full"] = (
            bool(white[health_rows[0]:health_rows[1], tail[0]:tail[1]].any()) if readable else None)
    return entry


def entry_ok(entry: dict, members) -> bool:
    if not entry or not entry.get("hud_readable"):
        return False
    return all(entry.get(m + "_" + k + "_full") for m in members for k in ("armour", "health"))


def main() -> int:
    ap = argparse.ArgumentParser(description="Per-second squad bar state.")
    ap.add_argument("--band", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--width", type=int, default=W_DEFAULT)
    ap.add_argument("--height", type=int, default=H_DEFAULT)
    ap.add_argument("--tail", default="%d,%d" % TAIL_X_DEFAULT)
    ap.add_argument("--timeline", type=Path,
                    help="optional: report the entry state of every episode's source_start")
    args = ap.parse_args()

    tail = tuple(int(x) for x in args.tail.split(","))
    rows = ROWS_DEFAULT
    members = [m[0] for m in rows]

    records = []
    for name in sorted(os.listdir(args.band)):
        if not name.endswith(".jpg"):
            continue
        try:
            stamp = int(name[1:5])
        except ValueError:
            continue
        entry = measure(str(args.band / name), args.width, args.height, rows, tail)
        if entry is None:
            continue
        entry["sec_stamp"] = stamp
        entry["source_sec"] = stamp - 0.5      # fps=1 lands mid-bucket; declared, never used for a cut
        records.append(entry)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(
        {"schema": "naraka-squad-state/v1", "band": str(args.band),
         "note": "frame stamped N is source second N-0.5 (fps=1 mid-bucket)",
         "metric": "bar reaches the right edge of its slot (x %d-%d)" % tail,
         "members": members, "rows": records}, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")

    readable = sum(1 for r in records if r["hud_readable"])
    print("squad_state: %d seconds, %d readable" % (len(records), readable))

    if args.timeline and args.timeline.is_file():
        doc = json.loads(args.timeline.read_text(encoding="utf-8-sig"))
        episodes = doc.get("combat_episodes") or doc.get("episodes") or []
        bad = []
        for ep in episodes:
            start = float(ep["source_start"])
            near = min(records, key=lambda r: abs(r["source_sec"] - start)) if records else None
            ok = entry_ok(near, members)
            print("  %-16s source_start %8.1f  %s"
                  % (ep.get("id", "?"), start, "FULL" if ok else "NOT FULL"))
            if not ok:
                bad.append(ep.get("id", "?"))
        if bad:
            print("ENTRY_STATE_FAIL: %s" % ", ".join(bad))
            return 1
        print("ENTRY_STATE_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
