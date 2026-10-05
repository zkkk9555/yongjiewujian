"""Which combat cues does a candidate lose vs the reference, and on what term?

usage: python lost_cues.py <outdir> <ref_label> <label>
"""
import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

COMBAT = ["杀", "开大", "大招", "打他", "打我", "打你", "打过来", "拉药", "弹", "闪避", "钩",
          "倒地", "救", "队友", "敌人", "报点", "血量", "护甲", "包", "追", "跑", "快",
          "打药", "武器", "绝泰圈", "进攻", "偷袭", "小心", "倒了", "三杀", "打不过", "打不"]
TOL = 12.0

outdir, ref_label, label = sys.argv[1], sys.argv[2], sys.argv[3]


def load(lab):
    return json.loads((Path(outdir) / (lab + ".json")).read_text(encoding="utf-8"))["segments"]


def cues(segs):
    return [(float(s["start"]), s["text"], [w for w in COMBAT if w in s["text"]])
            for s in segs if any(w in s["text"] for w in COMBAT)]


R = load(ref_label)
C = load(label)
rc, cc = cues(R), cues(C)
print("REF %s: %d cues | CANDIDATE %s: %d cues\n" % (ref_label, len(rc), label, len(cc)))

# nearest candidate cue within tolerance
def near(t):
    best, bd = None, TOL
    for c in cc:
        d = abs(c[0] - t)
        if d < bd:
            best, bd = c, d
    return best


print("%-8s %-26s %-22s %s" % ("time", "REFERENCE said", "terms", "candidate said (or MISSED)"))
lost = 0
for t, text, hits in rc:
    n = near(t)
    tag = "ok"
    if n is None:
        tag = "*** LOST ***"
        lost += 1
        print("%-8.1f %-26s %-22s %s" % (t, text[:24], ",".join(hits), tag))
    else:
        print("%-8.1f %-26s %-22s %s" % (t, text[:24], ",".join(hits), n[1][:28]))

extra = [c for c in cc if all(abs(c[0] - r[0]) >= TOL for r in rc)]
print("\nLOST %d/%d reference cues (%.0f%% recall)" % (lost, len(rc), 100.0 * (len(rc) - lost) / len(rc)))
print("candidate-only cues (false alarms): %d" % len(extra))
for c in extra:
    print("   +%-8.1f %-28s [%s]" % (c[0], c[1][:26], ",".join(c[2])))