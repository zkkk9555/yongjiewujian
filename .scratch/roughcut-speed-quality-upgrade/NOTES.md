# NOTES — roughcut-speed-quality-upgrade

Skills called: ask-matt, to-spec(implicit), to-tickets(implicit), implement, tdd(smoke), code-review(fast-lane)

## 2026-09-11 build evidence

- env: `scripts/check_video_environment.ps1` all PASS (FFmpeg/FFprobe link+target, venv, large-v3 cache, LosslessCut). Canonical python execution WARN is the known sandbox limit; direct venv execution works (`py-ok`, package versions printed).
- baseline packages: faster-whisper 1.2.1 / scenedetect 0.7.1 / auto-editor 29.3.1 / ctranslate2 4.8.1 / librosa 0.11.0 / otio 0.18.1; torch/funasr/ultralytics/transformers/PIL absent; models only tiny/small/medium/large-v3. Zero-install constraint honored: no pip, no model download.
- 01 qa_gate.py: `--help` PASS; fixture `tests/fixtures/combat_episodes.json` PASS (fail=0); crafted overlap+over-duration case FAIL=2 (timeline_mutex + source_range). Stdlib only.
- 02 manifest hash: `fp_same: True`, `id_same: True` across copy/rename; manifest e2e `sources=1 errors=0`, new `content_fingerprint` field present, old fields kept.
- 03 time-budget.md: new file with credible clocks + fuse + early-exit; indexed from SKILL.md and roughcut-launch.md §4.
- 04 multiagent contract: roughcut-launch.md §2.6 single-writer + 1+2~3 + token discipline, terms aligned with e4/d1.
- 05 subtitle/map gates: validate_delivery old args still work; new SRT checks on crafted file: sha recorded, stats 2==2 PASS, zero-cross-cut PASS (overall FAIL only because master/preview paths are intentionally missing in the smoke test). validate_combat_timeline fixture still pass with new proxy/program-sum checks.
- task dirs untouched: `123/` mtimes all 2026-09-09 or earlier except pre-existing workflow_upgrade; no source media touched.

## Code-review (fast lane: Standards + Spec)

- Standards: no new dependency, no per-task venv, absolute paths in prompts untouched, image-budget rules untouched, AGENTS.md untouched (only skill-internal docs changed). `validate_delivery.py` keeps old CLI compatible (new args optional). `stable_id` keeps sha1-16 shape; only the payload changed from path-keyed to content-keyed, plus an additive fingerprint field.
- Spec: 5/5 tickets map to spec slices 1-5; acceptance boxes all checked; verify commands above are the red-green evidence (fail case red, fixture green).
- Smell (record only): `qa_gate.py` media-content gates (black/freeze/silence/ebur128/splice) are evidence-presence WARNs, not decoders — full filter passes remain in render/self-audit reports by design to avoid double-decoding in the gate.
