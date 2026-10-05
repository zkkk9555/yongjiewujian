"""Throwaway: harder, more realistic version of the 849 test.

Concern with the first pass: AUC 0.72 for audio_rms_db could be inflated by between-episode
offset (some fights have BGM, some don't) rather than real within-fight structure. So here each
kept episode is scored only against the deleted intervals ADJACENT to it. That removes every
between-episode confound and asks the question the pipeline actually needs answered:
"given I am already inside a battle window, can signals tell me whether this second matters?"
"""
import csv, glob, json, os
import numpy as np
import librosa

T = os.path.join(os.environ["TEMP"], "opencode")
tl = glob.glob(r"C:\Project\永劫无间\123\13.849*\timeline\combat_episodes_v8.json")[0]
D = json.load(open(tl, encoding="utf-8"))

rows = [r for r in csv.DictReader(open(os.path.join(T, "g849.csv"), encoding="utf-8")) if r.get("flow")]
t = np.array([float(r["t"]) for r in rows])
SIG = {
    "flow_p95": np.array([float(r["flow_p95"]) for r in rows]),
    "fdiff": np.array([float(r["fdiff"]) for r in rows]),
    "content_val": np.array([float(r["content_val"]) for r in rows]),
    "edge": np.array([float(r["edge"]) for r in rows]),
}
y, sr = librosa.load(os.path.join(T, "g849.wav"), sr=32000, mono=True)
hop = 3200
n0 = min(len(t), len(librosa.feature.rms(y=y, hop_length=hop)[0]))
SIG["audio_onset_env"] = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)[:n0]
SIG["audio_rms_db"] = 20 * np.log10(librosa.feature.rms(y=y, hop_length=hop)[0][:n0] + 1e-9)
G = t[:min(len(v) for v in SIG.values())]
for k in SIG: SIG[k] = SIG[k][:len(G)]
sm = lambda v, k=15: np.convolve(v, np.ones(k) / k, mode="same")

def auc(p, q):
    p = np.asarray(p, float); q = np.asarray(q, float)
    p = p[~np.isnan(p)]; q = q[~np.isnan(q)]
    if not len(p) or not len(q): return float("nan")
    return float(((p[:, None] > q[None, :]).sum() + 0.5 * (p[:, None] == q[None, :]).sum()) / (len(p) * len(q)))

eps = sorted(D["combat_episodes"], key=lambda e: e["source_start"])
dels = sorted(D.get("deleted_intervals", []), key=lambda d: d["start"])

print("per-episode: kept seconds vs the two nearest deleted intervals (within 120s of the episode)")
print(f"  {'ep':12s} {'kept_s':>7s} {'neg_s':>6s} " + " ".join(f"{k:>14s}" for k in SIG))
agg = {k: [] for k in SIG}
for ep in eps:
    a, b = ep["source_start"], ep["source_end"]
    near = [d for d in dels if 0 <= min(abs(d["end"] - a), abs(d["start"] - b)) <= 120]
    if not near:
        continue
    lo = min([d["start"] for d in near] + [a]); hi = max([d["end"] for d in near] + [b])
    km = (G >= a) & (G < b)
    nm = np.zeros(len(G), bool)
    for d in near:
        nm |= (G >= d["start"]) & (G < d["end"])
    row = []
    for k, v in SIG.items():
        vs = sm(v)
        A = auc(vs[km], vs[nm])
        if not np.isnan(A): agg[k].append(A)
        row.append(f"{A:.3f}" if not np.isnan(A) else "  n/a")
    print(f"  {ep['id']:12s} {km.sum():7d} {nm.sum():6d} " + " ".join(f"{r:>14s}" for r in row))

print("\nmedian within-episode AUC (between-confound removed):")
for k in SIG:
    v = agg[k]
    print(f"  {k:16s} median={np.median(v):.3f}  min={np.min(v):.3f} max={np.max(v):.3f}  n_ep={len(v)}")

print("\nfor contrast, the between-episode AUC from the first pass was:")
print("  flow_p95=0.570 fdiff=0.622 content_val=0.622 audio_onset_env=0.612 audio_rms_db=0.723")
print("\nAUC=0.5 means the signal cannot tell kept from deleted at all.")