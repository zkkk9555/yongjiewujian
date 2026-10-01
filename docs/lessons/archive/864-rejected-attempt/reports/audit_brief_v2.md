# v2 审片作业书（任务 21 / 素材 864）

v1 已被对抗审（9 路）+ 自审（4 遍）+ 三路定点裁决推翻多处边界。**v2 是按裁决处方重建的版本，这一轮的任务是验证 v2、并只报 v2 自身的问题。**

## 绝对路径

| 用途 | 路径 |
|---|---|
| 任务目录 TASK | `C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13` |
| 冻结预览 v2（唯一 QA 依据） | `TASK\preview\864-review-v2.mp4`（1280x720 / 60fps CFR / **587.354 s** / 0 字幕流 / 干净画面） |
| 时间线 v2 | `TASK\timeline\combat_episodes_v2.json`（11 场 / 11 条删除段 / **6 处段内挖洞**） |
| 节目映射 v2 | `TASK\timeline\program_map_v2.json`（**16 个切口**，含每片的 `source_start/end`、`program_start/end`、`rendered_frames`） |
| 校验 | `TASK\reports\v2_validate.json`（pass=true，27 check，warnings 0） |
| 合并决策 v2 | `TASK\reports\merge_decision_v2.md` |
| 媒体滤镜日志 | `TASK\reports\preview_media_filters_v2.log` |
| 解码日志 | `TASK\preview\864-review-v2.decode.log`（exit 0，stderr 0 行） |
| 外挂字幕 | `TASK\captions\864-review-v2.srt`（42 条）+ `.stats.json` + `TASK\reports\srt_crosscheck_v2.json`（cross_cut 0） |
| v1 冻结包（**只读对照，不许当 v2 的 QA 依据**） | `preview\864-review-v1.mp4` / `timeline\combat_episodes_v1.json` / `reports\selfaudit_864_v1.md` / `reports\adversarial_864_v1_*.md` / `reports\adjudicate_{a,b,c}.md` / `reports\issue_list_v1.md` |

## v2 的 16 个切口（节目秒 ← 源秒）

| # | episode | 源区间 | 节目区间 | 时长 |
|---|---|---|---|---|
| 1 | combat_001 | 181.0–229.0 | **0.0–48.0** | 48.0 |
| 2 | combat_001（洞后） | 234.0–266.5 | **48.0–80.5** | 32.5 |
| 3 | combat_002 | 305.0–345.0 | **80.5–120.5** | 40.0 |
| 4 | combat_003 | 357.0–404.0 | **120.5–167.5** | 47.0 |
| 5 | combat_004 | 416.7–444.0 | **167.5–194.8** | 27.3 |
| 6 | combat_005 | 495.0–517.5 | **194.8–217.3** | 22.5 |
| 7 | combat_006 | 517.5–554.3 | **217.3–254.1** | 36.8 |
| 8 | combat_006（洞后） | 555.4–562.0 | **254.1–260.7** | 6.6 |
| 9 | combat_007 | 598.0–659.5 | **260.7–322.2** | 61.5 |
| 10 | combat_007（洞后） | 661.2–685.0 | **322.2–346.0** | 23.8 |
| 11 | combat_008 | 726.0–781.0 | **346.0–401.0** | 55.0 |
| 12 | combat_008（洞后） | 791.9–799.0 | **401.0–408.1** | 7.1 |
| 13 | combat_009 | 911.0–943.0 | **408.1–440.1** | 32.0 |
| 14 | combat_010 | 949.0–1037.0 | **440.1–528.1** | 88.0 |
| 15 | combat_011 | 1053.0–1100.8 | **528.1–575.9** | 47.8 |
| 16 | combat_011（洞后） | 1116.0–1127.5 | **575.9–587.3** | 11.5 |

换算以 `program_map_v2.json` 的 `cuts[]` 为准（每条都直接给了 P↔S）。

## v2 相对 v1 改了 17 处（这一轮重点验这些）

