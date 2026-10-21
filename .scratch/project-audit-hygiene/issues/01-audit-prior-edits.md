# 01: 既往剪辑工作体检报告

**What to build:** 一份 `docs/lessons/STATUS-2026-10-22.md`，让用户一眼看出 25 个任务目录每个的状态
（母版在不在、冻结门禁最后判什么、清理跑没跑、经验落没落、缺口是什么），并列出本轮发现的
P0/P1/P2 问题，每条带 file:line 证据。只读体检，不改任何剪辑产物。

**Anchors:**
- `scripts/check_task_numbering.ps1 :: main`
- `scripts/collect_lessons.ps1 :: Test-Absorbed`
- `skills/cujian/references/roughcut-launch.md :: §3.7 冻结门禁2.0`
- `AGENTS.md :: §7.1 成片归属与出 4K 后的收尾清理`

**Blocked by:** None

**Status:** resolved

- [x] 25 个任务目录逐个体检，母版 / 冻结判定 / 清理 / notes / 缺口五项齐全
- [x] E 盘 40 份母版逐个核对存在性与非空（其中 16 份属早期任务，任务目录已删）
- [x] P0/P1/P2 问题清单，每条带 file:line
- [x] 母版帧精确抽查（ffprobe：nb_frames 对 duration×60、A/V 漂移）
- [x] 未闭合缺口如实登记，不补写缺失的冻结表

## Answer (decision tickets only)

**已交付（提交 `3906120`）：`docs\lessons\STATUS-2026-10-22.md`。**

超出 spec 的部分：

1. 母版从「39 份」改成 **40 份**（E 盘还有一个 `887…cujian.srt` 外挂字幕，与母版同目录，符合 §5）。
2. 多做了一项母版**帧精确实测**：10 份近期母版 `nb_frames == duration×60` 全部 delta=0，
   A/V 漂移恒 21 ms 不累加——顺手把 889 那条「concat 拼块每接缝漏一帧」的说法判成**未复现**。
3. 多登记了 **G6**：`streak≥1` 降级档这件 10-06 就挂着的待拍板事，
   已经被 885/887 两局的母版事实上默认了（两局都在 streak<2 的状态下出了母版）。

**按 spec 的要求没有做的事**：没有补写 887 缺的 `freeze_gate_33_v8.md`（补写=伪造冻结记录），
也没有动 34.888/34.889 的目录号（改了会让几十处绝对路径证据失效）。
