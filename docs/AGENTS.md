# AGENTS.md —— 给后续 agent 的技术交接

> 这份文档面向「下一个要改这个项目的 agent」，讲**为什么这么写**、**哪些地方碰了就坏**、**怎么验证**。
> 面向使用者的说明在 [README.md](README.md)，配置项含义也在那里，这里不重复。

---

## 1. 项目一句话

Windows 上的桌面歌词悬浮层：读网易云正在播的歌（歌曲 id / 进度 / 播放状态），
用《边狱巴士》风格把当前歌词句画在全屏透明、置顶、鼠标穿透的窗口上。两套渲染风格可热切换。

- 目录：`A:\agent\084图示\limbus-lyric-overlay\`
- 入口：`main.py`；启动脚本 `启动字幕.bat`（pythonw 无控制台）
- 当前默认风格：`scatter`（散落逐字）；`line`（整句滑动）为另一套

## 2. 运行环境（实测）

| 项 | 值 |
| --- | --- |
| OS | Windows 10/11 中文，1920×1080，系统缩放 125%（120 DPI） |
| Python | 3.14.6，路径 `W:\python.exe`（`pythonw.exe` 同目录） |
| 依赖 | PyQt5 5.15.11、Pillow 12.3、requests、numpy（都已装好，requirements 未写死） |
| 网易云 | 3.1.41，桌面版，`%LOCALAPPDATA%\NetEase\CloudMusic\` |

## 3. 数据流

```
cloudmusic.elog ──(decode+事件解析)──> ElogWatcher ─┐
                                                    ├─> pick_session() ─> tick() ─> view.set_line()/on_gap()
SMTC (smtc_bridge.ps1, 子进程) ──> SmtcBridge ──────┘                        │
                                                                             ├─> Lyrics.index_at(pos)
