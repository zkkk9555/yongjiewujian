"""Throwaway: do the machine signals (flow / fdiff / audio onset) agree with each other?

No images are viewed. If visual motion and audio transients co-locate, they are describing the
same events, which is the precondition for fusing them into one interval detector.
"""
import csv, subprocess, os, sys
import numpy as np

VIDEO = sys.argv[1]
START = 300.0
DUR = 120.0
FFMPEG = r"C:\Project\姘稿姭鏃犻棿\.video-tools\LosslessCut\resources\ffmpeg.exe"
PROBE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "bench_probe.py")
PROXY = os.path.join(os.environ["TEMP"], "opencode", "agree_proxy.mp4")
SIG = os.path.join(os.environ["TEMP"], "opencode", "agree_sig.csv")

subprocess.run(
    [FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", str(START), "-t", str(DUR),
     "-i", VIDEO, "-an", "-vf", "fps=20,scale=480:-2", "-c:v", "libx264",
     "-preset", "veryfast", "-crf", "23", "-y", PROXY], check=True)
subprocess.run([sys.executable, PROBE, PROXY, "--seconds", str(DUR), "--out", SIG], check=True)

rows = [r for r in csv.DictReader(open(SIG, encoding="utf-8")) if r.get("flow")]
t = np.array([float(r["t"]) for r in rows])
flow = np.array([float(r["flow_p95"]) for r in rows])
fdiff = np.array([float(r["fdiff"]) for r in rows])

wav = os.path.join(os.environ["TEMP"], "opencode", "agree.wav")
subprocess.run(
    [FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", str(START), "-t", str(DUR),
     "-i", VIDEO, "-vn", "-ac", "1", "-ar", "32000", "-y", wav], check=True)

import librosa
y, sr = librosa.load(wav, sr=32000, mono=True)
env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=1600)  # 10 fps grid
n = min(len(env), len(flow))
env = env[:n]; flow_a = flow[:n]; fdiff_a = fdiff[:n]; t_a = t[:n]

def corr(a, b):
    a = a - a.mean(); b = b - b.mean()
    d = (np.sqrt((a**2).sum()) * np.sqrt((b**2).sum()))
    return float((a*b).sum()/d) if d else 0.0

print(f"grid_points={n} hop_s={32000/3200:.1f}")
print(f"pearson(flow_p95, audio_onset_env) = {corr(flow_a, env):+.3f}")
print(f"pearson(fdiff,     audio_onset_env) = {corr(fdiff_a, env):+.3f}")
print(f"pearson(flow_p95, fdiff)            = {corr(flow_a, fdiff_a):+.3f}")

# regime split: does the top-decile flow window concentrate audio onsets?
thr = np.percentile(flow_a, 90)
hi = flow_a >= thr
print(f"flow_p95 p50={np.percentile(flow_a,50):.2f} p90={thr:.2f} max={flow_a.max():.2f}")
print(f"onset_env mean in TOP10% flow frames = {env[hi].mean():.3f}")
print(f"onset_env mean in rest               = {env[~hi].mean():.3f}")
print(f"ratio = {env[hi].mean()/max(env[~hi].mean(),1e-9):.2f}x")
