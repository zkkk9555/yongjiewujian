"""A/B interleaved benchmark: alternates models inside ONE process so every
candidate sees the same machine conditions, then reports min/median wall clock.

Contention on this box is chronic (other sessions run ffmpeg renders), so an
absolute wall clock is only trustworthy as a MIN over interleaved rounds.

usage: python ab_bench.py <audio.wav> <outdir> <rounds> [hotwords_file]
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
hotwords_file = sys.argv[4] if len(sys.argv) > 4 else ""
hotwords = ""
if hotwords_file and os.path.isfile(hotwords_file):
    hotwords = open(hotwords_file, encoding="utf-8").read().strip()

ROOT = r"C:\Project\永劫无间"
TURBO = os.path.join(ROOT, ".video-tools", "models", "local", "whisper-large-v3-turbo")

# label, model-path-or-name, beam, hotwords
CFGS = [
    ("largev3_b5", "large-v3", 5, ""),
    ("turbo_b5", TURBO, 5, ""),
    ("small_b5", "small", 5, ""),
    ("turbo_b1", TURBO, 1, ""),
    ("largev3_b5_HOT", "large-v3", 5, hotwords),
]

os.makedirs(outdir, exist_ok=True)


def ffmpeg_count():
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq ffmpeg.exe", "/NH"],
                             capture_output=True, text=True, timeout=20).stdout
        return out.lower().count("ffmpeg.exe")
    except Exception:
        return -1


def run(model, beam, hw):
    kw = {"hotwords": hw} if hw else {}
    t0 = time.time()
    segs, info = model.transcribe(
        audio, language="zh", beam_size=beam, vad_filter=True,
        vad_parameters=dict(min_silence_duration_ms=500, speech_pad_ms=200),
        condition_on_previous_text=False, word_timestamps=False, **kw)
    data = [{"start": round(float(s.start), 3), "end": round(float(s.end), 3),
             "text": s.text.strip(), "avg_logprob": round(float(s.avg_logprob), 4),
             "no_speech_prob": round(float(s.no_speech_prob), 4)} for s in segs]
    return time.time() - t0, data, float(info.duration)


# load each model once, keep resident: isolates decode cost from load cost
models = {}
for label, path, beam, hw in CFGS:
    t0 = time.time()
    models[label] = WhisperModel(path, device="cuda", compute_type="float16",
                                 download_root=os.path.join(ROOT, ".video-tools", "models"))
    print("loaded %-14s in %6.1fs  (ffmpeg=%d)" % (label, time.time() - t0, ffmpeg_count()), flush=True)

results = {label: {"load_s": None, "runs": []} for label, _, _, _ in CFGS}
dur = None
for r in range(1, rounds + 1):
    for label, path, beam, hw in CFGS:
        model = models[label]
        el, data, dur = run(model, beam, hw)
        results[label]["runs"].append({"round": r, "decode_wall_s": round(el, 2),
                                       "ffmpeg": ffmpeg_count(), "segs": len(data)})
        # keep the fastest run's transcript as the representative output
        fastest = min(x["decode_wall_s"] for x in results[label]["runs"])
        if el <= fastest * 1.001:
            with open(os.path.join(outdir, label + ".json"), "w", encoding="utf-8") as f:
                json.dump({"meta": {"label": label, "model": path, "beam_size": beam,
                                    "audio_duration": round(dur, 2),
                                    "decode_wall_s": round(el, 2), "realtime_factor": round(dur / el, 2),
                                    "segments": len(data), "hotwords": bool(hw),
                                    "ffmpeg_procs": ffmpeg_count()},
                           "segments": data}, f, ensure_ascii=False, indent=1)
        print("  r%d %-14s decode=%7.2fs rf=%6.2fx segs=%3d ffmpeg=%d"
              % (r, label, el, dur / el, len(data), results[label]["runs"][-1]["ffmpeg"]), flush=True)

print("\n=== min / median decode wall clock (seconds), %d rounds, audio=%.1fs ==="
      % (rounds, dur))
summary = {}
for label, _, _, _ in CFGS:
    v = sorted(x["decode_wall_s"] for x in results[label]["runs"])
    summary[label] = {"min": v[0], "median": statistics.median(v), "all": v}
    print("%-14s min=%7.2f  median=%7.2f  all=%s" % (label, v[0], statistics.median(v),
                                                      [round(x, 1) for x in v]))
with open(os.path.join(outdir, "ab_summary.json"), "w", encoding="utf-8") as f:
    json.dump({"audio_duration": dur, "rounds": rounds, "summary": summary,
               "raw": results}, f, ensure_ascii=False, indent=1)