"""Full-length clean sweep, priority order (open questions first).

usage: python full_sweep.py <audio.wav> <outdir>
ASCII-only on purpose; model paths are built from an explicit root arg-free
constant so no non-ASCII literal lives in this file.
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

audio, outdir = sys.argv[1], sys.argv[2]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJ = os.path.dirname(os.path.dirname(os.path.dirname(ROOT)))
# ROOT = <proj>\.scratch\aivideo\asr_bench -> strip 4 levels to reach <proj>
PROJ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CACHE = os.path.join(PROJ, ".video-tools", "models")
TURBO = os.path.join(CACHE, "local", "whisper-large-v3-turbo")
HWFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hotwords.txt")
hotwords = open(HWFILE, encoding="utf-8").read().strip()

CFGS = [
    # label, model, compute_type, beam, vad, hotwords
    ("turbo_fp16_b5_vad", TURBO, "float16", 5, True, ""),
    ("base_largev3_b5_vad_HOT", "large-v3", "float16", 5, True, hotwords),
    ("base_largev3_fp16_b5_vad", "large-v3", "float16", 5, True, ""),
    ("small_fp16_b5_vad", "small", "float16", 5, True, ""),
    ("medium_fp16_b5_vad", "medium", "float16", 5, True, ""),
    ("largev3_int8f16_b5_vad", "large-v3", "int8_float16", 5, True, ""),
    ("largev3_fp16_b1_vad", "large-v3", "float16", 1, True, ""),
    ("largev3_fp16_b5_novad", "large-v3", "float16", 5, False, ""),
    ("tiny_fp16_b5_vad", "tiny", "float16", 5, True, ""),
]

os.makedirs(outdir, exist_ok=True)


def ffmpeg_count():
    try:
        o = subprocess.run(["tasklist", "/FI", "IMAGENAME eq ffmpeg.exe", "/NH"],
                           capture_output=True, text=True, timeout=20).stdout
        return o.lower().count("ffmpeg.exe")
    except Exception:
        return -1


rows = []
for label, path, ctype, beam, vad, hw in CFGS:
    ff0 = ffmpeg_count()
    t0 = time.time()
    model = WhisperModel(path, device="cuda", compute_type=ctype, download_root=CACHE)
    load_s = time.time() - t0
    kw = {"hotwords": hw} if hw else {}
    t1 = time.time()
    segs, info = model.transcribe(
        audio, language="zh", beam_size=beam, vad_filter=vad,
        vad_parameters=dict(min_silence_duration_ms=500, speech_pad_ms=200),
        condition_on_previous_text=False, word_timestamps=False, **kw)
    data = [{"start": round(float(s.start), 3), "end": round(float(s.end), 3),
             "text": s.text.strip(), "avg_logprob": round(float(s.avg_logprob), 4),
             "no_speech_prob": round(float(s.no_speech_prob), 4)} for s in segs]
    dec = time.time() - t1
    tot = time.time() - t0
    dur = float(info.duration)
    ff1 = ffmpeg_count()
    meta = {"label": label, "model": os.path.basename(path), "compute_type": ctype,
            "beam_size": beam, "vad": vad, "hotwords": bool(hw),
            "audio_duration": round(dur, 2), "model_load_s": round(load_s, 2),
            "decode_wall_s": round(dec, 2), "total_wall_s": round(tot, 2),
            "realtime_factor": round(dur / dec, 2), "segments": len(data),
            "speech_s": round(sum(d["end"] - d["start"] for d in data), 1),
            "mean_avg_logprob": round(sum(d["avg_logprob"] for d in data) / len(data), 4) if data else None,
            "ffmpeg_before": ff0, "ffmpeg_after": ff1}
    with open(os.path.join(outdir, label + ".json"), "w", encoding="utf-8") as f:
        json.dump({"meta": meta, "segments": data}, f, ensure_ascii=False, indent=1)
    rows.append(meta)
    print("%-26s load=%6.2fs dec=%7.2fs tot=%7.2fs rf=%7.2fx segs=%4d logp=%7.4f ffmpeg=%d/%d"
          % (label, load_s, dec, tot, meta["realtime_factor"], len(data),
             meta["mean_avg_logprob"], ff0, ff1), flush=True)
    del model

with open(os.path.join(outdir, "full_sweep.json"), "w", encoding="utf-8") as f:
    json.dump(rows, f, ensure_ascii=False, indent=1)
print("\nDONE", len(rows), "configs")