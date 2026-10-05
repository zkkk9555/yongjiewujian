"""Score benchmark runs against the accepted baseline (large-v3 fp16 beam5 VAD).

Metrics (offline, no images):
  charsim       : normalized char-level similarity of concatenated text vs baseline
  rec12 / rec30 : share of BASELINE combat-keyword cues that the candidate also hits
                  within +-12 s / +-30 s. This is the 'anti-miss scan' recall that
                  actually matters for this project -- it is NOT generic CER.
  prec          : share of candidate combat cues backed by a baseline cue

NOTE: recall conflates two failure modes -- the text changed, OR the segment
merged/shifted so the timestamp no longer lines up. Use lost_cues.py to tell them
apart; both are reported per-cue there.

usage: python score.py <outdir> <ref_label> <label...>
"""
import difflib
import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# verbatim from 864 reports/tools/voice_index.py -- the project's combat vocabulary
COMBAT = ["杀", "开大", "大招", "打他", "打我", "打你", "打过来", "拉药", "弹", "闪避", "钩",
          "倒地", "救", "队友", "敌人", "报点", "血量", "护甲", "包", "追", "跑", "快",
          "打药", "武器", "绝泰圈", "进攻", "偷袭", "小心", "倒了", "三杀", "打不过", "打不"]


def load(outdir, label):
    return json.loads((Path(outdir) / (label + ".json")).read_text(encoding="utf-8"))


def cues(segs):
    return [(float(s["start"]), s["text"], [w for w in COMBAT if w in s["text"]])
            for s in segs if any(w in s["text"] for w in COMBAT)]


def match(a, b, tol):
    used, pairs = set(), 0
    for ca in a:
        best, bd = None, tol
        for i, cb in enumerate(b):
            if i in used:
                continue
            d = abs(ca[0] - cb[0])
            if d < bd:
                best, bd = i, d
        if best is not None:
            used.add(best)
            pairs += 1
    return pairs


def flat(segs):
    return "".join(s["text"] for s in segs).replace(" ", "")


def main():
    outdir, ref = sys.argv[1], sys.argv[2]
    R = load(outdir, ref)
    rc = cues(R["segments"])
    rtext = flat(R["segments"])
    print("REF %s: cues=%d segs=%d chars=%d decode=%ss rf=%sx"
          % (ref, len(rc), R["meta"]["segments"], len(rtext),
             R["meta"]["decode_wall_s"], R["meta"]["realtime_factor"]))
    print()
    hdr = ("%-26s %-12s %-13s %-5s %-4s %9s %8s %8s %6s %6s %9s %5s %6s %6s %6s"
           % ("label", "model", "ct", "beam", "vad", "dec_s", "rf_x", "ffmpeg",
              "segs", "chars", "charsim", "cues", "rec12", "rec30", "prec"))
    print(hdr)
    print("-" * len(hdr))
    for lab in [ref] + list(sys.argv[3:]):
        try:
            D = load(outdir, lab)
        except FileNotFoundError:
            print("%-26s (missing)" % lab)
            continue
        m, cc = D["meta"], cues(D["segments"])
        t = flat(D["segments"])
        print("%-26s %-12s %-13s %-5d %-4d %9.2f %8.2f %8s %6d %6d %9.3f %5d %6.2f %6.2f %6.2f"
              % (lab, str(m["model"])[:12], m["compute_type"], m["beam_size"], int(m["vad"]),
                 m["decode_wall_s"], m["realtime_factor"],
                 m.get("ffmpeg_procs_during_run", m.get("ffmpeg_after", "?")),
                 m["segments"], len(t), difflib.SequenceMatcher(None, rtext, t).ratio(),
                 len(cc), match(rc, cc, 12.0) / len(rc) if rc else float("nan"),
                 match(rc, cc, 30.0) / len(rc) if rc else float("nan"),
                 match(rc, cc, 12.0) / len(cc) if cc else float("nan")))


if __name__ == "__main__":
    main()