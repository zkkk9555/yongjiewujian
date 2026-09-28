---
Status: spec
---

# Spec: image-limit-enforce

## Problem Statement

项目文档已经在 4 处写明了单次 50 张图片红线
（`AGENTS.md §9`、`IMAGE_LIMIT.md`、`docs/WORKFLOW.md`、
`complete-combat-roughcut.md`），但 `sess_03bfff9d` 仍然超限、
会话作废。复盘发现：超限不是一批发了 53 个 `Read`，
而是每批只看 5 张、连续多批在同一次上游请求里累加爆掉的。
文档只约束“本轮新增”，上游按“本次请求携带总量”（含历史已看图）结算，
口径错位 + 无强制预算手段 = 文字规则拦不住。

## Solution

50 张数字不变（上游硬性限制，与模型无关），把口径从
“本轮新增 ≤50” 改成“累计口径 + 每轮新增预算”，并配两把工具：
`scripts/check_image_budget.ps1`（看图前强制做分批预算）、
`scripts/make_contact_sheet.ps1`（多图拼一张，只算 1 张）。
5 处文档同步到同一口径，任何冲突以 50 为准。

## User Stories

1. As a video-review agent, I want the rule to state the cumulative
   counting scope (history + new in one upstream request), so that
   I stop believing "5 new images this round is always safe".
2. As a video-review agent, I want a mandatory per-round NEW budget
   (≤10 images), so that accumulated history can never push a round
   over 50.
3. As a video-review agent, I want a budget script I must run before
   reading images, so that the split plan exists before any Read,
   not after the failure.
4. As a video-review agent, I want a contact-sheet script, so that
   reviewing >10 frames costs 1 image instead of N.
5. As a video-review agent, I want every round to close with a verify
   note before opening the next, so that cross-round history is
   written down and later rounds shrink their budget accordingly.
6. As a returning user, I want all 5 docs to carry the same rule,
   so that any session enforces it identically.
7. As a returning user, I want the `sess_03bfff9d` cumulative-overload
   lesson recorded in the docs, so that future sessions do not repeat
   the "small batches are safe" mistake.

## Implementation Decisions

- Cap stays 50, absolute, model-independent (red-line: numeric
  self-answers checked against anchors first; 50 is locked, no ADR
  needed to keep it).
- New counting scope: upstream settles on ALL images carried in one
  request, including images seen in earlier rounds. Docs state this
  explicitly ("累计口径").
- Per-round NEW image budget: ≤10 (`Read` new images; whole-round
  image-tool sum still ≤50). Rationale: 50 / 5 rounds of safe margin;
  matches the existing "常规每批 4–10 张" practice, now mandatory.
- Mandatory pre-flight: `ls`/`dir` count (write the number down) +
  `check_image_budget.ps1` split plan, before any image Read.
- Contact-sheet-first when >10 frames are needed; boundary补帧 only.
- Anchors (`path :: symbol`, one line each, required):
  - `AGENTS.md :: §9 单次图片上限`
  - `IMAGE_LIMIT.md :: 强制执行顺序`
  - `docs/WORKFLOW.md :: 看图限流`
  - `skills/naraka-highlight-studio/references/complete-combat-roughcut.md :: 看图限流`
  - `docs/TROUBLESHOOTING.md :: 单轮一次提交超过 50 张图片导致会话作废`
  - `scripts/check_image_budget.ps1 :: Show-ImageBudgetPlan (new)`
  - `scripts/make_contact_sheet.ps1 :: New-ContactSheet (new)`
- No harness interception (not possible from docs), no skill copies,
  no tool reinstall, no footage changes.

## Testing Decisions

- Seam 1 (parity, grep-level): every one of the 5 docs contains `50`
  with the cumulative scope tokens (`累计`, `单轮新增`, `≤10`);
  no doc claims a higher/different cap (numbers → red-line range check).
- Seam 2 (procedure): `AGENTS.md §9` + `IMAGE_LIMIT.md` contain the
  three tokens: `check_image_budget.ps1`, `make_contact_sheet.ps1`,
  per-round-new ≤10.
- Seam 3 (scripts): `check_image_budget.ps1` dry-runs read-only on a
  real shots dir and prints a round plan; `make_contact_sheet.ps1`
  builds one contact sheet from sample thumbs with ffmpeg (or records
  BLOCKED if ffmpeg is unreachable in the sandbox).
- No new test framework (STOP-list: adopting one needs human); scripts
  are plain `.ps1` like the existing `check_video_environment.ps1`.
- Good test = external behaviour (plan output / contact jpg exists),
  not implementation detail.

## Out of Scope

- Changing the 50 number, per-model exceptions, raising the cap.
- Harness-level hard interception of tool calls (outside repo control).
- Installing/copying skills, reinstalling video tools, touching footage.
- Rewriting the video workflow beyond the image-limit sections.

## Glossary

- 累计口径 (cumulative scope): upstream counts every image carried in
  one request, including images already seen in earlier rounds.
- 单轮新增 (per-round new): images first read in the current round;
  budget ≤10.
- 预算脚本 (budget script): `check_image_budget.ps1`, prints the
  round-split plan before any Read.
- 联系表 (contact sheet): N thumbnails composited into 1 image.

## Notes

- Gate 0 verdict: HIT (50-text in 4 docs) + MISS (cumulative scope,
  enforced budget, contact-sheet tooling) → delta fix only, no rewrite.
- Lane B, 2 slices embedded below (no separate ticket files).

## Checks

- i18n: N/A (Chinese-language project docs, no locale strings).
- save-compat: N/A (no save format touched).
- red-line: Pass — 50 unchanged in all 5 docs (evidence: Seam 1 grep).

## Slices

- [ ] Slice 1: doc sync — same cumulative rule in all 5 docs
      (data + trigger + verify = grep parity closed loop).
- [ ] Slice 2: scripts — budget + contact-sheet `.ps1`, dry-run green.
