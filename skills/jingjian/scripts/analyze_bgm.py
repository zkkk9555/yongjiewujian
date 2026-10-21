from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import librosa
import numpy as np


def scalar(value: object) -> float:
    array = np.asarray(value).reshape(-1)
    return float(array[0]) if array.size else 0.0


def normalize(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=float)
    if values.size == 0:
        return values
    low = float(np.min(values))
    high = float(np.max(values))
    if high - low < 1e-9:
        return np.zeros_like(values)
    return (values - low) / (high - low)


def make_sections(y: np.ndarray, sr: int, bpm: float, duration: float) -> list[dict]:
    hop_length = 512
    rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=hop_length)[0]
    rms_times = librosa.frames_to_time(np.arange(len(rms)), sr=sr, hop_length=hop_length)
    beat_seconds = max(60.0 / bpm, 0.25) if bpm > 0 else 0.5
    section_seconds = beat_seconds * 32.0
    section_seconds = min(max(section_seconds, 8.0), 30.0)
    sections: list[dict] = []
    starts = np.arange(0.0, max(duration, 0.001), section_seconds)
    energies: list[float] = []
    for start in starts:
        end = min(float(start + section_seconds), duration)
        mask = (rms_times >= start) & (rms_times < end)
        energies.append(float(np.mean(rms[mask])) if np.any(mask) else 0.0)
    normalized = normalize(np.asarray(energies, dtype=float))
    for index, start in enumerate(starts):
        end = min(float(start + section_seconds), duration)
        energy = float(normalized[index]) if index < len(normalized) else 0.0
        previous = float(normalized[index - 1]) if index else energy
        delta = energy - previous
        if start < duration * 0.12:
            label = "intro"
        elif start >= duration * 0.84:
            label = "outro"
        elif energy >= 0.72:
            label = "drop"
        elif delta >= 0.16:
            label = "build"
        else:
            label = "body"
        sections.append(
            {
                "start": round(float(start), 3),
                "end": round(end, 3),
                "label": label,
                "energy": round(energy, 4),
                "energy_delta": round(delta, 4),
            }
        )
    return sections


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze BPM, beats, onsets, and energy sections for a BGM track.")
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--sample-rate", type=int, default=22050)
    parser.add_argument("--start-bpm", type=float, default=120.0)
    args = parser.parse_args()

    y, sr = librosa.load(str(args.input), sr=args.sample_rate, mono=True)
    duration = float(len(y) / sr) if sr else 0.0
    onset_env = librosa.onset.onset_strength(y=y, sr=sr)
    tempo, beat_frames = librosa.beat.beat_track(
        onset_envelope=onset_env,
        sr=sr,
        start_bpm=args.start_bpm,
        units="frames",
        trim=False,
    )
    bpm = scalar(tempo)
    beat_frames = np.asarray(beat_frames, dtype=int)
    beat_times = librosa.frames_to_time(beat_frames, sr=sr)
    onset_frames = librosa.onset.onset_detect(
        onset_envelope=onset_env,
        sr=sr,
        backtrack=True,
        units="frames",
    )
    onset_times = librosa.frames_to_time(onset_frames, sr=sr)
    beat_strength = normalize(onset_env[np.clip(beat_frames, 0, max(len(onset_env) - 1, 0))]) if len(onset_env) else []

    beats = []
    for index, time in enumerate(beat_times):
        beats.append(
            {
                "index": index,
                "time": round(float(time), 4),
                "bar": index // 4,
                "beat_in_bar": index % 4,
                "strong": bool(index % 4 == 0 or (index < len(beat_strength) and beat_strength[index] >= 0.8)),
                "strength": round(float(beat_strength[index]), 4) if index < len(beat_strength) else None,
            }
        )

    result = {
        "schema": "naraka-highlight-beatmap/v1",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "input": str(args.input.resolve()),
        "sample_rate": sr,
        "duration": round(duration, 4),
        "bpm": round(bpm, 4),
        "bpm_source": "librosa.beat.beat_track",
        "beats": beats,
        "onsets": [round(float(value), 4) for value in onset_times if value <= duration],
        "sections": make_sections(y, sr, bpm, duration),
        "manual_corrections": [],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"bpm": result["bpm"], "beats": len(beats), "onsets": len(result["onsets"]), "output": str(args.output)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
