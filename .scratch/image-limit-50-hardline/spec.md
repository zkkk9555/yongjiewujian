---
Status: spec
---

# Spec: image-limit-50-hardline

## Problem

Upstream single-request image cap is 50. Previous rounds documented the cap
(`AGENTS.md §9`, `IMAGE_LIMIT.md`, `docs/WORKFLOW.md`), yet a later round
still submitted 53 images in one turn. Upstream failed and the session could
not continue; work had to move to a new window. Several sessions
(sess_fd6d3012, sess_47c354c9, sess_b3a79071, sess_729a549a) hit this shape.
Text-only restatement of the limit did not prevent the violation.

## Solution

Keep 50 as a model-independent hard redline persisted at the project root,
and change it from a statement into an enforceable pre-flight procedure:
count first (ls/dir), then batch, then read; every round, every model.
Strengthen the root (`AGENTS.md §9` + `IMAGE_LIMIT.md`) with a mandatory
checklist, then sync the workflow copies so no doc contradicts it.

## User-Stories

1. As an agent doing thumbnail review, I count `thumb_*.jpg` with ls/dir
   BEFORE any image Read, so I know whether the set exceeds 50 before I act.
2. As an agent needing >50 frames, I split into multiple rounds and write the
   intermediate verify note first, so no single round ever carries >50.
3. As a returning user, I can open `AGENTS.md §9` or `IMAGE_LIMIT.md` and see
   the same 50-image rule with the same counting scope, so any session
   enforces it identically.

## Implementation Decisions

- Cap stays 50, absolute, model-independent (including
  `muse-spark-1.3-contributor-free` and any future model).
- Counting scope: sum of ALL image-bearing tool uses in one round
  (`Read` images + `get_app_state` screenshots + `screenshot` + `zoom`
  re-reads). Not per-call.
- Mandatory pre-flight: batch image review only after a same-session
  `ls`/`dir` count; the count result decides the split before any Read.
- Normal batch 4–10; contact sheet preferred as one image; FFmpeg
  downsample first (e.g. 1/10fps thumbnails), small补帧 only at boundaries.
- Conflict rule: if any doc disagrees, 50 wins.
- No new skill copy, no user-level skill change, no tool reinstall.

## Testing Decisions

- Seam 1 (parity): grep for `50` across
  `AGENTS.md`, `IMAGE_LIMIT.md`, `docs/WORKFLOW.md`,
  `skills/naraka-highlight-studio/references/complete-combat-roughcut.md`
  returns the cap in each; no file claims a higher/different cap.
- Seam 2 (procedure): `AGENTS.md §9` and `IMAGE_LIMIT.md` both contain the
  three tokens: `ls`/`dir` pre-count, per-round sum, 4–10 batch.
- Seam 3 (failure memory): docs record the 53-image failure as the reason
  for count-first (regression note, not a new rule).
- No code harness in this repo; verification is grep + Read re-check.

## Slices

- [x] Slice 1: root hardline (`AGENTS.md §9` + `IMAGE_LIMIT.md`)
- [x] Slice 2: workflow copies
      (`docs/WORKFLOW.md`, `complete-combat-roughcut.md`,
      `docs/TROUBLESHOOTING.md` failure entry)
- [x] Slice 3: parity verification (grep + Read)

## Out of Scope

- Changing the 50 number itself, per-model exceptions, raising the cap.
- Installing/copying skills, reinstalling video tools, touching footage.
- Rewriting the video workflow beyond the image-limit sections.

## Glossary

- 单轮 (round/turn): one assistant turn including all tool calls before
  the next user-visible message; the counting window.
- 加总 (sum): add image counts across every image tool in the round.
- 事前数数 (count-first): ls/dir the thumbnail set before any image Read.
- 联系表 (contact sheet): multiple thumbnails composited into one image.

## Notes

- Gate 0: HIT on existing text (`AGENTS.md:119-127`, `IMAGE_LIMIT.md:1-24`,
  `WORKFLOW.md:85-91`, `roughcut.md:~130`). Behaviour-parity gap: text
  existed but did not force count-first, so 53 slipped through. This spec
  is the delta (procedure hardening), not a rewrite.
- Freshness-gate: `AGENTS.md` + `docs/agents/` present; conformant, setup
  skipped.
- T0 `ask-matt` routing not available as a separate Skill effect here;
  executed Lane B fallback order per `feature-flow.md` inline and recorded.

## Checks

- Checks: i18n N/A (docs are Chinese-first by repo convention, no new
  locale strings) / save N/A (no save format touched) / red-line Pass
  (50-image cap preserved in every touched file, evidence: grep Seam 1).
