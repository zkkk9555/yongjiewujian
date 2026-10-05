"""Tight interleaved timing, 3 models, N rounds, one process, models loaded once.

usage: python ab_timing.py <audio.wav> <outdir> <rounds>
"""
import io
import json
import os
import statistics
import subprocess
import sys
import time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
from faster_whisper import WhisperModel

audio, outdir, rounds = sys.argv[1], sys.argv[2], int(sys.argv[3])
PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
CACHE = os.path.join(PROJ, ".video-tools", "models")
TURBO = os.path.join(CACHE, "local", "whisper-large-v3-turbo")

CFGS = [("largev3_fp16_b5", "large-v3", 5), ("turbo_fp16_b5", TURBO, 5),
        ("largev3_fp16_b1", "large-v3", 1)]


def ff():
    try:
        return subprocess.run(["tasklist", "/FI", "IMAGENAME eq ffmpeg.exe", "/NH"],
                              capture_output=True, text=True, timeout=20).stdout.lower().count("ffmpeg.exe")
    except Exception:
        return -1


models, loads = {}, {}
for lab, path, beam in CFGS:
    t0 = time.time()
    models[lab] = WhisperModel(path, device="cuda", compute_type="float16", download_root=CACHE)
    loads[lab] = round(time.time() - t0, 2)
    print("load %-16s %6.2fs (ffmpeg=%d)" % (lab, loads[lab], ff()), flush=True)

res = {l: [] for l, _, _ in CFGS}
dur = 0.0
for r in range(rounds):
    for lab, path, beam in CFGS:
        m = models[lab]
        t = time.time()
        segs, info = m.transcribe(audio, language="zh", beam_size=beam, vad_filter=True,
                                  vad_parameters=dict(min_silence_duration_ms=500, speech_pad_ms=200),
                                  condition_on_previous_text=False, word_timestamps=False)
        # faster-whisper returns a LAZY generator: all decoding happens on
        # iteration. Consume it fully BEFORE stopping the clock, or you measure
        # only VAD + feature extraction.
        n = 0
        for _ in segs:
            n += 1
        el = time.time() - t
        dur = float(info.duration)
        res[lab].append({"round": r, "decode_wall_s": round(el, 2), "ffmpeg": ff(),
                         "segs": n})
        print("  r%d %-16s dec=%7.2fs rf=%6.2fx ffmpeg=%d" % (r, lab, el, dur / el, ff()), flush=True)

print("\n=== decode wall clock, %d rounds, audio=%.2fs ===" % (rounds, dur))
out = {}
for lab in res:
    v = sorted(x["decode_wall_s"] for x in res[lab])
    out[lab] = {"load_s": loads[lab], "min": v[0], "median": round(statistics.median(v), 2),
                "rf_min": round(dur / v[0], 2), "runs": v}
    print("%-16s load=%6.2fs  dec min=%7.2fs median=%7.2fs  rf(min)=%6.2fx  runs=%s"
          % (lab, loads[lab], v[0], statistics.median(v), dur / v[0], [round(x, 1) for x in v]))
os.makedirs(outdir, exist_ok=True)
with open(os.path.join(outdir, "ab_timing.json"), "w", encoding="utf-8") as f:
    json.dump({"audio_duration": dur, "rounds": rounds, "result": out, "raw": res},
              f, ensure_ascii=False, indent=1)