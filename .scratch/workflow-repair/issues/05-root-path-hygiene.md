# 05 — 路径卫生：根目录违规文件归位

Status: resolved
Slice: 4
Blocked by: —

## 问题

项目根目录躺着两个派生物，违反 `AGENTS.md §1` 与 `roughcut-launch.md §2.7`：

- `14-review-v2.decode.log`（196B）——任务 14 渲预览时误写根目录
- `t2.txt`（32B）——任务 15 渲 v2 预览时误写的 2 行 concat 残桩

## 动作

按 §2.7 规定隔离到**任务内** `cache/quarantine/`（不是删、不是丢到 `%TEMP%`——那是二次违规）：

- → `123\14.852…\cache\quarantine\14-review-v2.decode.log.stray-root`
- → `123\15.853…\cache\quarantine\t2.txt.stray-root`

## 一处判断错误及其修正

第一份文件我**最初判断为字节相同的副本，是错的**。加 SHA256 比对后哈希不同：

```text
root : 288D1F5A28B13AE94D9EAAC500F239AC749D35F8471695514CD4206CD7FF05A3
task : 1F3B0590B32A59445EF90FCE4C68729229B0E8BE8D242842989376CB5D698093
```

逐行 diff 确认**唯一差异是时间戳**（`16:46:14` vs `16:46:31`），其余完全相同（同文件、同 task_id、同 version、同 `exit_code: 0`、同 clean 结论）。是同一次解码检查的两次落盘，根目录那份更早，任务目录那份是符合命名约定的正本。

**沉淀教训：同名同大小 ≠ 副本。** 后续同类清理必须比对哈希或内容，不能凭文件名和大小下判断。

## 结果

根目录现只剩 `AGENTS.md` / `IMAGE_LIMIT.md` / `README.md` 三个规则文件，路径铁律在磁盘上自洽。

未删除任何文件、未改动任务目录正本、未触碰源盘。日志见 `docs/cleanup_log_2026-09-29_root_hygiene.md`。
