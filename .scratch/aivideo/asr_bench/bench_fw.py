"""Single faster-whisper measurement. Self-documents CPU contention.

usage: python bench_fw.py <audio.wav> <outdir> <label> <model> <compute_type> <beam> <vad 0|1> [hotwords_file]

ASCII-only on purpose: non-ASCII payloads (e.g. a Chinese hotword list) belong
in a UTF-8 .txt file passed as the 8th argument, never as a literal in a .ps1.
PYTHON SOURCE IS UTF-8 BY DEFAULT, so literals here are fine -- the encoding
trap in this project is PowerShell 5.1 reading .ps1 files without a BOM.
"""
import json
import os
import platform
import subprocess
import sys
import time


def _ffmpeg_count():
    """Contention marker. Sibling sessions render with ffmpeg and starve the
    CPU-side stages of faster-whisper (silero-vad ONNX + audio decode),
    inflating wall clock by up to ~30x on this box."""
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq ffmpeg.exe", "/NH"],
                             capture_output=True, text=True, timeout=20).stdout
        return out.lower().count("ffmpeg.exe")
    except Exception:
        return -1


audio, outdir, label, model_name, ctype, beam, vad = sys.argv[1:8]
hotwords = sys.argv[8] if len(sys.argv) > 8 else None
if hotwords and os.path.isfile(hotwords):
    with open(hotwords, "r", encoding="utf-8") as fh:
        hotwords = fh.read().strip()
os.makedirs(outdir, exist_ok=True)

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
MODELS = os.path.join(PROJ, ".video-tools", "models")

from faster_whisper import WhisperModel

t0 = time.time()
model = WhisperModel(model_name, device="cuda", compute_type=ctype, download_root=MODELS)
load_s = time.time() - t0

kw = {"hotwords": hotwords} if hotwords else {}
t1 = time.time()
segments, info = model.transcribe(
    audio, language="zh", beam_size=int(beam), vad_filter=bool(int(vad)),
    vad_parameters=dict(min_silence_duration_ms=500, speech_pad_ms=200),
    condition_on_previous_text=False, word_timestamps=False, **kw)

data = []
last = time.time()
for seg in segments:            # LAZY generator: all decoding happens here
    data.append({"start": round(float(seg.start), 3), "end": round(float(seg.end), 3),
                 "text": seg.text.strip(), "avg_logprob": round(float(seg.avg_logprob), 4),
                 "no_speech_prob": round(float(seg.no_speech_prob), 4)})
    last = time.time()
dec_s = last - t1               # clock stopped AFTER the generator is consumed
total_s = time.time() - t0
dur = float(info.duration)

payload = {"meta": {"label": label, "model": model_name, "compute_type": ctype,
                    "beam_size": int(beam), "vad": bool(int(vad)), "hotwords": hotwords or "",
                    "audio": audio, "audio_duration": round(dur, 2),
                    "model_load_s": round(load_s, 2), "decode_wall_s": round(dec_s, 2),
                    "total_wall_s": round(total_s, 2),
                    "realtime_factor": round(dur / dec_s, 2) if dec_s else None,
                    "segments": len(data),
                    "speech_s": round(sum(d["end"] - d["start"] for d in data), 1),
                    "mean_avg_logprob": round(sum(d["avg_logprob"] for d in data) / len(data), 4) if data else None,
                    "python": platform.python_version(),
                    "ffmpeg_procs_during_run": _ffmpeg_count()},
           "segments": data}
with open(os.path.join(outdir, label + ".json"), "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=1)
print(json.dumps(payload["meta"], ensure_ascii=False))