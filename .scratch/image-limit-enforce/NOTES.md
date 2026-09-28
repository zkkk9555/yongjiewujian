# NOTES — image-limit-enforce

Skills called: ask-matt (T0), to-spec (spec synthesis).

## Gate 0

- HIT: `50` present in `AGENTS.md:121`, `IMAGE_LIMIT.md:3`,
  `docs/WORKFLOW.md:87`, `complete-combat-roughcut.md:130`,
  plus `docs/TROUBLESHOOTING.md:109-113` (53-image failure entry).
- MISS (the actual gap): zero hits for `累计|累积|历史|预算`
  in the image-limit sections; no budget/contact-sheet script in
  `scripts/` (only `check_video_environment.ps1`).
- Verdict: HIT (text) + MISS (enforcement) → delta fix, Lane B.

## Self-answered design (grill ≤2 rounds, round 1 of 2)

1. Scope = cumulative or per-round-new? → cumulative (repo: none said
   it; upstream failure shape in sess_03bfff9d proves per-round-new
   is insufficient; smallest reversible doc change, no ADR needed).
2. Per-round-new number? → ≤10 (repo practice "4–10 张/批" already
   says 4–10; locking the top at 10 keeps 5x safety margin under 50;
   numeric change stays inside the existing red-line practice, no
   new red-line value introduced).
3. Enforcement without harness hooks? → mandatory pre-flight script
   (`check_image_budget.ps1`) + contact-sheet script; docs name them
   as required steps (smallest reversible option).
4. Which docs? → all 5 copies fixed (single source of truth = fix
   every copy, per feature-flow rule).
5. Scripts in Chinese or English? → English-only output strings to
   dodge the known PS 5.1 non-BOM Chinese-path garble
   (`docs/TROUBLESHOOTING.md` 832 v2 lesson); docs carry the Chinese.

## Downgrades

- Lane C → Lane B: 2 slices, anchors writable now, no cross-system
  change, single session. No code-review-commit (repo is not a git
  checkout; review recorded here instead).
