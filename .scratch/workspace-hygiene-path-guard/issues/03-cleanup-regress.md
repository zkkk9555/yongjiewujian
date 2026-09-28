# 03: 回归与孤儿清理收尾

**What to build:** 回归（fixture PASS + 4 脚本 py_compile + grep 无合法烧录外的新残留）+ 经用户确认删除根目录 85 张孤儿 `f_*.jpg` 与 0 文件空壳目录（`$T`、星号重复目录、乱码兄弟目录，有文件者不动）+ NOTES 落证据 + 删 marker。
**Anchors:** `skills/naraka-highlight-studio/tests/fixtures/combat_episodes.json :: combat_episodes`
**Blocked by:** 01-path-guard-docs.md, 02-realtime-cleanup.md
**Status:** completed
- [x] fixture + py_compile 全绿
- [x] 孤儿散图与空壳目录已处置（用户已确认）
- [x] 任务目录除清理 log 外无新增写入，marker 已删

## Verify
PASS: implemented and verified on 2026-09-12. See NOTES.md for evidence.
