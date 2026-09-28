# 素材库

这是专属剪辑工作流使用的本地素材库。当前只建立目录和索引，不自动塞入过期或来源不明的 BGM。

```text
assets\bgm       BGM 与节拍分析文件
assets\sfx       振刀、击杀、冲击、whoosh、riser 等音效
assets\overlays  闪白、粒子、速度线、光效等透明素材
assets\fonts     关键字和标题使用的字体
```

每次新增素材后，在 [asset_manifest.json](asset_manifest.json) 登记：文件路径、类型、标签、BPM/时长（适用于音乐）、来源和使用方式。剪辑任务只从已登记素材中自动选择。

当前项目暂不接入平台榜单动态查询；本地库只收录本地/用户提供的可用音频，任务时按实际 BGM 分析节拍。
