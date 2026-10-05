"""Throwaway probe: audio-side zero-view signals available with the CURRENT toolchain (librosa only)."""
import argparse, subprocess, time, json, os
import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("video")
ap.add_argument("--seconds", type=float, default=90.0)
args = ap.parse_args()

import librosa
FFMPEG = r"C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe"

t0 = time.time()
wav = os.path.join(os.environ["TEMP"], "aivideo_probe_audio.wav")
subprocess.run(
    [FFMPEG, "-hide_banner", "-loglevel", "error", "-ss", "300", "-t", str(args.seconds),
     "-i", args.video, "-vn", "-ac", "1", "-ar", "32000", "-y", wav],
    check=True,
)
t_extract = time.time() - t0

t1 = time.time()
y, sr = librosa.load(wav, sr=32000, mono=True)
t_load = time.time() - t1

t2 = time.time()
rms = librosa.feature.rms(y=y)[0]
t_rms = time.time() - t2

t3 = time.time()
onset_env = librosa.onset.onset_strength(y=y, sr=sr)
onsets = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, units="time", backtrack=False)
t_onset = time.time() - t3

t4 = time.time()
zcr = librosa.feature.zero_crossing_rate(y)[0]
centroid = librosa.feature.spectral_centroid(y=y, sr=sr)[0]
t_spec = time.time() - t4

print(json.dumps({
    "extract_s": round(t_extract, 2),
    "librosa_load_s": round(t_load, 2),
    "rms_s": round(t_rms, 2),
    "onset_s": round(t_onset, 2),
    "spectral_s": round(t_spec, 2),
    "total_s": round(time.time() - t0, 2),
    "audio_s": len(y) / sr,
    "n_rms_frames": int(len(rms)),
    "n_onsets": len(onsets),
    "rms_db_p50": round(float(20 * np.log10(np.percentile(rms, 50) + 1e-9)), 2),
    "rms_db_p95": round(float(20 * np.log10(np.percentile(rms, 95) + 1e-9)), 2),
    "rms_db_max": round(float(20 * np.log10(rms.max() + 1e-9)), 2),
    "onset_times_head": [round(float(t), 2) for t in onsets[:12]],
}, ensure_ascii=False, indent=2))