网易云歌词接口 (lyrics.py: by_id / lookup) ──> Lyrics(行列表) ───────────────┘
```

- **身份**：elog 给出真实 `songId` → `NeteaseLyrics.by_id()` 直接取歌词，不做搜索匹配。
- **进度**：elog 的 `setPlayingPosition` / `native播放state` 作为锚点，增量事件按轮询时刻、
  历史事件按日志时间戳（见第 11 条），随后用时钟插值；SMTC 会话则用 `Position` + 本地时钟插值。
- **歌词**：官方 LRC（含翻译轨），内存解析，不落盘；前 10 行里的「作词/作曲/编曲…」署名行
  和「纯音乐，请欣赏」之类的提示会被 `lyrics._clean_lines()` 丢掉，不当作字幕唱。
- **调度**：Qt 20ms `QTimer` → `tick()`：更新 cfg 热重载、收歌词线程结果、算 `pos`，
  由 `sync.LyricSync.present()` 识别歌词变化/跳转，调用 `view.set_line()` / `view.on_gap()`。
  `view.animate()` 每 tick 推进，包含最后清屏帧。

线程模型：`SmtcBridge` 读子进程 stdout 的线程、`ElogWatcher` 轮询线程、每次换歌一个歌词解析线程
（结果经 `queue.Queue` 回主线程）。**所有 QWidget 操作只在主线程**。

## 4. 文件与关键符号

| 文件 | 关键符号 | 职责 |
| --- | --- | --- |
| `main.py` | `run` / `build_view` / `tick` / `set_track` / `resolve` / `switch_style` / `pick_session` / `dump` / `match` | 装配、调度、托盘 |
| `overlay.py` | `SubtitleView`（整句）、`ScatterView`（散落）、`demo_snapshot` | 渲染 |
| `sync.py` | `LyricSync`（`present` / `reset`） | 按播放进度调度、拖动检测、动画年龄 |
| `settings_ui.py` | `SettingsWindow` / `PreviewCanvas` / `ColorButton` | 原生桌面设置窗口及嵌入式字幕预览 |
| `lyrics.py` | `NeteaseLyrics`（`by_id` / `lookup` / `song_meta`）、`parse_lrc`、`Lyrics.index_at` | 歌词 |
| `netease_elog.py` | `decode`、`ElogWatcher`（`_scan` / `position` / `as_session`） | 播放状态 |
| `smtc_bridge.ps1` | — | 用 WinRT 读 SMTC，每 `poll_ms` 打一行 JSON |

定位符号用 `grep -n "class ScatterView" overlay.py` 这类方式，**不要依赖行号**（会漂）。

### 视图契约（两套渲染都必须实现，`tick()` 依赖它）

```python
set_line(text, tl="", instant=False, elapsed=0.0, duration=None)  # elapsed/duration 为歌词时间
clear(instant=False)                   # 普通淡出；instant=True 立即清除所有层及去重状态
on_gap()                               # 句间空白：整句模式清屏，散落模式不动
animate() -> bool                      # 推进动画；返回是否需要重绘
reload_cfg(cfg)                        # 配置热重载（会重建几何）
show_idle(visible)                     # 需要时 show()
```

`on_gap()` 和 `clear()` **必须分开**：散落模式靠前者让旧句自然活到自己寿命，否则每句之间会被清空，
永远只有一句在屏幕上（这个 bug 调过）。

**散落模式的默认是严格「一句一条」**：`scatter_max_lines = 1`，新句出现时旧句直接移除，
不保留淡出层（2026-10-20 修复重影）。`scatter_overlap` 只在把 max_lines 调大时才有意义。
早期版本沿用参考仓库的 5 句堆叠 + 9s 寿命，用户第一反应是「怎么一堆字幕」，所以改成单句。
`set_line()` 里还有一道去重：同一文本若 0.6s 内已在屏上，不再重复生成（防止进度在行边界抖动时叠字）。

## 5. 不可破坏的约束（踩过的坑）

1. **DPI**：`run()` 一开始必须调 `_physical_pixels()`（`SetProcessDpiAwareness(2)`）并设
   `Qt.AA_DisableHighDpiScaling`。否则窗口被系统按 125% 拉伸，字号/位置全偏，字还会糊。
2. **字体**：Qt5 + **可变字体**（如 `Noto Sans SC`）配 `font_weight: "black"` 会错误实例化轮廓，
   笔画缺失、粘连。整句模式用静态字重的 `Source Han Sans Heavy`；散落模式 `Microsoft YaHei UI` + Bold。
3. **散落模式的字距只能加一次**：`ScatterView._font()` 里**不要**再 `setLetterSpacing`，
   字距由 `_spawn()` 推进 `cursor` 时加（否则间距翻倍）。
3b. **按用户 2026-10-20 的明确偏好，散落字幕默认关闭描边**（`scatter_outline_width: 0.0`），
   保留金色落影。不要因为亮背景可读性而擅自重新开启；用户认为无描边更好看。
   `scatter_outline_*` 仅保留为可选配置。
4. **config.json 可能带 BOM**：PowerShell `Set-Content -Encoding UTF8` 会写 BOM；
   `load_cfg` 用 `utf-8-sig` 读，程序自己保存时用 `utf-8`（无 BOM）。
5. **QImage 生命周期**：`pil_to_qimage()` 从 bytes 构造 QImage，必须把 bytes 存进 `LineArt._keep`，
   否则图像数据被回收（花屏/崩溃）。
6. **窗口标志**（实测 `0x800A8`）：`Frameless | StaysOnTop | Tool | TransparentForInput | DoesNotAcceptFocus`
   + `WA_TranslucentBackground` + `WA_ShowWithoutActivating` + `WA_TransparentForMouseEvents`。
   改动后要重新验证：置顶、鼠标穿透、不抢焦点、不进 Alt+Tab。
7. **强制重发当前句用 `sync.reset()`**（已替代旧 `state["idx"] = -2` 约定）：同时清层与去重状态。
   暂停/隐藏后恢复，即使还是同一行也必须重新发；拖动到同一行内部也要按新 elapsed 重建动画。
8. **`pick_session` 排序**：偏好且正在播 > 任意正在播（`allow_other_players`）> 偏好但暂停。
   网易云 3.x **不上报 SMTC**，所以 elog 会话带 `app="cloudmusic.elog"` 参与同一套排序。
9. **elog 首次扫描读全文件**（可能 8MB+），之后从上次字节偏移读取新增部分。
   绝不能把旧尾部重复作为 live 事件扫描，否则每次无关日志写入都会把旧 seek/load 重新锚定到现在。
   半行要缓存并在 UTF-8 解码前拼接；截断/文件标识变化时重建历史。历史事件按秒级
   时间戳 +0.5s 居中，新增事件按轮询时刻锚定，两者不可混用。
10. **散落模式的 `_spawn(..., apply_overlap=False)`** 只给截图用；正常运行必须走默认重叠逻辑。
11. **elog 的时间锚点**：日志行头 `[YYYY-MM-DD HH:MM:SS]` 只有秒精度，直接拿它当锚点会让进度
    最多提前近 1 秒（表现为「字幕抢拍」）。`_event_time()` 的做法是：增量读到的新事件按**轮询时刻**
    锚定（减半个 `poll_ms` 补偿写入延迟），只有首次全量扫描用「时间戳 + 0.5s」居中。
    不要为了「简单」改回纯 `_stamp()`。
12. **用户可调的 `offset_sec`**：正值=字幕提前，负值=延后；托盘有「提前/延后 0.2s」按钮并写回配置。
    它同时作用于实时播放和 `--preview`。按钮文案必须写清「更早出现 / 更晚出现」——用户很容易
    把「提前」理解成「等我一下」，结果越点越偏（真实发生过：连点三次 +0.6s，然后说完全对不上）。
13. **视图契约要在运行时兜底**：`tick()` 直接调 `view.on_gap()`，两套渲染**都必须实现**。
    曾经 `ScatterView` 漏了 `on_gap`，结果每句之间的空隙都抛 `AttributeError`、该帧后续的
    `animate()` 被跳过，表现成「字幕乱跳/完全对不上」。新增方法后先跑：
    `python -c "..."` 对两个类各调一遍 `on_gap/clear/set_line/animate/reload_cfg`（见第 7 节）。

## 6. 加第三套渲染风格

1. 在 `overlay.py` 写一个 `QWidget`，实现第 4 节那六个方法（几何自定，全屏或条带都行）。
2. `main.py`：`build_view()` 里按 `cfg["style"]` 分支加一行；托盘「切换渲染风格」的
   `style_label()` / `switch_style()` 目前是二选一，改成循环列表即可。
3. `config.json` + `DEFAULT_CFG` 加该风格的 `前缀_*` 参数；`demo_snapshot()` 里按风格分支出预览图。
4. 跑一遍第 7 节的验证。

## 7. 调试与验证（都用 PowerShell，在项目目录下）

```powershell
# 1) 静态检查
python -m py_compile main.py overlay.py lyrics.py netease_elog.py sync.py
python -m unittest discover -s tests -v
python tests/integration_smoke.py

