# 01: QA 门禁脚本 qa_gate.py

**What to build:** 在 skill scripts 下新增唯一 QA 入口，把 12 项门禁做成可执行检查：时间线互斥、源时间码合法、音画差、VFR、blackdetect/freezedetect/silencedetect、astats/ebur128、字幕 CPS 重叠、双层字幕、漂移、三件套齐，外加 Phase3-02 补齐三处（Proxy-Source 帧映射、拼接点音频连续性、字幕哈希互斥）。任一 FAIL 即 NOT_FROZEN，阻断送审与 4K 成片。只用标准库 + FFprobe/FFmpeg 文本输出解析，不新增依赖。
**Anchors:** `skills/naraka-highlight-studio/scripts/validate_combat_timeline.py :: main`
**Anchors:** `skills/naraka-highlight-studio/scripts/validate_delivery.py :: main`
**Anchors:** `skills/naraka-highlight-studio/references/deliverables-and-qa.md :: Quality gates before delivery`
**Blocked by:** None
**Status:** completed
- [x] `qa_gate.py --help` 可运行，12 项每项输出 PASS/FAIL/WARN + 实测值 + 阈值 + 证据路径
- [x] fixture 时间线实跑 pass；构造一例越界/重叠时间线实跑 FAIL
- [x] 无新增第三方依赖，沙箱不可执行时如实报环境限制

## Verify
PASS: implemented and smoke-tested on 2026-09-11. See NOTES.md for evidence.
