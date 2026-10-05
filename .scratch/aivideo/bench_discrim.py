"""Throwaway: refined discrimination test using ONLY inside-episode negatives.

Fixes the flaw in bench_groundtruth.py: negatives are now episode seconds that are >=5s away
from every impact_point / engage_start / outcome_time, so "kept vs deleted" is not confounded
(the program contains only kept material, so that comparison was degenerate by construction).

Also tests a fused score so the ceiling of pure signal arithmetic is visible.
"""
import csv, glob, json, os, subprocess, sys
import numpy as np
import librosa

T = os.path.join(os.environ["TEMP"], "opencode")
tl = glob.glob(r"C:\Project\永劫无间\123\21.864*\timeline\combat_episodes_v3.json")[0]
D = json.load(open(tl, encoding="utf-8"))
prog_dur = D["program_seconds_total"]

rows = [r for r in csv.DictReader(open(os.path.join(T, "prog864.csv"), encoding="utf-8")) if r.get("flow")]
t = np.array([float(r["t"]) for r in rows])
flow = np.array([float(r["flow_p95"]) for r in rows])
fdiff = np.array([float(r["fdiff"]) for r in rows])
cval = np.array([float(r["content_val"]) for r in rows])

y, sr = librosa.load(os.path.join(T, "prog864.wav"), sr=32000, mono=True)
hop = 1600
onset = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)
rms = 20 * np.log10(librosa.feature.rms(y=y, hop_length=hop)[0] + 1e-9)
n = min(len(onset), len(flow), len(t))
G = t[:n]; flow, fdiff, cval = flow[:n], fdiff[:n], cval[:n]; onset, rms = onset[:n], rms[:n]

impacts, engages, outcomes, ep_spans = [], [], [], []
for ep in D["combat_episodes"]:
    off = ep["source_start"] - ep["program_start"]
    ep_spans.append((ep["program_start"], ep["program_end"]))
    impacts += [p - off for p in ep.get("impact_points", [])]
    if ep.get("engage_start") is not None: engages.append(ep["engage_start"] - off)
    if ep.get("outcome_time") is not None: outcomes.append(ep["outcome_time"] - off)
key = np.array(sorted(impacts + engages + outcomes))
keep_far = np.array([np.abs(key - x).min() > 5.0 for x in G])   # safe negatives

def auc(p, q):
    p = np.asarray(p, float); q = np.asarray(q, float)
    p = p[~np.isnan(p)]; q = q[~np.isnan(q)]
    if not len(p) or not len(q): return float("nan")
    return float(((p[:, None] > q[None, :]).sum() + 0.5 * (p[:, None] == q[None, :]).sum()) / (len(p) * len(q)))

def win(sig, centres, half):
    return np.array([float(sig[np.abs(G - c) <= half].mean()) for c in centres])

pos_pts = np.array(impacts)
neg_pts = G[keep_far]
print(f"positives(impact)={len(pos_pts)}  negatives(episode, >5s from every key event)={len(neg_pts)}")

SIG = {"flow_p95": flow, "fdiff": fdiff, "content_val": cval,
       "audio_onset_env": onset, "audio_rms_db": rms}

print("\n=== single signal: impact(+-2s) vs safe episode negative ===")
scores = {}
for k, s in SIG.items():
    a = auc(win(s, pos_pts, 2.0), win(s, neg_pts, 2.0))
    scores[k] = a
    print(f"  {k:16s} AUC={a:.3f}")

print("\n=== z-fused score (equal weight, z-scored over whole program) ===")
def z(v): return (v - v.mean()) / (v.std() or 1.0)
Z = {k: z(v) for k, v in SIG.items()}
fuse = z(z(flow) + z(fdiff) + z(cval) + z(rms) + z(onset))
print(f"  visual only (flow+fdiff+cv)   AUC={auc(win(fuse if False else z(flow)+z(fdiff)+z(cval), pos_pts, 2.0), win(z(flow)+z(fdiff)+z(cval), neg_pts, 2.0)):.3f}")
print(f"  audio only (rms+onset)       AUC={auc(win(z(rms)+z(onset), pos_pts, 2.0), win(z(rms)+z(onset), neg_pts, 2.0)):.3f}")
print(f"  all five                     AUC={auc(win(fuse, pos_pts, 2.0), win(fuse, neg_pts, 2.0)):.3f}")

print("\n=== ceiling check: what AUC do 5 random splits of the same data give? ===")
rng = np.random.default_rng(1)
vals = win(flow, pos_pts, 2.0)
allv = np.concatenate([vals, win(flow, neg_pts, 2.0)])
for _ in range(5):
    p = rng.permutation(allv)[:len(vals)]
    print(f"  random-split flow_p95 AUC={auc(p, rng.permutation(allv)[:len(vals)]):.3f}")