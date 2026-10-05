---
name: naraka-highlight-studio
description: "Create high-quality Naraka: Bladepoint gameplay videos from local match recordings. Includes a complete-combat roughcut mode that preserves each fight from engagement through outcome while removing loot, travel, waiting, repetition, and long no-event sections; also supports optional BGM, captions, effects, audio mixing, and final delivery. Use for Naraka montage or combat-roughcut production; keep general-purpose video edits on the project’s base video skills."
metadata:
  short-description: "批量制作《永劫无间》高燃成片"
---

# Naraka Highlight Studio

## Outcome

The user wants the finished video, not a tutorial. Handle analysis, music planning, event selection, effects, audio mix, rendering, and verification internally. Report only the useful result paths and a short quality summary unless the user asks for intermediate artifacts.

When the user asks for a “完整战斗粗剪”, “高质量粗剪”, “保留整场战斗”, or says that previous cuts ended before a fight was over, select `complete_combat_roughcut`. In this mode, the unit of selection is a complete combat episode, not an isolated hit, kill, scene change, or audio peak. Read [references/complete-combat-roughcut.md](references/complete-combat-roughcut.md) before building the source timeline.

Use the project’s shared tools and output convention:

```text
Tools:  C:\Project\永劫无间\.video-tools\venv
Output: C:\Project\永劫无间\123\<编号>.<素材文件名>
Source: E:\OBS or E:\PR导出, read-only
```

Never create a per-task virtual environment or reinstall an existing project tool. Run the project environment check before processing.

This project-local folder is the only canonical copy of the skill. Do not install or copy another `naraka-highlight-studio` into the user-level skills directory. Since 2026-10-05 it is advertised normally: the project's `opencode.json` sets `"skills": ["./skills"]`, because OpenCode's project discovery paths are `.opencode/skills`, `.claude/skills` and `.agents/skills` — a bare `skills/` at the project root is **not** one of them. If this skill ever stops appearing in the available-skills list, check that `opencode.json` is still in the project root before falling back to reading it by path.

## Modes

Infer a mode from the user’s brief, with `high_energy` as the default:

- `high_energy`: optional-BGM montage, parry/counter/kill/clutch/team-save emphasis.
- `complete_combat_roughcut`: complete fight-to-outcome selection; remove looting, travel, waiting, repetition, and long no-event stretches. Default to no BGM, no dialogue subtitles, and no decorative effects during the review pass.
- `cinematic`: longer context, restrained cuts, dramatic builds and releases.
- `team_save`: preserve the full rescue or peel story, including setup and outcome.
- `teaching`: dialogue captions and explanatory markers enabled.
- `comedy`: preserve useful voice moments and use lighter timing effects.

Read only the relevant supporting references:

- Batch ingestion and caching: [references/batch-workflow.md](references/batch-workflow.md)
- Credible time budget (fast vs reviewable preview, fuse, early exit): [references/time-budget.md](references/time-budget.md)
- Current-task music and beat mapping: [references/bgm-policy.md](references/bgm-policy.md)
- Events, effects, text, and sound design: [references/event-effect-recipes.md](references/event-effect-recipes.md)
- Complete-combat boundaries and roughcut QA: [references/complete-combat-roughcut.md](references/complete-combat-roughcut.md)
- Roughcut launch rules (say "粗剪" auto-applies): [references/roughcut-launch.md](references/roughcut-launch.md)
- Deliverables and quality gates: [references/deliverables-and-qa.md](references/deliverables-and-qa.md)

Use the bundled helpers for repeatable mechanics:

- `scripts/build_batch_manifest.py` — deduplicated input manifest;
- `scripts/analyze_bgm.py` — BPM, beat, onset, and energy map;
- `scripts/map_events_to_beats.py` — event-pack placement on the beat map;
- `scripts/export_edit_timeline.py` — OTIO, Premiere XML, and marker CSV;
- `scripts/validate_combat_timeline.py` — complete-combat boundary, ordering, overlap, and deletion-audit checks;
- `scripts/validate_delivery.py` — delivery smoke checks.
- `scripts/qa_gate.py` — every delivery gate in one entry (any FAIL blocks freezing).

These helpers do not replace visual review or event judgment; they make the same decisions reproducible and make later one-shot revisions cheap.

## Required workflow

