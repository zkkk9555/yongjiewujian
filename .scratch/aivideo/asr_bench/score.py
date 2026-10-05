"""Score benchmark runs against the accepted baseline (large-v3 fp16 beam5 VAD).

Metrics (all computed offline, no images):
  charsim_vs_ref      : normalized char-level similarity of the concatenated text
  combat_recall       : share of REF combat-keyword cues that a candidate cue also
                        hits within +-12 s (this is the 'anti-miss scan' recall that
                        actually matters for this project)
  combat_precision    : share of candidate combat cues that match a REF cue +-12 s
  text_chars          : total recognized characters (proxy for output mass)
usage: python score.py <outdir> <ref_label> <label...>
"""
import json, re, sys, difflib
from pathlib import Path

# same vocabulary the project ships in 864 reports/tools/voice_index.py
COMBAT = ["杀", "开大", "大招", "打他", "打我", "打你", "打过来", "拉药", "弹", "闪避", "钩",
          "倒地", "救", "队友", "敌人", "报点", "血量", "护甲", "包", "追", "跑", "快",
          "打药", "武器", "绝泰圈", "进攻", "偷袭", "小心", "倒了", "三杀", "打不过", "打不"]
TOL = 12.0


def load(outdir, label):
    p = Path(outdir) / (label + ".json")
    return json.loads(p.read_text(encoding="utf-8"))


def cues(segs):
    out = []
    for s in segs:
        hits = [w for w in COMBAT if w in s["text"]]
        if hits:
            out.append((float(s["start"]), float(s["end"]), s["text"], hits))
    return out


def match(a, b, tol=TOL):
    """one-to-one greedy nearest match of cue lists"""
    used = set()
    pairs = 0
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


def charsim(x, y):
    return difflib.SequenceMatcher(None, x, y).ratio()


def flat(segs):
    return "".join(s["text"] for s in segs).replace(" ", "")


def main():
    outdir, ref = sys.argv[1], sys.argv[2]
    labels = sys.argv[3:]
    R = load(outdir, ref)
    rc = cues(R["segments"])
    rtext = flat(R["segments"])
    print(f"REF {ref}: cues={len(rc)} segs={R['meta']['segments']} chars={len(rtext)} "
          f"decode={R['meta']['decode_wall_s']}s rf={R['meta']['realtime_factor']}x")
    print()
    hdr = f"{'label':<28}{'model':<14}{'ct':<14}{'beam':<5}{'vad':<4}{'load_s':>7}{'dec_s':>8}{'rf_x':>7}{'segs':>6}{'chars':>7}{'logp':>8}{'charsim':>9}{'cues':>6}{'rec':>7}{'prec':>7}"
    print(hdr)
    print("-" * len(hdr))
    for lab in [ref] + labels:
        try:
            D = load(outdir, lab)
        except FileNotFoundError:
            print(f"{lab:<28} (missing)")
            continue
        m = D["meta"]
        cc = cues(D["segments"])
        t = flat(D["segments"])
        matched = match(rc, cc)
        rec = matched / len(rc) if rc else float("nan")
        prec = matched / len(cc) if cc else float("nan")
        cs = charsim(rtext, t)
        print(f"{lab:<28}{m['model'][:13]:<14}{m['compute_type']:<14}{m['beam_size']:<5}"
              f"{int(m['vad']):<4}{m['model_load_s']:>7}{m['decode_wall_s']:>8}{m['realtime_factor']:>7}"
              f"{m['segments']:>6}{len(t):>7}{m['mean_avg_logprob']:>8}{cs:>9.3f}"
              f"{len(cc):>6}{rec:>7.2f}{prec:>7.2f}")


if __name__ == "__main__":
    main()
