# 02: 门禁改禁烧录

**What to build:** `qa_gate.py` 烧录门改为禁烧录：任何烧录标记或 MP4 内字幕流（ffprobe subtitle 流 > 0）即 FAIL，不再有合法烧录分支。`validate_delivery.py` 的 `--burned-subtitles` 保留参数做兼容，但传入即按禁烧录判 FAIL（兼容不兼容错）。只用标准库 + ffprobe 文本解析。
**Anchors:** `skills/naraka-highlight-studio/scripts/qa_gate.py :: gate_burned_srt`
**Anchors:** `skills/naraka-highlight-studio/scripts/validate_delivery.py :: main`
**Blocked by:** None
**Status:** completed
- [x] 烧录 MP4 或含字幕流 MP4 实跑 FAIL
- [x] 干净 MP4 + 外挂 SRT 实跑 PASS
- [x] 旧 --burned-subtitles 调用不崩溃但判 FAIL

## Verify
PASS: implemented and smoke-tested on 2026-09-11. See NOTES.md for evidence.
