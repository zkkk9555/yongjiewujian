"""One-off audit: is coverage_complete actually computing on every real timeline,
or is it silently taking the "cannot judge" path and reporting PASS?

Run from the project root. Prints per-timeline counts next to the gate's verdict
so a PASS with 0 deletions declared is visible as such.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
GATE = os.path.join(ROOT, "skills", "naraka-highlight-studio", "scripts", "qa_gate.py")
TIMELINES = os.path.join(ROOT, "123")

out_dir = tempfile.mkdtemp(prefix="covaudit")
found = 0
silent = 0
print("%-46s %-5s %-22s %s" % ("timeline", "res", "input shape", "what the gate said"))
print("-" * 160)
for dirpath, _dirnames, filenames in os.walk(TIMELINES):
    for name in sorted(filenames):
        if not name.startswith("combat_episodes") or not name.endswith(".json"):
            continue
        path = os.path.join(dirpath, name)
        if os.path.getsize(path) > 200_000:
            continue
        found += 1
        out = os.path.join(out_dir, "o.json")
        if os.path.exists(out):
            os.remove(out)
        subprocess.run(
            [sys.executable, GATE, path, "--output", out],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        with open(out, encoding="utf-8") as fh:
            doc = json.load(fh)
        cov = next((c for c in doc["checks"] if c["name"] == "coverage_complete"), None)
        if cov is None:
            print("%-46s %-5s" % (name, "MISSING"))
            continue
        with open(path, encoding="utf-8") as fh:
            tl = json.load(fh)
        eps = tl.get("combat_episodes") or tl.get("episodes") or []
        dis = tl.get("deleted_intervals") or []
        sd = tl.get("source_duration")
        shape = "ep=%d di=%d sd=%s" % (
            len(eps), len(dis), ("%.1f" % sd) if isinstance(sd, (int, float)) else "None",
        )
        judged = bool(eps) and bool(dis) and isinstance(sd, (int, float)) and sd > 0
        if not judged:
            silent += 1
        print("%-46s %-5s %-22s %s" % (name, cov["result"], shape, cov["measured"][:78]))
        if not judged:
            print("      ^ NOT ACTUALLY JUDGED (no episodes, or no deletions, or no source_duration)")
print()
print("timelines: %d   actually judged: %d   silently unjudged: %d" % (found, found - silent, silent))
