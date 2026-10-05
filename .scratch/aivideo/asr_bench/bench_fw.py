"""faster-whisper tier/param benchmark. Zero-image, read-only w.r.t. source material.

usage: python bench_fw.py <audio.wav> <outdir> <label> <model> <compute_type> <beam> <vad 0|1> [hotwords]
Emits <outdir>/<label>.json  {meta, segments}
"""
import json, os, sys, time, platform

MODELS = r"C:\Project\永劫无间\.video-tools\models"

audio, outdir, label, model_name, ctype, beam, vad = sys.argv[1:8]
hotwords = sys.argv[8] if len(sys.argv) > 8 else None
os.makedirs(outdir, exist_ok=True)

from faster_whisper import WhisperModel

t0 = time.time()
model = WhisperModel(model_name, device="cuda", compute_type=ctype, download_root=MODELS)
load_s = time.time() - t0

kw = {}
if hotwords:
    kw["hotwords"] = hotwords

t1 = time.time()
segments, info = model.transcribe(
    audio,
    language="zh",
    beam_size=int(beam),
    vad_filter=bool(int(vad)),
    vad_parameters=dict(min_silence_duration_ms=500, speech_pad_ms=200),
    condition_on_previous_text=False,
    word_timestamps=False,
    **kw,
)
data = []
last = time.time()
for seg in segments:
    data.append({
        "start": round(float(seg.start), 3),
        "end": round(float(seg.end), 3),
        "text": seg.text.strip(),
        "avg_logprob": round(float(seg.avg_logprob), 4),
        "no_speech_prob": round(float(seg.no_speech_prob), 4),
    })
    last = time.time()
dec_s = last - t1
total_s = time.time() - t0

payload = {
    "meta": {
        "label": label, "model": model_name, "compute_type": ctype,
        "beam_size": int(beam), "vad": bool(int(vad)),
        "hotwords": hotwords or "",
        "audio": audio, "audio_duration": round(float(info.duration), 2),
        "model_load_s": round(load_s, 2),
        "decode_wall_s": round(dec_s, 2),
        "total_wall_s": round(total_s, 2),
        "realtime_factor": round(float(info.duration) / dec_s, 2) if dec_s else None,
        "segments": len(data),
        "speech_s": round(sum(d["end"] - d["start"] for d in data), 1),
        "mean_avg_logprob": round(sum(d["avg_logprob"] for d in data) / len(data), 4) if data else None,
        "python": platform.python_version(),
    },
    "segments": data,
}
p = os.path.join(outdir, label + ".json")
with open(p, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=1)
print(json.dumps(payload["meta"], ensure_ascii=False))
