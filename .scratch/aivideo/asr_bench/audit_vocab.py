"""Audit the project's combat keyword vocabulary against every real transcript
that exists under 123\\. Read-only, no images, no models.

Answers the question that decides every model swap: how dense is the cue surface?
Measured on the 9 real task transcripts: 5-45 cues per match, 18-26 for a ~19 min
match, i.e. ~1-3 cues/min. Losing 1/3 of them is losing 1/3 of the scan surface.

usage: python audit_vocab.py
"""
import glob
import io
import json
import os
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

COMBAT = ["杀", "开大", "大招", "打他", "打我", "打你", "打过来", "拉药", "弹", "闪避", "钩",
          "倒地", "救", "队友", "敌人", "报点", "血量", "护甲", "包", "追", "跑", "快",
          "打药", "武器", "绝泰圈", "进攻", "偷袭", "小心", "倒了", "三杀", "打不过", "打不"]

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
files = sorted(glob.glob(os.path.join(PROJ, "123", "*", "captions", "source_transcript.json")))

tot = {}
print("%-5s %8s %6s %6s   top terms" % ("task", "dur_s", "segs", "cues"))
for f in files:
    d = json.load(open(f, encoding="utf-8"))
    segs, dur = d["segments"], d.get("duration", 0)
    hits, ncue = {}, 0
    for s in segs:
        h = [w for w in COMBAT if w in s["text"]]
        if h:
            ncue += 1
            for w in h:
                hits[w] = hits.get(w, 0) + 1
    for k, v in hits.items():
        tot[k] = tot.get(k, 0) + v
    task = os.path.basename(os.path.dirname(os.path.dirname(f))).split(".")[0]
    top = sorted(hits.items(), key=lambda x: -x[1])[:6]
    print("%-5s %8.0f %6d %6d   %s" % (task, dur, len(segs), ncue,
                                        " ".join("%s:%d" % kv for kv in top)))

never = [w for w in COMBAT if tot.get(w, 0) == 0]
print("\nterms that NEVER fired in any of the %d transcripts: %s"
      % (len(files), ", ".join(never) if never else "(none)"))
print("\nfiring counts across all tasks:")
for k, v in sorted(tot.items(), key=lambda x: -x[1]):
    print("  %-8s %d" % (k, v))