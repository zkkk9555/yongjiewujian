"""Throwaway: do zero-view signals spike at KNOWN impact points?

Ground truth comes from 123/21.864*/timeline/combat_episodes_v3.json, which carries both
source-time and program-time coordinates. We measure signals on the finished PROGRAM
(E:\\Cujian导出\\864...cujian.mp4), so every episode's source times can be mapped to program
time and the known impact_points / engage_start / outcome_time become labels.

No frames are viewed. Everything below is arithmetic over the existing JSON + measured signals.
"""
import csv, glob, json, os, subprocess, sys
import numpy as np

FFMPEG = r"C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe"
PY = sys.executable
PROBE = r"C:\Project\永劫无间\.scratch\aivideo\bench_probe.py"
T = os.path.join(os.environ["TEMP"], "opencode")

tl = glob.glob(r"C:\Project\永劫无间\123\21.864*\timeline\combat_episodes_v3.json")[0]
T_ = json.load(open(tl, encoding="utf-8"))
prog = glob.glob(r"E:\Cujian*/*864*.mp4")[0]
print("timeline:", os.path.basename(tl))
print("program :", os.path.basename(prog))

# program duration from timeline
prog_dur = T_["program_seconds_total"]
print("program_seconds_total:", prog_dur)

proxy = os.path.join(T, "prog864.mp4")
wav = os.path.join(T, "prog864.wav")
sigcsv = os.path.join(T, "prog864.csv")

subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", prog, "-an",
                "-vf", "fps=20,scale=480:-2", "-c:v", "libx264", "-preset", "veryfast",
                "-crf", "23", "-y", proxy], check=True)
subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", prog, "-vn",
                "-ac", "1", "-ar", "32000", "-y", wav], check=True)
subprocess.run([PY, PROBE, proxy, "--seconds", str(prog_dur), "--out", sigcsv],
               check=True, stdout=subprocess.DEVNULL)

rows = [r for r in csv.DictReader(open(sigcsv, encoding="utf-8")) if r.get("flow")]
t = np.array([float(r["t"]) for r in rows])
flow = np.array([float(r["flow_p95"]) for r in rows])
fdiff = np.array([float(r["fdiff"]) for r in rows])
cval = np.array([float(r["content_val"]) for r in rows])

import librosa
y, sr = librosa.load(wav, sr=32000, mono=True)
hop = 1600  # 20 fps grid
onset_env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
rms_db = 20 * np.log10(librosa.feature.rms(y=y, hop_length=hop)[0] + 1e-9)
n = min(len(onset_env), len(flow), len(t))
GRID = t[:n]
flow, fdiff, cval = flow[:n], fdiff[:n], cval[:n]
onset_env, rms_db = onset_env[:n], rms_db[:n]
print(f"grid points={n} covers {GRID[-1]:.1f}s of {prog_dur:.1f}s")

# ---- build labels in program time -------------------------------------------
impacts = []          # known violent moments (impact_points) inside each episode
engages, outcomes = [], []
for ep in T_["combat_episodes"]:
    off = ep["source_start"] - ep["program_start"]   # source->program offset
    for p in ep.get("impact_points", []):
        pt = p - off
        if 0 <= pt < prog_dur:
            impacts.append(pt)
    e = ep.get("engage_start")
    o = ep.get("outcome_time")
    if e is not None and 0 <= e - off < prog_dur:
        engages.append(e - off)
    if o is not None and 0 <= o - off < prog_dur:
        outcomes.append(o - off)
print(f"labels: impacts={len(impacts)} engages={len(engages)} outcomes={len(outcomes)}")


def window_mean(sig, centre, half=2.0):
    m = np.abs(GRID - centre) <= half
    return float(sig[m].mean()) if m.any() else np.nan


def auc(scores_pos, scores_neg):
    """P(score_pos > score_neg), the probability a random impact frame outranks a random gap frame."""
    a = np.asarray(scores_pos, float); b = np.asarray(scores_neg, float)
    a = a[~np.isnan(a)]; b = b[~np.isnan(b)]
    if not len(a) or not len(b):
        return float("nan")
    wins = (a[:, None] > b[None, :]).sum() + 0.5 * (a[:, None] == b[None, :]).sum()
    return float(wins / (len(a) * len(b)))


rng = np.random.default_rng(0)
all_pts = np.arange(2.0, prog_dur - 2.0, 1.0)
impact_set = set(int(round(x)) for x in impacts)
neg_pts = np.array([x for x in all_pts if int(round(x)) not in impact_set])

SIGNALS = {
    "flow_p95": flow,
    "fdiff": fdiff,
    "content_val": cval,
    "audio_onset_env": onset_env,
    "audio_rms_db": rms_db,
}

print("\n=== discrimination at known impact_points vs all other seconds (AUC, 0.5=useless) ===")
for name, sig in SIGNALS.items():
    pos = [window_mean(sig, p, 2.0) for p in impacts]
    neg = [window_mean(sig, p, 2.0) for p in neg_pts]
    a = auc(pos, neg)
    lift = np.nanmean(pos) / (np.nanmean(neg) or 1e-9)
    print(f"  {name:16s} AUC={a:.3f}   impact_mean={np.nanmean(pos):8.3f} other_mean={np.nanmean(neg):8.3f} lift={lift:.2f}x")

print("\n=== same, but impact window tightened to +-1.0s ===")
for name, sig in SIGNALS.items():
    pos = [window_mean(sig, p, 1.0) for p in impacts]
    neg = [window_mean(sig, p, 1.0) for p in neg_pts]
    print(f"  {name:16s} AUC={auc(pos, neg):.3f}")

print("\n=== engage_start vs outcome_time (fight onset vs fight resolution) ===")
for name, sig in SIGNALS.items():
    pe = [window_mean(sig, p, 2.0) for p in engages]
    po = [window_mean(sig, p, 2.0) for p in outcomes]
    print(f"  {name:16s} engage_mean={np.nanmean(pe):8.3f} outcome_mean={np.nanmean(po):8.3f}  AUC(engage>outcome)={auc(pe, po):.3f}")

# ---- how well does a single threshold on flow_p95 recover the kept intervals? --
kept = []
for ep in T_["combat_episodes"]:
    off = ep["source_start"] - ep["program_start"]
    kept.append((ep["program_start"], ep["program_end"]))
kept_m = np.zeros(len(GRID), bool)
for a, b in kept:
    kept_m |= (GRID >= a) & (GRID < b)
print(f"\n=== single-threshold sweep on flow_p95 to reproduce the KEPT program ===")
print(f"    kept fraction={kept_m.mean():.3f}")
best = None
for q in range(50, 100, 5):
    thr = np.percentile(flow, q)
    pred = flow >= thr
    # pad/smooth: require 3 of 5 consecutive above threshold
    k = np.convolve(pred.astype(int), np.ones(5) / 5, mode="same") >= 0.6
    tp = (k & kept_m).sum(); fp = (k & ~kept_m).sum(); fn = (~k & kept_m).sum()
    prec = tp / max(tp + fp, 1); rec = tp / max(tp + fn, 1)
    f1 = 2 * prec * rec / max(prec + rec, 1e-9)
    if best is None or f1 > best[1]:
        best = (q, f1, prec, rec, thr)
    if q % 10 == 0:
        print(f"    q={q:3d} thr={thr:6.2f} precision={prec:.3f} recall={rec:.3f} F1={f1:.3f}")
q, f1, prec, rec, thr = best
print(f"    BEST q={q} thr={thr:.2f} precision={prec:.3f} recall={rec:.3f} F1={f1:.3f}")