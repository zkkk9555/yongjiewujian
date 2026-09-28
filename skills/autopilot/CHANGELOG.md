# CHANGELOG — mattpocock-skills driver 注记（v10–v40 原样搬运）

> 本文件收录 driver v10–v40 版本注记，与瘦身前 SKILL.md 第 27–367 行逐字一致（仅加本文件头）。SKILL 主体只留触发表与接续规则，历史注记以此处为准。
>
> **版本号对照（V2.008 起单一版本号 V2.00N，历史 vNN 仅存于档案）**：v41=V2.001（基线导入）、v43=V2.002、v44=V2.003、v45=V2.004、v46=V2.005、v47=V2.006、v48=V2.007、v49=V2.008。V2.009 起新条目一律只用 V2.00N。

**v10 — `disable-model-invocation` fallback (R1 pressure-test finding).**
`ask-matt` and `triage` declare `disable-model-invocation: true`, but the
Skill tool still dispatches them (verified R1: both returned full content).
The driver therefore treats the flag as routing advice, not a hard block:
call via the Skill tool normally; if a future runtime refuses, fall back to
executing the skill's documented steps inline (router table / triage
Invocation section) and note the substitution in the trace — same rule as
the missing-skill fallback above.

**v11 — prosaic-skill manual execution (R2–R3 pressure-test finding).**
`to-spec`, `to-tickets`, `implement`, `tdd`, `code-review`, `wayfinder`,
`diagnosing-bugs`, `improve-codebase-architecture`, `wizard`, `grilling`,
`domain-modeling` return their documented process as content instead of
executing it. The driver therefore executes their steps inline, manually,
exactly as written (R2: spec template + ticket files + red-green + parallel
sub-agent review; R3: chart-only map, Phase-1 loop, HTML report, STOP-note
for wizard), and records each manual run in the trace/JOURNAL. A manual run
that follows the skill text verbatim IS a compliant invocation — the absence
of an auto-executing Skill-tool effect is expected, not a defect.
`wizard` additionally never auto-executes external steps: scope the stages,
verify statically (`bash -n`), then STOP with `NEEDS-HUMAN.md` when any stage
spends money, touches credentials, or submits externally (R3: Steam $100/tax/
bank/submit → STOP, script content only).

