"""Throwaway: cross-window comparison of the zero-view signals. No images viewed."""
import subprocess, sys, os
import numpy as np
import librosa

T = os.environ["TEMP"]
PROBE = r"C:\Project\永劫无间\.scratch\aivideo\bench_probe.py"
PY = sys.executable


def sig(mp, csvout):
    subprocess.run([PY, PROBE, mp, "--seconds", "60", "--out", csvout],
                   check=True, stdout=subprocess.DEVNULL)
    rows = [r for r in __import__("csv").DictReader(open(csvout, encoding="utf-8")) if r.get("flow")]
    return {k: np.array([float(r[k]) for r in rows]) for k in ("flow_p95", "fdiff", "content_val", "edge")}


def corr(a, b):
    a = a - a.mean(); b = b - b.mean()
    d = np.sqrt((a**2).sum()) * np.sqrt((b**2).sum())
    return float((a * b).sum() / d) if d else 0.0


for s in (60, 400, 900, 1400):
    d = sig(os.path.join(T, "opencode", f"w{s}.mp4"), os.path.join(T, "opencode", f"w{s}.csv"))
    y, sr = librosa.load(os.path.join(T, "opencode", f"w{s}.wav"), sr=32000, mono=True)
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=1600)
    rms = 20 * np.log10(librosa.feature.rms(y=y, hop_length=1600)[0] + 1e-9)
    n = min(len(env), len(d["flow_p95"]))
    print(
        f"win={s:5d}s  flow p50={np.percentile(d['flow_p95'][:n],50):6.2f} p90={np.percentile(d['flow_p95'][:n],90):6.2f}"
        f"  cv p50={np.percentile(d['content_val'][:n],50):6.2f} p90={np.percentile(d['content_val'][:n],90):6.2f}"
        f"  edge p50={np.percentile(d['edge'][:n],50):.3f}"
        f"  rms_dB p50={np.percentile(rms[:n],50):6.1f}"
        f"  onsets/s={len(librosa.onset.onset_detect(onset_envelope=env[:n], sr=sr, hop_length=1600))/60:5.2f}"
        f"  corr(flow,onset)={corr(d['flow_p95'][:n], env[:n]):+.3f}"
    )