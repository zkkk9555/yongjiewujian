# 06 — 质检脚本 PowerShell 移植：已放弃（回滚记录）

Status: abandoned
Slice: 5
Blocked by: —

## 结论

**未完成，已回滚。** `scripts\validate_combat_timeline.ps1` 移植稿已按用户指示删除。
`scripts\` 恢复为 6 个原有脚本；Python 原版
`skills\naraka-highlight-studio\scripts\validate_combat_timeline.py`（7956B）**自始至终未被改动**。

不做此移植不等于质检缺口已解决——**缺口仍然存在**，见文末「遗留影响」。

## 做过什么

1. 读了 Python 原版（171 行）并逐条对照，列出移植必须补齐的 5 处差异：
   - `--proxy-map` 代理偏移检查（原任务 13 手写版缺失）
   - `start`/`end` 字段回退（原手写版缺失，只能应付单一数据形态）
   - 逐条 try/except 语义（坏数据应产出该项 `pass=false + detail`，而非整体中断）
   - `deleted_intervals` 元素非对象的显式判定
   - 时间线解析失败时仍产出 `load_timeline` 失败报告
2. 从 Python 源重写移植版，**没有**直接捡用任务 13 的 `cache\validate_ps1.ps1`（该稿对任务 13 的数据形态够用，但对其他任务不等价，属一次性产物）。
3. 建立黄金参照对账机制：任务 12/13/14/15 在 Python 尚可用时真跑出的 9 份 `validate_v*.json`
   （覆盖 5 种数据形态：episode 数 20/11/10/9），对同一份 timeline 重跑移植版逐字段比对。
4. 移植版在实跑中崩溃，**未通过任何一次验证**，因此按用户指示回滚。

## 两个有价值的发现（保留，避免重复踩坑）

### 发现 1：`.ps1` 必须存为 UTF-8 with BOM

无 BOM 的 UTF-8 `.ps1` 在 Windows PowerShell 5.1 下按 ANSI 读取，中文全部乱码，
直接导致**解析错误**（报「字符串缺少终止符」之类）。

本项目 `docs\TROUBLESHOOTING.md` 早已记录过这条（「832 v2 修复沉淀」），本次又犯了一次。
写任何含中文的 `.ps1` 后必须转 BOM：

```powershell
$c = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($f, $c, (New-Object System.Text.UTF8Encoding($true)))
```

注意：`edit` / `write` 工具写回文件时**不带 BOM**，改完要重新转。
纯 ASCII 的 `.ps1`（如 `check_video_environment.ps1`）不受影响，可不转。

### 发现 2：PowerShell 5.1 下 `List[object]` 经 `@()` 塞进哈希表会抛类型不匹配

症状：对 `[ordered]@{}` 赋值时报 `参数类型不匹配`（ParameterBindingException），
**报错行指向哈希表字面量，看起来完全无辜**，极易误判为参数绑定问题而查错方向。

隔离实验结论（`dbg_construct.ps1` 实测）：

| 构造方式 | 结果 |
|---|---|
| `List[object]` + `@($list)` | **失败**（`参数类型不匹配`） |
| 纯数组 `@() ; += item` | 正常 |
| `ArrayList` + `@($list.ToArray())` | 正常 |
| 内联数组字面量 `@(@{...}, @{...})` | 正常 |

**可用写法**：`New-Object System.Collections.ArrayList` + `[void]$list.Add(...)`
+ `@($list.ToArray())`。`ArrayList.Add` 返回索引，必须用 `[void]` 抑制输出。

另：PowerShell 5.1 的 `ConvertTo-Json` 对**单元素数组**会退化成对象而非数组，
序列化结果需用 `@(...)` 显式强制。

## 遗留影响（重要）

**质检缺口依然存在。** 粗剪流程中这三项能力目前不可用：

| skill 脚本 | 作用 | 当前状态 |
|---|---|---|
| `validate_combat_timeline.py` | 战斗边界重叠/缝隙/删除段审计 | 不可运行 |
| `qa_gate.py` | 十二道质量门禁，FAIL 即不许冻结 | 不可运行 |
| `validate_delivery.py` | 交付前体检 | 不可运行 |

后果：按 `docs\粗剪提示词.md` 执行粗剪时，流程走到「跑校验」「过门禁」会受阻，
工作窗口只能临场用 PowerShell 自编替代品（任务 12/13 曾如此），
或跳过门禁直接交付——后者会削弱交付可信度。

## 三个选项留待将来

- **甲**：授权修复 Python（详见 `docs\PYTHON_RUNTIME_DECISION.md`）。
- **乙**：重做移植，但要**先解决上述两个坑**（BOM + ArrayList），并**必须跑通 9 份黄金对账**才算完成。
  本次的失败点在于：移植稿在未验证状态下就留在 `scripts\` 下，存在被其他窗口误用的风险——
  重做时应先在 `.scratch` 内验证通过，再移入 `scripts\`。
- **丙**：接受缺口，在粗剪提示词里明确「门禁降级、如实标注」，不假装完整通过。