| 场 | 改动 |
|---|---|
| combat_001 | `source_end` 266.0→**266.5**；**新挖洞 `[229.0, 234.0)`**（5.0 s 全屏背包面板，货币 5450） |
| combat_002 | 边界不动。**已知且被接受的局限**：前置 305.0–310.0 是纯屋顶滑翔、没有「为什么打起来」的信号（「发现敌人」横幅落在被删的 `[266.5,305)` 内，前移要 +19.5 s 其中 2.1 s 全屏 UI 违规） |
| combat_003 | `engage_start` 361.0→**359.0**。`[374.4,375.4)` 的 1.0 s 面板**按硬门槛未挖**（洞两侧落在 seg5 判定要保留的战术拉开窗内，修线员核不到书面证据）→ **combat_003 内仍留约 1.0 s 全屏魂玉面板，是已登记的已知残留** |
| combat_004 | `source_start` 412.0→**416.7**（前置 0.4 s，"前置无可用素材"例外）；`source_end` 442.0→**444.0**（442.0 本身是全屏背包面板帧，v1 漏了） |
| combat_006 | `engage_start` 528.0→**522.0**；`source_end` 556.5→**562.0**（尾窗 7.5 s→**13.0 s**）；**新挖洞 `[554.3, 555.4)`**（1.1 s 全屏大地图） |
| combat_007 | `source_start` 597.0→**598.0**（597.0 开着右半屏面板）；**新挖洞 `[659.5, 661.2)`**（1.7 s 魂玉面板）；**`boundary_reason` 事实更正**（源 660.5–665.5 有归属本人的「就我有小猫饼 获得了四连胜」青色播报，v1 说"无一条归属玩家"是错的） |
| combat_008 | `source_start` 716.0→**726.0**（"救援白光"是建筑雕像，证伪）；`outcome_time` 792.0→**796.5**；`source_end` 800.0→**810.0**（**延长**，v1 差 9.5 s 没走完 13 s 尾窗）；**新挖 2 个洞 `[781.0, 791.9)`（10.9 s 背包面板，遮挡播报栏）+ `[799.0, 810.0)`（11.0 s 背包装备）**；`boundary_reason` 改成「敌方 4 人出局」（`窝不喝奶茶` 不在本队名册） |
| combat_009 / 010 | 边界不动 |
| combat_011 | 挖洞 `[1100.8, 1115.9)`→**`[1100.75, 1115.97)`**（v1 漏 7 帧、明暗双闪 0.117 s）；`source_end` 1127.5→**1127.45**（v1 越过熟练屏切走点 3 帧） |

## 判定标尺（唯一来源）

`TASK\reports\scanner_brief_common.md` 第 5 节。一场战斗 = 第一次明确交战 → 结果明确（击杀／团灭／敌人逃脱／玩家脱险／胜负已分）+ 短暂收束。
**删**：跑图、搜物资、等待、重复操作、长时间无事件、全屏 UI（除属收束环节的）。**留**：拉扯、救援、追击、躲技能、重新接战。**不切走**：战斗中途。**边界不确定 → 保留并标记。**

## 只报这四类低级错误

1. **战斗中断** —— 某场战斗在结果明确前被切走；或结果帧被挖掉/被切掉。
2. **漏战** —— 源里有完整一场战斗，节目里没有。
3. **跑图残留** —— 节目里出现搜物资 / 跑图 / 等待 / 全屏 UI 的长段。
4. **因果链断裂** —— 玩家状态突变（倒地 / 重新站起来 / 阵亡 / 复活 / 结算）缺来源；或"倒地直接跳站立奔跑"这类游戏内状态矛盾。

风格、BGM、字幕字体、特效喜好一律不报。**本阶段无 BGM、无装饰特效、预览零字幕流零烧录** —— 若你在画面上看到字幕，那是渲染缺陷，按 `跑图残留` 之外的独立问题报（类别写「污染」）。

## 抽帧命令

**⚠ 先读这段，它是本项目反复踩的坑，已由多路独立验证定案。**

