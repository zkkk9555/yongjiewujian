# Time budget: credible roughcut clocks (zero-install baseline)

> Scope: single-machine baseline (RTX 4060 Ti 8GB, no torch, faster-whisper
> small/medium/large-v3 only, NVENC 3-5 sessions, 50-image cumulative cap).
> Clocks below are the review verdict after Phase3/Phase4; the 30-minute
> "order to preview" promise only holds with cache hits.

## 1. Credible clocks

| Situation | Deliverable | Clock |
|---|---|---|
| Cache hit (probe + transcript + scenes + thumbs frozen) | Fast preview for early feedback, not freezable | 30 min |
| Cold start, single 2h match | Fast preview (small transcription sample + recall screening + first timeline) | 60 min |
| Cold start, single 2h match | Reviewable 720p preview (full small/medium transcription + subtitle alignment) | 90-120 min |
| Any | 4K60 VBR master re-rendered from source | Scheduled separately, never inside the preview window |

A fast preview (`快览`) must be labeled non-freezable and non-reviewable.
Only a preview that passes the five freeze gates plus the streak rule may be
sent for user review.

## 2. Global clock fuse

- Fast preview fuse: +10 min over budget degrades scope (drop to Top-N
  candidates), it never silently drops segments.
- Reviewable preview fuse: +30 min over budget degrades to fast preview and
  renames the deliverable; a fast preview must never be served as reviewable.
- Every fuse trip is logged with the version, the dropped scope, and the
  evidence paths that remain.

## 3. Cache-miss early exit

On missing model, exhausted VRAM, or a busy NVENC session: record the gap,
ship the degraded checklist, and stop. No retry loops, no installs, no
network fetches. Re-run only after the user authorizes the missing piece.

Rendering stays serial: analysis may run in parallel shards, but NVENC
encoding holds a single global lock so parallel jobs cannot wedge the driver.

## 4. Recalibration note (2026-09-24)

- 本表时钟本轮不动数字。下轮 849（28 路待派，体量与 848 同级）实测后重校：以 T0/T1 台账时间戳为据，对比 848 基线（扫描波 28 路约 1 小时级收齐 + repair-v1 阻塞 4 轮教训），两次实测才改数字，不拍脑袋。
- 熔断记账字段：每次熔断记版本 + 被降 scope + 剩余证据路径（见 §2）；熔断两次同因即入 `workflow_notes` 待升级项。
