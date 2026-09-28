# 02: 即时清理与门禁护栏

**What to build:** `deliverables-and-qa.md` 生命周期追加即时清理节（旧版预览单保留、散帧段冻结即清、可再生音频成片即删、记 cleanup_log）；`qa_gate.py` 增 `workspace_hygiene` 检查：任务目录外零散产物（项目根 `f_*.jpg`/`thumb_*.jpg`/散 `*.mp4`）存在即 WARN，数量超阈值即 FAIL；只用标准库。
**Anchors:** `skills/naraka-highlight-studio/references/deliverables-and-qa.md :: Versioned naming, lifecycle, and cleanup`
**Anchors:** `skills/naraka-highlight-studio/scripts/qa_gate.py :: main`
**Blocked by:** None
**Status:** completed
- [x] 即时清理节落盘，旧版预览只留相邻两版→成片只留冻结一版
- [x] qa_gate 根散图存在即 WARN，超 10 张即 FAIL
- [x] 无新增依赖，fixture 仍 PASS

## Verify
PASS: implemented and verified on 2026-09-12. See NOTES.md for evidence.