本机 FFmpeg **n8.0-23** 对 seek / 时长选项的解析是**按位置**生效的，四种组合的实测结果如下（证据见 `cache\make_route_frames.ps1` 顶部注释与 `shots\adjudicate_a\`）：

| 写法 | 实测结果 | 判定 |
|---|---|---|
| `-ss A -to B -i SRC` | 输出 A+B 个**完全相同**的帧 | ❌ `-to` 放 `-i` 前被忽略，`fps` 滤镜吐出重复帧 |
| `-ss A -t D -i SRC` | 输出远多于 D×fps 的帧 | ❌ **`-t` 放 `-i` 前被静默忽略** |
| `-i SRC -ss A -t D` | 输出精确 D×fps 帧、全部不同 | ✅ 可用，但要从 0 解到 A，4K 源上很慢（解到 713 s 要 10 分钟+） |
| `-ss A -i SRC -t D` | 精确 D×fps 帧、全部不同，**1 秒完成** | ✅ **推荐**。`-ss` 前置做输入侧快速定位，`-t` 后置限定输出时长 |

**规则**：
1. `-ss` 放 `-i` **前**（输入侧 seek，快且准）
2. `-t` 放 `-i` **后**（输出侧时长）
3. **绝对不要**把 `-t` / `-to` 放在 `-i` 前面
4. 用 `fps=` 滤镜时**必须**加 `-fps_mode passthrough`，否则会为凑 CFR 补出重复帧
5. 已有的可信逐秒帧 `TASK\shots\segN\hd\tXXXX.0.jpg`（960×540，1152 帧，MD5 互异，文件名秒点 == 烧入 h:mm:ss == 源秒）**可以直接引用，不必重抽**
6. 抽完先跑 `cache\make_route_frames.ps1` 输出的 `distinct_md5` 自检；`distinct_md5 < 帧数` 就是又出重复帧了，**立刻停手，不要用这批帧**

推荐写法：
```powershell
& 'C:\Project\永劫无间\.video-tools\LosslessCut\resources\ffmpeg.exe' -y -v error `
  -ss <节目起> -i 'C:\Project\永劫无间\123\21.864永劫无间 2026-09-30 02-57-13\preview\864-review-v2.mp4' `
  -t <时长> -an `
  -vf "fps=<1 或 2>,scale=960:540,drawtext=fontfile='C\:/Windows/Fonts/arialbd.ttf':text='%{pts\:hms}':x=8:y=6:fontsize=48:fontcolor=yellow:box=1:boxcolor=black@0.6" `
  -fps_mode passthrough -q:v 3 '<你的输出目录>\t%05d.jpg'
```

**烧入的 h:mm:ss 是节目秒**（因为输入是对预览做 seek，输出时间轴从 0 起）。
若要稳妥校时，把抽出的第一帧与 `program_map_v2.json` 里对应切口的 `program_start` 对一下，或用 ffmpeg 的 `trim` 滤镜（`-vf "trim=start=A:end=B,..."`）完全避开 seek。

**另外两个同源坑**：
- 含中文路径的 `.ps1` 存成 UTF-8 **无 BOM** → PowerShell 5.1 按 ANSI 读源码 → 路径变乱码 → 输出树被建到 `C:\Project\<乱码名>\` 下。**脚本源码一律纯 ASCII，中文路径只走命令行参数。**（本轮已因此在 `C:\Project\姘稿姭鏃犻棿\` 下产生过空目录壳，见 `reports\cleanup_log_v2.md`）
- Python 的 `cv2.imread` / `cv2.imwrite` **打不开含中文的路径** → 用 `np.fromfile(path, dtype=np.uint8)` + `cv2.imdecode(buf, ...)`。

拼表用 `TASK\cache\make_sheets.ps1`（16 格一张，480×270，**一张表算 1 张图**）。

## 看图预算（硬红线，违者会话作废）

单次请求累计 ≤ 50 张，单轮新增 ≤ 10 张。**每轮之间先把已得结论写进报告文件**，再开下一轮。
看图前先跑 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'C:\Project\永劫无间\scripts\check_image_budget.ps1' -ImageDir <你的帧目录> -AlreadySeen <已看数>`。

## 报告必填

写入 `TASK\reports\adversarial_864_v2_advK.md` 或 `TASK\reports\selfaudit_864_v2.md`（按你的角色），UTF-8：
1. **区间**（节目秒 `[P0,P1)` + 对应源秒范围）
2. **已看证明**（抽帧规格 + 帧数 + 联系表绝对路径 + 预算记录）—— **无问题的结论也必须附**
3. **问题清单**：每条五项（类别 + `P→S` + 换算式 `S = cut.source_start + (P − cut.program_start)` + 画面描述 + 证据路径），`P` 精确到 0.1 秒
4. **段缝互证**（5 秒重叠带两侧结论）
5. **不报清单**（看到但按标尺不构成问题的，写清为什么不报）
6. 末尾单独一行 `STATUS: DONE` 或 `STATUS: BLOCKED`

**禁止**：改 `timeline\`、重渲预览、补抽帧定新边界、开新问题分支、动任何 v1 文件、写出 TASK 目录以外任何路径。**`C:\Project` 下有并发会话留下的乱码目录，不要碰、不要删。**
