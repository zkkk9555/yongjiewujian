# 02 — BGM 策略对齐

Status: resolved
Anchors: `style_profiles/high_energy_v1.json :: music`, `assets/README.md :: 素材库`

## Task
消除“暂缓平台榜单”与“dynamic_current/按趋势重排”之间的矛盾。

## Answer
`high_energy_v1.json` music.mode 改为 `local_or_supplied_only`，`prefer_platform_native_when_publishing` 改为 false，保留 BGM stem 与 ducking 参数。`assets/README.md` 删除平台趋势重排句，改为只收录本地/用户可用音频。

## Verify
读取 JSON music 块确认为新值；assets README 已更新。
