"""Throwaway: THE decisive test. Can machine signals separate KEPT (combat) from DELETED
(non-combat) in SOURCE time, using a real human-verified timeline whose source still exists?

Task 849: 123/13.849*/timeline/combat_episodes_v8.json, source_duration 2399.3s,
13 kept episodes, 12 deleted intervals. Source: E:\\PR导出\\849*.mp4

Everything here is arithmetic over existing JSON + measured signals. No frames are viewed.
"""
import csv, glob, json, os, subprocess, sys
import numpy as np
import librosa

FFMPEG = r"C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe"
PY = sys.executable
PROBE = r"C:\Project\永劫无间\.scratch\aivideo\bench_probe.py"
T = os.path.join(os.environ["TEMP"], "opencode")
os.makedirs(T, exist_ok=True)

tl = glob.glob(r"C:\Project\永劫无间\123\13.849*\timeline\combat_episodes_v8.json")[0]
D = json.load(open(tl, encoding="utf-8"))
src = glob.glob(r"E:\PR*\849*.mp4")[0]
dur = D["source_duration"]
print("timeline:", os.path.basename(tl))
print("source  :", os.path.basename(src), f"duration={dur:.1f}s")

proxy = os.path.join(T, "g849.mp4")
wav = os.path.join(T, "g849.wav")
sigcsv = os.path.join(T, "g849.csv")

if not os.path.exists(proxy):
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", src, "-an",
                    "-vf", "fps=10,scale=480:-2", "-c:v", "libx264", "-preset", "veryfast",
                    "-crf", "23", "-y", proxy], check=True)
if not os.path.exists(wav):
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", src, "-vn",
                    "-ac", "1", "-ar", "32000", "-y", wav], check=True)
if not os.path.exists(sigcsv):
    subprocess.run([PY, PROBE, proxy, "--seconds", str(dur), "--out", sigcsv],
                   check=True, stdout=subprocess.DEVNULL)

rows = [r for r in csv.DictReader(open(sigcsv, encoding="utf-8")) if r.get("flow")]
t = np.array([float(r["t"]) for r in rows])
SIG = {
    "flow_p95": np.array([float(r["flow_p95"]) for r in rows]),
    "fdiff": np.array([float(r["fdiff"]) for r in rows]),
    "content_val": np.array([float(r["content_val"]) for r in rows]),
    "edge": np.array([float(r["edge"]) for r in rows]),
}
y, sr = librosa.load(wav, sr=32000, mono=True)
hop = 3200  # 10 fps grid
n0 = min(len(t), len(librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)))
SIG["audio_onset_env"] = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop)[:n0]
SIG["audio_rms_db"] = 20 * np.log10(librosa.feature.rms(y=y, hop_length=hop)[0][:n0] + 1e-9)
G = t[:min(len(v) for v in SIG.values())]
for k in SIG: SIG[k] = SIG[k][:len(G)]

# ---- labels in SOURCE time ---------------------------------------------------
kept = np.zeros(len(G), bool)
for ep in D["combat_episodes"]:
    kept |= (G >= ep["source_start"]) & (G < ep["source_end"])
deleted = np.zeros(len(G), bool)
for dv in D.get("deleted_intervals", []):
    deleted |= (G >= dv["start"]) & (G < dv["end"])
neither = ~(kept | deleted)
print(f"grid={len(G)} kept={kept.sum()} ({kept.mean():.1%}) deleted={deleted.sum()} ({deleted.mean():.1%}) unlabelled={neither.sum()}")

def auc(p, q):
    p = np.asarray(p, float); q = np.asarray(q, float)
    p = p[~np.isnan(p)]; q = q[~np.isnan(q)]
    if not len(p) or not len(q): return float("nan")
    return float(((p[:, None] > q[None, :]).sum() + 0.5 * (p[:, None] == q[None, :]).sum()) / (len(p) * len(q)))

def sm(v, k=15):   # 1.5 s box smoothing on the 10 fps grid
    return np.convolve(v, np.ones(k) / k, mode="same")

print("\n=== KEPT vs DELETED, per-second samples, 1.5s smoothing ===")
print(f"  {'signal':16s} {'raw AUC':>9s} {'smoothed AUC':>14s}   kept_mean  del_mean")
best = []
for k, v in SIG.items():
    a_raw = auc(v[kept], v[deleted])
    vs = sm(v)
    a_sm = auc(vs[kept], vs[deleted])
    best.append((a_sm, k))
    print(f"  {k:16s} {a_raw:9.3f} {a_sm:14.3f}   {v[kept].mean():9.3f}  {v[deleted].mean():8.3f}")
best.sort(reverse=True)
print(f"  best single smoothed signal: {best[0][1]} AUC={best[0][0]:.3f}")

print("\n=== equal-weight z-fusion ===")
def z(v): return (v - v.mean()) / (v.std() or 1.0)
for subset in (["flow_p95", "fdiff", "content_val"],
               ["audio_onset_env", "audio_rms_db"],
               list(SIG.keys())):
    f = np.zeros(len(G))
    for k in subset: f += z(sm(SIG[k]))
    print(f"  {'+'.join(subset):46s} AUC={auc(f[kept], f[deleted]):.3f}")

print("\n=== how good is the best possible per-signal threshold? (kept vs deleted) ===")
for k, v in SIG.items():
    vs = sm(v)
    scores = []
    for q in range(1, 100, 2):
        thr = np.percentile(vs, q)
        pred = vs >= thr
        prec = (pred & kept).sum() / max(pred.sum(), 1)
        rec = (pred & kept).sum() / max(kept.sum(), 1)
        f1 = 2 * prec * rec / max(prec + rec, 1e-9)
        scores.append((f1, prec, rec, q, thr))
    f1, prec, rec, q, thr = max(scores)
    print(f"  {k:16s} best F1={f1:.3f} (P={prec:.3f} R={rec:.3f}) at q={q} thr={thr:.3f}")

print("\n=== baseline: what does 'predict everything' score? ===")
print(f"  always-keep precision={kept.sum()/(kept|deleted).sum():.3f} recall=1.000")