1. Inspect the environment, enumerate all supplied files or folders, deduplicate inputs, and create one numbered task directory.
2. Build a batch manifest. Treat each match as a source unit, but rank highlights across the entire batch so one weak match does not consume the episode.
3. Use BGM only when a local or user-supplied audio file is available. The project currently does not call the Douyin ranking API or attempt platform-audio acquisition. If BGM is absent, keep the original game/voice mix and continue with event-driven pacing.
4. Analyze video, audio activity, optional human speech, HUD/kill-feed cues, and visual change. Combine signals into event candidates; never treat one detector as proof of a parry, kill, or team save.
5. In `complete_combat_roughcut`, group candidates into complete combat episodes, extend both boundaries by inspecting the surrounding footage, merge short tactical pauses that belong to the same fight, and reject any boundary that occurs while the fight is still active. In other modes, convert candidates into event packs with lead-in, key action, result, and necessary recovery.
6. Build a beat-aware program timeline. Bind event markers to musical sections and accents, not mechanically to every beat.
7. Apply semantic effect recipes. Keep gameplay readable; use slow motion, freeze, flash, zoom, shake, text, and SFX only where the event earns them.
8. Keep dialogue subtitles off for pure gameplay by default. Use a separate impact-text layer for selected parries, kills, ultimates, and clutch moments.
9. Render a review preview, run quality gates, and correct the source timeline before producing the final master.
10. Preserve a rebuildable internal timeline, stems, markers, cache, and style feedback even when the user only receives the final MP4.
11. **A 4K master lives in exactly one place: `E:\Cujian导出\<source filename> cujian.mp4`.** Render straight to the delivery folder, never into the task's `deliverables\`. The task directory holds regenerable working files and text evidence only; it must not keep a long-term copy of the master. Then verify that E-drive file with `verify_master.sh` and run the post-master cleanup. This is a standing step of the delivery chain, not an extra thing to ask about: the user saying "output the 4K master" authorises the whole chain, ending with the cleanup.

    ```powershell
    & 'C:\Project\永劫无间\scripts\cleanup_after_master.ps1' -TaskDir 'C:\Project\永劫无间\123\<编号>.<素材文件名>'
    ```

    **Delivery gate first:** it refuses to delete anything unless it finds a non-empty `<material>*.mp4` in the delivery folder. No master delivered means `[BLOCKED]` and zero bytes touched — losing a master costs far more than keeping a few GB.

    Once the gate passes it deletes only regenerable weight — `preview\`, `cache\`, `shots\`, `audio\` — plus any leftover master copy in `deliverables\` (the `.mp4` files only; the directory stays), and keeps the task directory itself, `timeline\`, `reports\`, `analysis\`, `captions\`, and every root-level file. On task 849 that is 3.38 GB out of 3.39 GB reclaimed while the ~10 MB of "why each cut landed there" evidence survives. See `references/deliverables-and-qa.md` → Master ownership and Post-master cleanup.

For `complete_combat_roughcut`, the review preview is the primary deliverable of the first pass. It must be checked for three things before any 4K export: every selected fight is complete, non-combat material is removed, and the transition to the next fight occurs only after a clear outcome and short recovery.

## BGM rule

Dynamic Douyin BGM discovery and acquisition are deferred for this project. Do not register an API application, request ranking permissions, scrape music pages, or download an untracked platform copy during an ordinary editing task.

If the user supplies a local MP3/WAV/M4A file, or selects one already registered in `assets\bgm`, analyze it with the bundled beat-map helper and use the actual file in the final mix. If no audio file is supplied, produce the montage without BGM rather than creating a platform-native cue that requires a second manual editing step.

## Revision rule

User feedback is evidence about the style profile. Translate feedback such as “keep more setup,” “less flash,” “BGM lower under voice,” or “more aggressive at the drop” into versioned profile changes. Do not overwrite the original profile or force a new global rule from a single exceptional clip.

## Delivery rule

Default delivery is a finished horizontal 4K60 VBR master plus a review preview. In `complete_combat_roughcut`, produce the review preview first and wait for the user's selection/continuity feedback before rendering the 4K60 master. The project may also contain editable timeline exports, stems, markers, and effect recipes for fast internal revisions. Final rendering always starts from source media or cached source-quality shots, never from a low-resolution preview.

Masters are always clean: no burned-in text, no embedded subtitle stream, and the render script has no burn option to enable. Subtitles ship as a sidecar SRT. After the master passes verification, the post-master cleanup step runs automatically — see Required workflow step 11.

## Environment rule

Prefer, in this order: what the project already ships (`.video-tools\`, `scripts\`, `skills\`), then a normal system installation. **Never depend on a temporary, cache, or tool-runtime directory** — one venv here was built on an interpreter under `~\.cache\` and was destroyed by ordinary system cleanup, taking the subtitle toolchain with it. A venv built on a system interpreter survives; one built on a cache does not.

Resolve tool paths at run time from `scripts\resolve_ffmpeg.ps1` and from `scripts\check_video_environment.ps1`, never from a hardcoded path.