**v12 — prototype branch choice in engine repos (R4 finding; R62 deviation
disclosure).** `prototype` offers LOGIC (shareable HTML) vs UI (routed
variants) branches, both assuming web tooling. In engine repos (Godot/Unity:
headless-capable, no URL router) default to a third shape: **headless numeric
timeline** — a gitignored single-file SceneTree script printing the design
question's state over time (R4: P2 telegraph ring/countdown/pulse values per
second), exit 0 when runnable. Branch picker: web page/route → UI; stateless
state machine → LOGIC; engine scene/draw/feedback → headless timeline.
DEVIATION (honest label, R62 upstream re-read `.scratch/toast-spacing/
upstream-note.md`): upstream mandates shareable-HTML artifact + double-click
run + throwaway-branch capture (`prototype/SKILL.md:14,22,26`) — the timeline
contradicts all three in letter while preserving intent (`:8` question-decides-
shape, `:17` surrounding-code default, `:25` per-step state print). Capture
rule therefore CORRECTED (v12's old "unchanged" claim was inaccurate):
default to upstream branch+pointer when the repo has a branch workflow;
delete only single-file numeric probes AND paste verdict+timeline into the
ticket. `handoff` target is always the OS temp dir, never the workspace (R5:
`handoff-boss-polish-r5.md` in `%TEMP%` with suggested-skills section).
`resolving-merge-conflicts` drill rule: synthetic rehearsals live in `/tmp`,
never in the game repo; resolve by intent (preserve both where orthogonal),
never `--abort` (R5 drill: punish −80 + floor 120 kept together).

**v14 — auto-dispatch triggers (R29 user requirement: skills must fire
automatically, in-round, not just at kickoff).** The driver calls the Skill
tool itself at these moments — no human prompt needed; each round's JOURNAL
entry names every skill called (T0 + phases), so dispatch is auditable
(grep-level: every iteration entry names ≥1 skill):

- **T0 every round:** open with one `ask-matt` call routing the round's work;
  record the route in one line (R29: EN re-sweep → verification loop,
  v14 → doc change).
- **Idea needs sharpening** → `grill-with-docs` (working dir) / `grill-me`
  (stateless, off-repo); raw primitive only via `grilling`.
- **Outside facts needed** → delegate `research` to a background agent, keep
  working; its note feeds the next grill/spec.
- **Runnable answer needed** (state feel, UI look) → `prototype` (engine:
  headless timeline per v12), bridged by `handoff` in both directions.
- **Multi-session build** → `to-spec`, then `to-tickets` (blocking edges),
  then `implement` per ticket (fresh context each), driving `tdd` inside
  (red-green per slice) and closing with `code-review` (two axes, parallel).
- **Hard bug** → `diagnosing-bugs` (Phase-1 tight loop FIRST, no theorising
  before red); post-mortem hands seam-less findings to
  `improve-codebase-architecture`.
- **Raw incoming pile** → `triage` (never triage `to-tickets` output).
- **Foggy multi-session effort** → `wayfinder` (chart-only first, one ticket
  per turn, collapse before build).
- **Interface shape in question** → `codebase-design` (design-it-twice);
  **fuzzy terms** → `domain-modeling` (lazy CONTEXT per §0/v13).
- **Upkeep moment** → `improve-codebase-architecture` (HTML report to temp,
  suggest-only); **harness/directory/colleague boundary** → `handoff`
  (temp dir per v12); **human-only wall** → `wizard` (scope + STOP per v11);
  **unclear message** → `wait-what` (STE100 + fallback vocab per v13);
  **mid-conflict** → `resolving-merge-conflicts` (intent, never --abort);
  **blocked on someone else's head** → `to-questionnaire` (grill the send);
  **multi-session learning** → `teach` (single-file lessons per v13);
  **authoring agent docs** → `writing-for-agents` (pointers/ladder/pruning);
  **first run in a repo** → `setup-matt-pocock-skills` (once, then audit-only).

**v15 — round sizing + T0 discipline + verification tiers (R30).**
One round = one commit = one JOURNAL entry (number cited before committing;
see v7 draft discipline). Size the round BEFORE acting: a round carries either
(a) one game-code change (Lane A/B slice), or (b) skill-doc evolution, or
(c) verification-only hardening — never (a)+(b) mixed, so each commit stays
reviewable. **T0 discipline:** every round opens with the `ask-matt` T0 call
above and records its one-line route; a round without a T0 line is malformed.
Verification tiers: code rounds carry the dual gate (title 300f + fast-forward
1800f, restore + re-verify); doc rounds carry title-smoke; audit rounds carry
their seam assert (parity/sweep) + smoke. R30 pairs (b)+(c): v15 text plus the
3600f long-soak baseline row.

**v16 — audit quota + doc-sweep batching (R49).**
Verification-only rounds are capped: at most 3 consecutive audit rounds, then
the next round MUST be (a) a game-code change or (b) skill-doc evolution —
audits never form the majority of any 10-round window (R31–R41 ran 11 straight
audits: thorough but main-line starving). When a doc sweep spans sibling files
(PLAN/README/STORE/TRAILER/SETUP/BALANCE), batch them as ONE Lane A round with
a per-file one-line provenance each, instead of one round per file (R44–R49
took 6 rounds for 6 files; batched it is 1–2).

**v17 — single-invocation persistence + diversity guard (R51).**
One driver invocation persists for the whole conversation: every round
re-anchors with the T0 `ask-matt` call above without needing a fresh
invocation, and any of the 25 skills may fire in-round at its trigger —
persistence is the default, not a re-entry. Diversity rule: every round
names ≥2 distinct skills in its JOURNAL entry (T0 `ask-matt` + at least one
lane/support skill whose steps were actually executed; inline execution per
v11 counts — a manual run following the skill text verbatim IS the
invocation). Monotony detector (grep-level): 3 consecutive rounds with an
identical skill set, or any round naming only T0, is malformed — the next
round MUST switch lane/type (audit → code/doc, doc → code, code → upkeep).
R29–R50 ran 22 straight T0-only entries despite v14: thorough but
monotonous; v17 makes that shape unverifiable-by-construction. First live
verification (R52–R53): R52 Lane B 5 skills + R53 upkeep 3 skills, three
rounds three types with R51 — see JOURNAL #184–#186. Detector compares skill
SETS, not themes: R55–R57 shared the F12-hint theme yet stay compliant (sets
differ, R56 audit rotated lane) — see JOURNAL #188–#190.

**v19 — coverage watchlist (R82 mid-point finding).** A coverage audit that
finds single-dispatch skills parks their names in the closeout ticket (not
here — R82: 14 names in `cover-25/issues/12-closeout.md`), and later rounds
prefer those skills at their natural v14 triggers when the lane fits. No new
gate, no quota: a preference that keeps the single-dispatch tail from
surviving to closeout un-re-verified.

**v20 — `disable-model-invocation` full list (R88 re-audit correcting v10).**
v10 named 2; re-audit finds 14 of 25 declare the flag (R88 grep: `ask-matt`,
`grill-with-docs`, `triage`, `improve-codebase-architecture`,
`setup-matt-pocock-skills`, `to-spec`, `to-tickets`, `implement`,
`wayfinder`, `grill-me`, `handoff`, `teach`, `to-questionnaire`,
`wait-what`; the other 11 carry no flag). Rule unchanged: call all 14 via
the Skill tool normally — the flag is routing advice, not a hard block. If a
future runtime refuses, execute that skill's steps inline and note the
substitution, same as v10/v11.

**v21 — `to-tickets` AFK quiz self-answer (R90 pressure-test finding).**
`to-tickets` §4 Quiz demands user questions + iterate to approval; AFK goal
has no user to ask. Driver therefore self-answers inline: granularity per R76
linear precedent, edges blockers-first, frontier named, ticket `Status:
ready-for-agent` line IS the publish (driver §5) — same rule as v11
manual-run-is-invocation. Returning user may re-split on review; no new gate.

**v22 — single-invocation persistence evidence (R101–R117 pressure-test finding).**
One explicit driver call (R101) persisted 16 further rounds (R102–R117) with
zero re-invocation: every round re-anchored via T0 `ask-matt`, sub-skills fired
at v14 triggers, JOURNAL names ≥2 skills per round (grep-auditable). No new gate.

**v23 — T0-first + quota-counting + parallel-order + proposal-landing (R152–R251
pressure-test findings, proposals 223/225/228/230).** Four wordings that read
three ways in the field, now pinned beside v17 (diversity guard lives here):

- T0-first: every round's FIRST Skill-tool call is `ask-matt` (lane routing);
  same-block parallel calls list T0 first and run in listed order; a late-added
  `ask-matt` does not satisfy T0. Read/Bash probes are not Skill calls and never
  count for or against order. `grill-with-docs` dual entry still opens with T0.
- Quota-counting: T0 counts toward the ≥2-skills round quota; an audit round's
  natural second skill is a `code-review` single-axis re-check (never pad with an
  unrelated skill); `grill-with-docs` dual entry (grilling + domain-modeling)
  counts 2 and the JOURNAL names both.
- Parallel-order: same-block parallel Skill calls run in listed order; re-check a
  result by quoting the tool output, never by re-invoking (a re-invocation is a
  new call); the JOURNAL `Skills called:` line lists names in call order.
- Proposal-landing: proposal filename NN = landing round (file-creation round),
  trigger chain inside under 触发轮次；unknown root cause keeps its section with
  candidates + confidence, never a deleted section; proposer self-passes the
  writing gate, main agent re-passes it at synthesis (two-gate two-person rule).

**v24 — standing triggers: intake-refill + verify + upkeep + boundary (R152–R251
findings, proposals 190/251/221/210).** v14 names the moments; these four name the
cadences that ad-hoc scheduling starved (each fired only by mission design before):

- Intake-refill: a round that leaves `needs-info` tickets records a refill hook
  (`回填钩子：<questionnaire/screenshot> → Rxxx`) in its draft; the next intake
  round opens with a refill check (answered → `needs-triage` re-estimate; silent →
  note the wait); two silent rounds mark `stale`, third silence closes
  `wontfix (reporter-silence)` with reason.
- Verify: a verification-only hardening round fires when the sweep is ≥10 rounds
  stale, the JOURNAL honesty triple (≥2 skills / no T0-only / no 3-identical-sets)
  is grep-unverified, or smoke shows a flake suspect — product is seam logs +
  counts, and it never consumes the v16 audit quota (hardening, not audit).
- Upkeep: survey every 20 rounds rotating talisman-build → wave-director →
  HUD-draw (uncovered zone first), honesty audit the next round, six-checks
  re-verify every ~60; event triggers (2nd same-shape adapter, 3rd duplication,
  cap-number change) fire immediately; coverage lives in `.scratch/upkeep/`.
- Boundary: lane-claim checks four gates (account-registration / bank-tax-submit /
  paid-submit-click / external-approval-wait); on a hit, finish all safe prep,
  file the slice STOP note, mark `ready-for-human`, never stop globally; on a
  miss, name the miss (`no gate matched`) and continue.

**v25 — environment honesty: tmp-namespace + soak-hygiene + assertion-discipline
(R152–R251 findings, proposals 159/170/201).** Three field bites where the tool,
not the code, lied:

- Tmp-namespace: never assume literal `/tmp` — resolve the OS temp dir at
  runtime from the shell that will verify it (`$TMPDIR` / `%TEMP%`), and verify
  back with a Read or `ls` in that same shell; on mismatch re-route (shell
  heredoc/`cp`) and record the mapping; a handoff note without its `ls` evidence
  is undelivered.
- Soak-hygiene: long headless runs (>1800f) go foreground under `timeout`
  (frames/60 + 60s); process-table before and after, kill strays first; one
  worker per worktree (collision → stand-down, never overwrite); fresh worktree
  imports once before first smoke; a segfault with an empty log is recorded as
  first-run 139 + unchanged rerun verdict, never as first-green.
- Assertion-discipline: every number an audit quotes is pasted with the command
  that produced it (glossary rows, counts, tallies); an eyeballed figure is a
  comment-truth bug of the R132 family — park the audit, re-count, then conclude.

Parked, not landed: 180 (game-code comment lock — a future Lane C slice owns it)
and 240 (audio empty-pool guard — explicitly deferred by its proposer); neither
is a driver rule, so neither is promoted here.

**v26 — freshness-gate: first-entry auto-setup (R252 finding, proposal 252).**
`v14 first run → setup` never fired because no entry action defined it. Now:
the round that first touches a repo MUST run the freshness-gate before T0
lane routing — check `AGENTS.md` / `CLAUDE.md` / `CONTEXT.md` /
`docs/agents/` presence; any miss (or all four absent in an empty repo) fires
`setup-matt-pocock-skills` immediately, AFK self-answer defaults
(local-markdown + single-context), products landed before lane work. T0
`ask-matt` route line therefore opens with the gate verdict, then the lane.
Rehearsals replay first-entry only inside the OS temp dir (`$TEMP` fixture,
never the workspace); a rehearsal without its `ls` evidence is unrun. Game
repos with all four present/conformant skip setup with a one-line `6/6` note.

**v27 — T0-order: gate-verdict-first (R281 finding).** v26 left two readings
(gate before T0 vs T0 opens with gate). Pinned: the freshness-gate RUNS
before the T0 call; the T0 `Skills called:` line QUOTES the gate verdict
(`gate 6/6 skip` / `gate MISS→setup fired`) as its first clause, then the
lane route. A T0 line without a gate clause is malformed on first-touch
rounds; on later rounds the clause is `gate n/a (touched)`.

**v28 — probe-type gate: explicit types in headless probes (R260 finding).**
GDScript single-file probes MUST annotate every local (`var x: float = ...`,
`float(wave)` casts) — inferred `:=` on Variant arithmetic parse-errors
(R260 `mult`). A probe that failed parse is not a verdict; rerun fixed and
record the correction inline before resolving its ticket.

**v29 — raw-entry checklist: when `grilling` fires alone (R303 finding, proposal P302-01).**
v14 "raw primitive only via `grilling`" left `raw` to feel. Enter the bare
primitive only when ALL three hold: (a) no working directory to leave a trail
in, (b) the run must leave zero doc side-effects (no CONTEXT/ADR/glossary
write), (c) the interview is one-shot with no frontier carry-over. Otherwise
`grill-with-docs` (working dir) or `grill-me` (stateless but trail-free only
by its own contract). Record which of (a)–(c) fired in the trace.

**v30 — foggy-gate checklist: when `wayfinder` fires (R312 finding, proposal P302-02).**
v14 "foggy multi-session effort" left `foggy` to feel. Enter `wayfinder` only
when ALL three hold: (a) the work cannot fit three sessions' tickets written
NOW (anchors + verify per ticket unwritable), (b) the decision chain is
invisible (blocking edges unknown until charted), (c) no map exists yet for
this destination. A well-scoped feature (Lane B writable NOW) never enters —
charting it wastes the map. Record which of (a)–(c) fired in the map Notes.

**v31 — shape-question checklist: when `codebase-design` fires (R313 finding, proposal P302-03).**
v14 "interface shape in question" left `question` to feel. Enter
`codebase-design` only when ≥1 holds: (a) two implementations compete and prose
cannot pick, (b) the seam sits in the wrong layer (caller learns too much),
(c) the 2nd same-shape adapter appears (one adapter = hypothetical seam, two =
real — reuse needs the design bench). Record the picked signal + KEEP choice.

**v32 — send checklist: when `to-questionnaire` fires (R317 finding, proposal P302-04).**
v14 "blocked on someone else's head" left `head` unobservable. Send only with
all three: (a) named recipient holding the gap, (b) the gap stated as questions
(most-important-first, one idea each), (c) a refill hook (`回填钩子：<send> →
Rxxx`, v24: answered → resolve, silent ×2 → stale, ×3 → wontfix). Grill the
send before writing (recipient + gap coverage = done).

**v33 — merge-entry checklist: when `resolving-merge-conflicts` fires (R322 finding, proposal P302-05).**
v14 "mid-conflict" left the entry state to feel. Enter only when `git status`
reports `merging` or `rebasing` (the conflict is real, not rehearsed). Resolve
by intent traced to each side's primary source, never `--abort`; synthetic
rehearsals live in `$TEMP` only (verified by `ls` in the same shell), never in
the workspace. Record both sides' intent + kept lines in the trace.

**v34 — anchor-block-first: cite version blocks, not line numbers (R348 finding).**
v29–v33 added ~30 lines, drifting every `driver:N–M` line anchor in audit
tables. Cite the version block (`v29`, `v30`…) as the anchor; a line number is
a snapshot valid only inside its version (note the version beside it). Repair
rule: when a version lands, its audit rows re-anchor to the block name.

**v35 — table-triage-flow: how to read the audit table (R361 finding).**
Read each row in three hops: (1) `verdict` (correct / missing / stale /
ambiguous per the R303 four-line rule), (2) proposal number (`P302-xx`,
trigger round = file NN), (3) fix version (`v29+` landed or `park` with
reason). The frozen table (R311) keeps version-snapshot line numbers; apply
v34 block names when re-anchoring. A new gap starts at hop 1, never by editing
a frozen row in place — append the re-anchor note.

**v36 — trace-capture + background-liveness (R402/R413 findings, proposals P402-01/P402-02).**
Two field bites where the trace, not the work, lied. (1) Trace-capture: in
repos whose `.gitignore` covers the pilot trace dir (`.scratch/`), a plain
`git add` silently drops every trace file — the round's commit then carries
only code, and the JOURNAL-trace 1:1 breaks without any error. Every round
therefore force-adds its trace paths (`git add -f .scratch/<slug>/…`) and the
commit's `--stat` must list them; a commit without its trace is unlanded, not
small. (2) Background-liveness: a timed-out status poll (`timeout`) reports
the worker as still running — that is a verdict about the poll, not the
worker. Re-read the worker's own log tail before claiming alive/done, and
record which evidence decided it.

**v37 — first-install observation window (R426 finding, proposal P402-03).**
v36(2) tells which evidence decides; it does not say how long to watch. For a
first-ever dependency install in a large repo, do not verdict `stall` before
10 minutes AND a log tail re-read: early output is only warnings/deprecations
while the tree resolves, and an empty `node_modules` at minute 3 is normal,
not stuck (R426: 3-minute `stall` corrected by the same log's tail reaching
the deprecation chain). The correction cites the tail lines, never the poll.

**v38 — worktree-branch discipline (R459 finding, proposal P452-01).**
When a branch is checked out in a linked worktree, never `checkout` it in the
main repo: the command fails and a follow-up `cherry-pick` lands on the wrong
branch, polluting the pilot trace (R459: `0e3f0be` rolled back). Do all PR-branch
work inside its worktree; the main repo stays on the pilot branch. Verify with
`git worktree list` before any checkout.

**v39 — T0-first round-opening gate (R513 finding, proposal P512-01).**
After the three round-opening reads and before any other Skill-tool call,
call `ask-matt` first (T0 route receipt opens the round). If a round already
opened with a non-T0 Skill call, disclose the deviation inline (round +
first-called skill + correction) and resume T0-first the next round; the
JOURNAL `Skills called:` line still leads with the T0 receipt. A round whose
first Skill call is not T0 is malformed the same way a T0-only round is.

**v40 — empty-slot search budget (R533 finding, proposal P512-02).**
When the second-PR slot is empty, cap the candidate search at 6 consecutive
rounds: log `搜索 n/6` in the JOURNAL each search round; at 6 with no clean
candidate, freeze the search and converge on polishing the banked patch or
coverage fill instead of widening further. Searching past 6 without a
candidate is the same drift the 10-round stall detector guards against.

**v13 — teach + wait-what without web/CONTEXT (R6–R7 findings).**
`teach` assumes HTML lessons + CDN assets + reference docs. In repos with no
web pipeline (R6: Godot), write **single-file lessons with inline style only**
(no CDN, no shared stylesheet until lesson 2 earns it); reference/ dir stays
empty until a second lesson reuses something. `wait-what` demands `CONTEXT.md`
vocabulary, but the driver lazily defers CONTEXT creation (§0): when no
CONTEXT exists, fall back to the repo's hardest-word list — BALANCE red-line
terms + code identifiers (`main.gd` symbols) — and note the fallback inline
(R7: 读条/群召/撕灯域/build_power). Neither fallback creates CONTEXT eagerly.


**V2.002 / v43 — single-trigger full-auto (skill-creator upgrade, 2026-09-06).**
- description 改推一把：invoke once drives whole task；正文加自举（每轮先重读自己再读现场然后 T0）。
- 新增 references/core-triggers.md：8 核心 skill 入口条件+产物约定+漏调判 malformed，其余 17 个四问模板。
- 新增 references/delivery-check.md：三件套（改哪里一句话+手工清单+verify 原文）+ 高危 STOP；HTML 看板彻底砍掉，每轮首句中文 `本轮调用：A、B、C`。
- 新增 references/usage-log.md：USAGE-LOG 记卡点供下次升级；driver 永不自改文件，只写 DRIVER-PROPOSAL。
- 轻痕迹：.scratch 只留 spec/NOTES/verify，JOURNAL 只记 decisions+verify 结论；长调度归 goal 模式，driver 只被触发时转一圈。

**V2.003 / v44 — central logbook (skill-creator upgrade, 2026-09-06).**
- 日志改中央一本：`mattpocock-skills-USAGE-LOG.md`（仓库根，所有 Agent 共用，append-only，不进 skill 包）。
- 一条 = 5 方面（经过/为啥用/卡点/漏用自查/结果），每方面可写多行；写不进中央本时退回本地 `.scratch/<slug>/USAGE-LOG.md` 并注明。
- 新增漏用自查硬规则：每轮对照 core-triggers.md 8 核心过一遍，“该用没用”自己交代，不依赖用户懂工作流。

**V2.004 / v45 — auto-log at task close (skill-creator upgrade, 2026-09-06).**
- 日志改自动：任务结束（交付/STOP/BLOCKED）driver 自己写一条，不用用户提醒；跨轮任务收尾写一条；无 skill 轮次在 JOURNAL 记原因。
- 写死任务 vs 轮次：按任务记，一任务一条；第二轮重触发=新一轮 driver 干活，收尾照写（注明接续第 N 轮）。

**V2.005 / v46 — eval-hardened (skill-creator test prompts, 2026-09-06).**
- 跑完 3 道短提示词考题（切换按钮 bug / 加复制时间按钮 / 记账小项目），三题 PASS。
- bug 题修正：有症状文本即满足 Lane D 入口，不停问；反馈环断言代码缝，不编用户操作路径。
- 小功能题确认 Lane B 全链（grill→spec→红→绿→冒烟→双轴自查→三件套）。
- 模糊题确认：无目录先访谈再画图，遇新系统 STOP 留开放问题，不建应用文件。
- 通用坑：Windows 下 /tmp 路径映射、仓库无验证命令时自发明 seam 断言、子 skill 只回文档时 fallback 手动执行并注记。

**V2.006 / v47 — utilization + continuity (field hardening, 2026-09-06).**
素材：ZenApiWeb v1.043–v1.048 + cc-gateway v1.031–v1.032 六轮真实日志 + DRIVER-PROPOSAL（ZenApiWeb/.scratch/mattpocock-workflow-upgrade/）。
- 正身优先：fallback 速记版只准在 skill 未安装时用；未加载正身就干活 = deviation 必记（根因修复：速记版架空 to-spec/implement/grill 的过程纪律）。
- research 硬入口：任务所需外部事实必须走后台代理+引文落盘，直接搜索顶替 = deviation。
- slice 后 15 秒自扫：对照已加载判据自问，绝不重读文件。
- 同会话续跑：全文重读只在会话首轮/compact 后/拿不准时；新窗口靠 WORKFLOW-ACTIVE 标记 + setup 写入项目 AGENTS.md 的常驻入口自动召回 driver。
- setup 判据：首个动代码轮之前必须已跑，纯理解轮不算 first touch。
- 用户政策入法：宁可多花 token 不让人参与——code-review/verify 永不豁免，纯 UI 走快档评审，人的参与只留 STOP 清单。
- 多意图单提交的 spec 组织规则（conventions）。

**V2.007 / v48 — scheduled reflection (skill-creator upgrade, 2026-09-06).**
- 新增定期反思：本会话每 3 个工程轮，任务收尾+任务日志写完后，driver 往中央日志本追加一条 [反思]（固定目标开头 + 五问：调用时机/含糊规则/自创偏方/最大差距/其他），每问引实际事例，无发现写"无"，禁止编造。
- 调用时机为第一问（用户中心关注）：外层"何时该调 mattpocock-skills"+现有检查点有效性+由它设计检查点放哪。
- 计数存 WORKFLOW-ACTIVE 标记（工程轮次: N，每轮 +1），删标记前计数留在会话上下文；误差无害宁多勿少；反思只在收尾做，绝不打断任务。
- 铁律不变：反思只进日志，不自改 skill；升级仍走 skill-creator。

**V2.008 / v49 — field distillation (skill-creator upgrade, 2026-09-06).**
素材：ZenApiWeb v1.049–v1.056、cc-gateway v1.034–cde34bd、ant-design 双 PR 及 6 轮跟进、V2.007 三轮评估跑 + 3 条 [反思]。
- 自扫清单扩展（core-triggers）：红转绿后问"这缝还锁着别的行为吗"；连败 ≥3 次停下固化踩坑；同文件新轮次冒烟覆盖既往缝；方案之争/跨 ≥3 源文件提示 codebase-design。
- 无 harness 期望值纪律（verification-gates）：期望值必须注明独立真值来源，≥1 条护栏期望 ≠ buggy 输出，注释契约按 comment-truth 核对。
- 测试清单纪律：≥2 个独立测试即建统一入口并登记全部测试，漏录 = 交付不完整（v1.055/v1.056 事故）；付费测试分层标注。
- 外部 review 意见处理：先复现→有效才修→线程贴红绿证据回复；tautological 断言可拒但审稿人坚持就加。
- 偏方转正：中央日志 shell 整条 append；无 JOURNAL 仓 Skills called: 写 NOTES 顶部；Edit 工具替代脚本 replace（静默 no-op 坑）；Windows 管道挂死/MSYS 路径注记；fork/上游 PR 计工程轮次。
- 字面修正：gate n/a (touched) 钉死为展示缩写，Gate 0 新变更面照跑；反思计数兜底（日志本重建 + 规则中途引入即补首反思）；chore 元数据提交不 bump 版本；手工清单优先一条可复制命令。
- 考题第 3 次点名的 B-vs-D 矛盾就地修正（prelane）：用户报的 bug 永远走 D，B glance 只管 lane 内偶遇的 bug；Gate 0 增设 BROKEN 出口（机制在但行为错 → Lane D）；非 git 仓 code-review 快档 = 明文完整替代。

**V2.009 — long-task hardening (skill-creator upgrade, 2026-09-07).**
素材：V2.008 水位线之后的 48 条（ZenApiWeb v1.057/v1.070–v1.073 三场硬仗 + DSH game 33 轮长会话 33 任务条 + 11 条 [反思]）。
- 长任务 spec 演进位（core-triggers）：跨轮 Lane C 冻结 M0 基线，增量只走决策票 + CHANGELOG；短任务不受影响。
- 收尾审计四项（verification-gates §7）：版本串 grep、模板假路径、断言串拷贝粘贴、三真源期望核对——每条都抓到过真实已交付缺陷。
- tdd 不适用落字（core-triggers）：纯渲染/文案/文档/只读审计轮记 n/a 合规，门禁=回归绿+包验/语法。
- 稳态心跳正式化（trace-discipline）：无新缝时重跑统一入口+包哈希即 Gate 0 结论，不是空转，照记任务条。
- 重复 PR 预检三条（trace-discipline）：时间线 cross-ref + 搜 close #编号 + 确认无 OPEN 竞争者；旧关闭尝试≠没人做。

**V2.010 — official alignment (skill-creator upgrade, 2026-09-07).**
素材：V2.009 水位线之后 30 条（DSH game 57–79 轮稳态心跳 + V2.009 切换轮 + 用户反馈 v0.8.0 + 侵蚀卡死复核轮 + 反思 19–25，无反例，放心加门）+ 官方 README 全文（browser-act 直读 github.com/mattpocock/skills：user-invoked/model-invoked 二分 + 四失败模式 + 三步安装）+ 本地正身上游 7 份原文互证。
- setup 状态位：`docs/agents/` 存在 = 已跑；不存在 = 本轮先跑；空仓/无 AGENTS.md 默认先跑（修 33 轮未触发之 bug）。
- grill 方向盘：超"改一个已定位东西"的需求必须走 frontier→自答→收敛书面过程；"一句话说清就不调"的漏洞关闭。
- prototype 硬入口：两方案争执/跑起来才知道 → prototype 或 design-it-twice 二选一，不许直接开写。
- codebase-design 前置 tdd：缝/形未定先 consult 词汇表，再写测试。
- research 量化门：≥2 处外部事实必须落盘。
- 编排铁律：user-invoked 永不调另一个 user-invoked（官方原文）。

**V2.011 — destructive-guard (skill-creator upgrade, 2026-09-09).**
素材：V2.010 水位线之后 35 条（DSH 83–86 轮 + ZenApiWeb v1.074/v1.075/v1.079–v1.083 流中断系列 + naraka 逆向 7 轮收官 + 学习营 6 轮 + 搜索信息建制 + cc-gateway 思考档位 + running_page PR + 反思 6 条）。
- 红阶段回退禁 stash（verification-gates §8）：文件级 cp 备份优先，禁改 git 状态取红；批量改动前先取基线；零命中换路；环境 bug 收尾问同类 sibling。（v1.083 git 对象库事故换来）
- 否定性证据规范（trace-discipline）：N 处 0 命中当证据，不写"没找到"。
- 标记重建带计数+反思位（trace-discipline）：累计工程轮次 N / 已反思 M 次同生共灭。
- T0 空转计数（trace-discipline）：连 3 次无裁决记 repair 信号，给 skill-creator 修路由。
- AGENTS.md 常驻钩子加半句：新任务拿不准也先调它分流（十几个字，不读全文）。

**V2.012 — author-aligned (skill-creator upgrade, 2026-09-09).**
素材：作者 11 份视频转录（9/11 有效，1 过时 XML 标签按正身排除、teach 无关）× GitHub 仓库介绍 × 本地 7 份上游正身互证 + 线上 README（browser-act 直读：user/model-invoked 二分 + 四失败模式）。
- grill→prototype 出口：ungrillable（手感/外观/状态行为）经 handoff 跑原型再回来，硬烤 = malformed。
- prototype 入口放宽到"look/behave 是关键问题"，wayfinder 默认放 prototype 票。
- triage 全套：双标签 + ready 必须附 brief + .out-of-scope/ 拒绝库 + 不轻信 reporter 独立复现。
- spec 审计定位：冻结即封存，审计看 issues+CHANGELOG。
- improve 产出等人拍板（strategic/programmer 分工）。

**V2.013 — version-handoff (skill-creator upgrade, 2026-09-09).**
素材：用户版本级迁移需求（001 在 ZCode 做完 → 002 整个搬 Codex → 005 搬回 ZCode 做 006）+ 作者 handoff 视频（写信不送信 + suggested-skills 段）。
- handoff 版本交接包：版本之间搬一次（交付 + decisions + 待办 + 日志本路径 + 建议 skill），落系统临时目录；不自动开新对话。
- 跨 harness 日志：日志本不跟版本走，交接包写明本机路径；新 harness 走本地注明，回来合并。

**V2.014 — rename: mattpocock-skills → autopilot (2026-09-09).**
- skill 名改为 `autopilot`（包目录/SKILL name/hook 行/安装器/日志默认路径 `~/.autopilot/` 全套）；仓库名 `autopilot-skill`（公开仓迁移 + 推送新远程）。
- 日志本更名 `autopilot-USAGE-LOG.md`（append-only 延续，历史条目不动）；规则内容零改动。

**V2.015 — logbook diet + T0 truth (skill-creator upgrade, 2026-09-09).**
素材：日志本 1632 行/210 条 + 逆向项目 T0 连空 11 次现场 + 用户两问（日志太大读不起怎么办；空转第 12 轮怎么回事）。
- 读本纪律：自举只读最后一个水位线 + 其后最多 3 条；反思计数同理；旧条目升级时归档 archive。
- T0 正名：ask-matt 是地图不是裁判，lane 裁决永远来自 prelane 自落子；恒空项目同会话只首轮调 T0（降频）。
- 空转记一次：同一项目首轮记 `T0 恒空` 即止，禁每轮数数（信号不做噪音）。

**V2.016 — round-boundaries (skill-creator upgrade, 2026-09-10).**
素材：V2.015 水位线之后 55 条（逆向 slice11–40 + E_Key_Monitor 理解轮/5 票/便携版 + 反思 13 条）。
- 理解→动手边界：理解轮不改仓不建标记不计轮；跨界另起轮 + 书面 transition；无 transition 混合轮 = malformed。
- 心跳评审对象：零改动轮审产物新鲜度（包时间戳/CHECKS重写/冒烟重跑），不是审 diff；完整心跳三件（全量回归+双包重打+便携同步）。
- 版本自检：自举先对 skill 版本行与日志水位线，失配重读（修 V2.014 包 V2.015 话术残留现场）。

**V2.017 — evidence-discipline (skill-creator upgrade, 2026-09-15).**
素材：V2.016 水位线之后 18 条（E_Key_Monitor 根目录清理＋反思、搜索工作流 V4/V5/V6＋反思、AEC 虚拟麦克风 MVP＋真机验证＋端到端＋证据固化＋验收指引＋咚咚声调查修复＋瞬态抑制＋夜攻坚＋深夜闭环＋反思）。
- 回执≠证据：子 agent 报完成必须做"回执 vs 磁盘+测试"对账，只信回执 = malformed（CLI 票报完成实际缺 4 文件 + README）。
- 合成基准唯一源头：新验证工具复用已验证配方，不重写；结论打架以已验证为准（ERLE 3.27dB vs 32.20dB）。
- 验收阈值必须拿已过样本校准：门限不许拍脑袋（e2e 门两次拍脑袋被打脸，第三次 -43.5dBFS 校准 -50dBFS 才站住）；单轮 e2e 数字不可信，用药前先测输入强度；实时链路优先于文件验证链路。
- ready-for-human 单独立票：必须真人动手的验收写成唯一的票，票 MUST 指向 NEEDS-HUMAN.md；resolved 票内出现未完成人工环节 = contradiction。
- Real-world 对照优先：行为结论先做"直采 vs 引擎"对照实验再动代码；实时指标必须加窗（EMA 全程平均在启停场景下是错的）。

**V2.018 — continuous-grilling (2026-09-16).**
素材：V2.017 水位线之后零新条目 + 用户本轮反馈（grill 只在开局用、中途不用；质量优先、不计 token）+ 15 路子 agent 三波讨论（正身精读/现状审计/点位挖掘/自答质量/铁律反模式 → 激进/保守/合规/Bug专项/验证五立场 → 红队双审/合规审查/排序收敛/终稿综合）。
- 开局问透：grill 跑到 frontier-empty（软上限 4 轮、硬上限 6 轮；收敛 = 空+稳+净；发散刹车 = frontier 连两轮不缩小即 STOP；不可逆清单/数值项永不计入收敛；找事实派子代理并行，不占轮次）。
- 中途 6 硬门禁（只许裸 `grilling`）：①prototype 回来必回烤；②research 回包必烤；③Lane C resolve 挖出 spec 范围外新系统/依赖先烤方向；④tdd 缝位未定先微烤再 consult；⑤code-review 报 spec 相反先回烤；⑥hypothesise 必烤假设排序。命中未调 = malformed。
- 中途 2 软提醒：红转绿后扩锁烤一轮；连败 ≥3 次重烤策略。切片/Collapse 边界争议暂缓 V2.019。
- 铁律边界：中途调 `grill-with-docs`/`grill-me` = malformed（user-invoked 互调）；中途产物只写 ticket `## Answer` + map 指针 + `NOTES.md`；审计只扫 JOURNAL `Skills called` + 调用痕。
- bug-flow 禁令加注：禁的只是无 Phase-1 红空聊；红建成后 hypothesise 窄烤是硬门禁⑥；verify-only 豁免保留；B-vs-D 拿不准允许先烤 1 轮分流。

**V2.019 — load-discipline (2026-09-17).**
素材：V2.018 水位线之后 11 条（ZenApiWeb v1.150–v1.158 同日 5 任务＋5 反思＋1 补记，单项目单日）。
- 开工点名：动手前写一行本轮正身清单并逐一经 Skill 工具调用，代执行仍先加载再 inline；清单缺项或有点名无调用痕 = deviation（同一条未加载正身连犯 5 轮，自觉换点名）。
- 按 lane 读本：自举读全套，lane 开工前按 `ground-truth.md` 确认本 lane 清单（Lane B/C/D/E＋纯理解各 5 行内）；首轮漏读 `core-triggers.md` 致 6 硬门禁漏用是本版直接起因。
- 引用改文件名：瘦身残留的 `§1`/`§4`/`§6` 全部改成文件名（prelane/verification-gates/context-hygiene/self-answer），档案区 v10–v40 原样不动。
- 单轮标记豁免：同轮内开闭的任务免建 WORKFLOW-ACTIVE，记一行 `单轮开闭，免建标记` 即可（同轮建了又删是空转）。
- 收尾结构机检：版本标题严格递减＋package 版本有对应标题＋README 版本行一致；占位符与假路径同查（两次误删版本标题＋反引号被 shell 展开换来）。
- 暂缓：通用思考态 grill 与切片/Collapse 边界仍不进本版——跨项目独立证据仅 1 例（提案前证伪前提），未达 3-1-2 门槛，不硬凑。

**V2.020 — trigger-audit (2026-09-24).**
素材：V2.019 注明的已消化范围（V2.018 水位线后 11 条，v1.150–v1.158）之后的新条目——v1.164 起 27 任务＋3 反思＋2 补记（另有 1 空标题已作废），共 33 条＋用户本轮边界反馈＋10 路边界讨论。
- 点名 2.0：收尾前 grep JOURNAL `Skills called` 行对点名清单，有点名无调用痕当轮补 deviation（v1.182–v1.184 code-review 连犯 3 轮；V2.019 点名只管写不管调）。
- 计数落盘：反思计数以 WORKFLOW-ACTIVE 标记文件为准，会话记忆重启即丢不可信；收尾删标记前先读数，够 3 即补（server 重启 4 次、marker 未丢换来）。
- 落盘一句话：证据进仓，日志进本——工程证据（spec/NOTES/回归）进仓随版本提交，过程流水（任务条/反思）只进中央本（v1.175 记错地方＋两轮反思同族）。
- 暂缓（触发门/证据门不过，park 不进）：提交前 diff 扫脏（同族 3 次但属执行卫生，留项目 checklist）；上游变更先查同类 PR（v1.170 单次，待跨项目复现）；V2 实测适配（项目域腐烂，不进 driver）。