# 2) 现在到底看到了什么（SMTC 会话 + elog 会话 + 选中项 + 歌词匹配）
python main.py --dump

# 3) 某首歌能不能匹配到歌词
python main.py --match "Between Two Worlds" "Mili"

# 4) 不放歌预览某首歌的真实歌词（合成时钟，1x 速度从头放）
python main.py --preview              # 当前网易云那首
python main.py --preview <songId>

# 5) 出预览图（按 config 里的 style）
python main.py --snapshot preview
#    line 模式预览：复制 config.json 改成 "style": "line" 作为临时 --config 传入

# 6) 跑起来看日志/资源
Start-Process python -ArgumentList "main.py" ; Get-Content overlay.log -Encoding UTF8 -Tail 20

# 7) 真实桌面截图验证（会短暂盖住屏幕）
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
$g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size)
$bmp.Save("$PWD\shot.png");$g.Dispose();$bmp.Dispose()
```

已验证过的：两套 `--snapshot` 渲染、`--preview` 真实歌词（曲目 id 2023212662，36 行）、
elog 取到 id/进度/暂停态、进度与墙钟 1:1（连测 3s 走了 3.00s）、署名行过滤
（Rendezvous 49→47 行，首句从 0.0s 的「作词」变成 9.29s 的正词）、窗口 ex-style、
`--dump`/`--match`、单实例锁（端口 59771）。
2026-10-20 补充：39 项离线回归及 `tests/integration_smoke.py` 已通过；后者运行真实 Qt 事件循环、
触发托盘 QAction，覆盖同标题不同 ID、A→B→A 旧请求竞争、暂停恢复、显隐、隐藏时风格热重载、
自定义配置的校准保存、按原 ID 重载、demo 与正式播放互斥，以及两种风格切换后译文仍显示。
测试播放器/API 使用可控 fixture。双语专测覆盖同组首尾同步、译文换行、开关及缺失处理、
只改译文时的去重和整句渲染实际像素。设置测试还覆盖批量保存、字体分风格保留、导入校验、
导出、嵌入预览、关闭时刷新、原子保存失败；集成测试验证工作台修改传入实际悬浮层和文件，
关闭窗口保留悬浮层，第二次启动唤起已有窗口。集成测试使用独立临时端口，不影响正在运行的程序。
**已知做不到的验证**：没法把网易云面板逐像素对拍——`PrintWindow` 抓 `OrpheusBrowserHost` 只拿到
一个 199×34 的辅助窗口（UI 是多进程 CEF，真正的画面不在顶层窗口里）。所以亚秒级对齐只能靠
托盘「提前/延后 0.2s」人工校准，别在这上面继续折腾截图。

## 8. 已知缺口 / TODO

### Windows 文件夹版发行（2026-10-20）

- `python build_windows.py` 用 PyInstaller 6.21 / Python 3.14 构建 `../字幕工作台/字幕工作台.exe`。
  它是 onedir 无控制台程序，`_internal` 是依赖目录；不得擅自改为单文件打包。
- `app_paths.APP_DIR` 在冻结状态指 EXE 所在文件夹，源码状态指项目目录；配置、日志写入此处。
  `resource_path()` 先找 EXE 旁资源，再找包内资源，SMTC 脚本实际从 `_internal` 读取。
  不要把配置写进 `_internal`，也不要依赖启动工作目录。构建先在 `build/portable` 暂存后复制，
  保留已有发行目录中的 config.json / color_presets.json / overlay.log。
- `palettes.py` 锁定原始 6 个颜色字段，其中整句 glow_color 为 #FFD27A（不是散落落影 #D8A523）。
  另外 7 套在 color_presets.json；只有颜色受预设影响，禁止改字号、字体、校准、双语或描边。
  选中状态按实际颜色推断，手动改色显示自定义；恢复按钮始终可用，即使外部预设文件损坏。
- 大肥鱼图标位于 ui_assets/dafeiyu.png / .ico，包含 16–256 的 7 个尺寸。
  统一用于标题、窗口、托盘、EXE 资源；Windows AppUserModelID 为 SubtitleWorkbench.Desktop。
  图像生成记录在 ui_assets/dafeiyu.prompt.md。新的实际窗口证据见 preview/presets/。

- 两套渲染器均支持双语，默认 `show_translation: true`，原文在上、译文在下，
  译文字号由 `translation_scale` 控制。散落原译文在同一个 `_ScatterLine` 内，共用起止和倾斜，
  逐字首尾同步；不应把译文当第二句生成，否则单句上限会误删原文。没有译文时只显示原文。
- 歌词缓存只在内存，重启要重新拉。
- 只有主屏；多显示器未做选择。
- 已有原生设置窗口，启动默认打开，关闭后保留托盘。手动编辑 `config.json` 仍支持热重载。
- `cloudmusic.elog` 的事件标记与客户端版本强相关（3.1.41 实测）；升级客户端后若 `--dump`
  里 elog 会话消失，先看 `netease_elog.MARK_*` 是否还匹配，用第 7 节的解码思路复查。
- 无版权/纯音乐/播客：`matched: none` 属正常，不要当 bug。
- SMTC 会话的 `pos` 精度依赖播放器上报。`timeline_t` 是 `LastUpdatedTime`，允许长时间插值；
  不提供该值的源仅按快照时间插值 5s。不要每轮用快照时间覆盖时间线更新时间。

### 2026-10-20 同步修复的补充约束

- 已知 song ID 作为歌曲 key 优先于标题；请求携带递增 generation，只有 key 和 generation
  同时匹配才接收结果，防止 A→B→A 时第一次 A 的旧结果覆盖新 A。已知 ID 无歌词不搜索其他版本。
- 散落动画的 start = monotonic - elapsed；提供 duration 时按歌词结束时间淡出，逐字间隔压缩至该时长内。
  LRC 明确的空白时间戳终止前句，不能在解析时直接丢掉；一位小数 `.5` 是半秒。
- 配置热重载改变 style 要重建视图，普通 reload_cfg 不能换类；隐藏状态下不能把新视图 show 出来。
- 预览与正式播放使用同一端口锁，只有静态 snapshot 不占锁；防止 demo 在正式字幕上再叠一套。
- Qt 最后移除图层的那一帧仍要 update；仅在还有存活图层时 update 会留下透明窗残影。

### 字幕工作台的约束

- 用户明确否定旧的深灰卡片外观，选择 [Lens](https://ruiqichenbiec.github.io/design-systems/)。
  当前视觉规范见 `DESIGN.md` 和 `.impeccable/design.json`，界面证据在 `preview/lens/`。
  保持浅色冷灰外壳、左侧大预览/播放信息、右侧紧凑属性栏、顶部分类；不要擅自恢复旧深色侧栏。
- 预览的光学背景是按尺寸缓存的 QImage，由 QPainter 矢量绘制；重绘不能每帧重建背景。
  柔光/暗色选择仅影响预览。随机散落在预览中居中展示，实际配置不被改变。

- `SettingsWindow.settingsChanged` 发送修改过的字段，160ms 合并；`main.apply_settings()` 统一更新渲染、
  托盘文案、窗口控件及配置，外部热重载/托盘变化经 `sync_config()` 同步且必须阻断控件信号，避免保存循环。
- `write_cfg()` 在同目录创建临时文件并 `os.replace()`，失败时保留旧配置；保存目标始终为 `args.config`。
- 预览通过 `ScatterView/SubtitleView(cfg, parent=..., preview=True)` 嵌入，必须是普通子控件，不能带置顶窗口标志，
  不能用透明 Source 清除父控件背景。预览以 2 倍比例放大方便观察，原生悬浮层仍保持原 DPI 逻辑。
- 原文/译文始终共用同一个渲染组；窗口改动不能恢复默认描边、重置时间校准或改变另一风格的字体设置。
- `--background` 临时跳过主窗口；`settings_on_start` 为持久偏好。关闭窗口仅隐藏；退出按钮/托盘退出结束程序。
- 单实例端口现在同时用于唤起主窗口，tick 非阻塞 accept；重复启动只通知已有实例，不创建第二套字幕。

## 9. 关于「直接抓网易云自己的字幕」（已逐条验证，别再重复试）

想法很好：直接读客户端当前高亮的那行，就不存在对时问题。但 3.1.41 上四条路全不通：

| 途径 | 结果 |
| --- | --- |
| CDP / `--remote-debugging-port` | 客户端没开；本机 9222 是 **Edge** 的调试口，不是网易云 |
| UI Automation | `AutomationElement.FromHandle(OrpheusBrowserHost)` 与 `Chrome_RenderWidgetHostHWND` 的 Text 后代都是 **0**（CEF 未启用 accessibility） |
| 带 `--force-renderer-accessibility` 重启 | 试过了：MSAA 能读到窗口按钮（minimize/close/play…）和一条 `播放进度调节` 滑块，但**歌词文本不在可访问性树里**（应为 canvas 绘制），滑块 `accValue` 也是空——“读面板”这条路仍然不通 |
| MSAA（oleacc `AccessibleObjectFromWindow`） | 渲染窗层级不稳定，且受同一个 accessibility 开关限制 |
| `PrintWindow` 抓窗口 | 只能拿到一个 **199×34** 的辅助窗；主画面是多进程 D3D 合成，不在顶层窗口里 |
| 本地 `127.0.0.1:20017` | 能连上但**不是 HTTP**（请求挂起），是 CEF↔原生的私有通道 |

剩下**唯一**没试的是截图 + `Windows.Media.Ocr`（zh-Hans）识别，用「面板中心那一行 + 与 LRC
模糊匹配」定位：不动客户端，但 2–4 fps、中文可能认错字，收益不确定，未实现。

参考仓库（LimbuslikeLrc）本身也**没有**抓面板：它的 `core/Cloudmusic/netease_source.py` 走
`api/search/get` + `fetch_lyrics_by_id` + 解析 YRC/LRC，播放状态来自 `cloudmusic.elog`——
和本项目同一套思路，只是它自己渲染。所以“抓网易云字幕”没有现成实现可抄。

现状选择的折中：**用时钟对时**（第 11 条已把系统偏差压到约 ±125ms），再给用户 ±0.2s 手动校准。

## 10. 归属

- 整句滑动的视觉参考《边狱巴士》9-50 实机；
- 散落逐字算法与 `elog` 取 id 的思路来自 [LKornway/LimbuslikeLrc](https://github.com/LKornway/LimbuslikeLrc)（MIT），
  本项目为独立实现，非复制代码；
- 歌词来自网易云官方接口，仅本机显示。
