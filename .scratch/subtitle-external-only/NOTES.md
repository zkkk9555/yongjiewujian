# NOTES — subtitle-external-only

Skills called: to-spec(implicit), to-tickets(implicit), implement, tdd(smoke), code-review(fast-lane)

## 2026-09-11 build evidence

- docs: AGENTS §5 rewritten to 全外挂禁烧录禁内嵌; WORKFLOW §5 preview keeps only 无字幕版/外挂字幕版, §6-§7 no-burn; TROUBLESHOOTING double-subtitle section reframed as history; PROMPT_TEMPLATES preview line bans burn; deliverables-and-qa freeze pack + §4K rule + Source gate + cleanup jig all external-only; roughcut-launch 字幕员 row + C-door require zero subtitle streams.
- gates: `qa_gate.py` burn flag now FAILs (`no_burned_variant`); new `no_subtitle_stream` gate checks ffprobe subtitle count == 0 on preview and master; `validate_delivery.py --burned-subtitles` kept as compat flag but FAILs.
- verify: fixture qa PASS fail=0; same fixture + `--burned-subtitles` FAIL fail=1; delivery + `--burned-subtitles` FAIL without crash; py_compile both scripts OK.
- grep: remaining 烧录 mentions are bans/history only, no legal burn path.
- task dirs: `123/` has new entries from other parallel work (11.844/12.845/12.846 etc.); this task wrote no task dir, touched no source media, installed nothing.

## Code-review (fast lane: Standards + Spec)

- Standards: no new dependency; old `--burned-subtitles` CLI kept (compat, fails closed); ffprobe parsing is text-only with WARN fallback when absent; docs use 禁烧录禁内嵌 consistently.
- Spec: 3/3 tickets map to spec slices; boxes checked.
- Smell (record only): `no_subtitle_stream` cannot catch pixels already burned into video frames — that case is covered by the process ban (never render with subtitles filter) plus adversarial preview watch, not by stream probe.
