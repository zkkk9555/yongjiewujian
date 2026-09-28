# 02: manifest 内容指纹与文件名解耦

**What to build:** 修改 `build_batch_manifest.py` 的 `stable_id`：key 中禁放绝对路径，改用内容标识（size + mtime_ns 保留作展示，新增内容 hash 字段供缓存命中；大文件用分段采样避免全片读入过慢）。改名、挪目录、复制后同一内容仍能命中缓存；路径只做展示字段。
**Anchors:** `skills/naraka-highlight-studio/scripts/build_batch_manifest.py :: stable_id`
**Anchors:** `skills/naraka-highlight-studio/references/batch-workflow.md :: Caching`
**Blocked by:** None
**Status:** completed
- [x] 同一文件改名/挪目录前后缓存 id 一致（或内容 hash 字段一致）
- [x] manifest schema 向后兼容，旧字段保留，输出仍可解析
- [x] 大文件不全量读入（分段采样 + size 组合）

## Verify
PASS: implemented and smoke-tested on 2026-09-11. See NOTES.md for evidence.
