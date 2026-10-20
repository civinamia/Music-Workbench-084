# 字幕工作台

> **给后续 agent / 二次开发**：动代码前先读 [AGENTS.md](AGENTS.md)——里面有架构、视图契约、
> 10 条「碰了就坏」的约束和调试命令。本文件只讲怎么用。

把网易云正在放的那首歌，按《边狱巴士》战斗里那种**金色字幕**铺在屏幕上。两套风格，随时切换。

桌面设置窗口已重做为 **Lens 风格的字幕工作台**：浅色冷灰界面、柔光玻璃预览、紧凑属性面板。可以直接调整字体、字号、颜色和动画，设置实时生效、自动保存。

![Lens 字幕工作台](preview/presets/desktop.png)

设计参考：[Lens / design-systems](https://ruiqichenbiec.github.io/design-systems/)。预览场景使用本地 QPainter 矢量绘制，不依赖网页或持续运行的 WebGL；柔光/暗色场景只影响示例预览，不改变桌面歌词设置。

| 散落逐字（默认） | 整句滑动 |
| --- | --- |
| ![散落](preview/verification/scatter/scatter.png) | ![整句](preview/verification/line/01_line.png) |

- **散落逐字**：每句丢到屏幕上一个随机位置、随机倾斜 ±10°，字符按 0.1s 间隔逐字蹦出，
  每个字每 143ms 抖一下，默认严格只显示当前一句。风格来自 [LKornway/LimbuslikeLrc](https://github.com/LKornway/LimbuslikeLrc)。
- **整句滑动**：按游戏实机做的——一屏一句、上方三分之一居中、金色渐变+泛光+投影，
  旧句左滑出、新句右滑入，长句直接溢出裁掉。

## 切换方式

预览下方的“字幕配色”提供 8 套完整搭配：原始金色、冷白极简、暮色紫、海盐蓝、薄荷青、樱花粉、落日杏和黑白映画。每套同时包含散落字幕文字/落影，以及整句字幕上中下渐变/泛光颜色。
点击 **恢复原配色** 可准确找回最初的暖白字＋金色落影，不影响字体、字号、双语、描边或时间校准。自定义颜色后会显示“自定义配色”；重新打开仍能识别当前匹配的预设。

程序目录的 `config.json` 保存个人设置，`color_presets.json` 可编辑另外 7 套配色（重启后读取），原始金色始终内置。`ui_assets` 放大肥鱼图标，`_internal` 放运行依赖；移动时请保留整个文件夹。

开发者从源码运行需要 Python 和 `requirements.txt` 内的依赖。重新打包：安装 `PyInstaller` 后运行 `python build_windows.py`，输出为文件夹版程序；构建会保留已有发行目录里的个人配置。

两种都行，立刻生效：

1. **托盘图标右键 → 切换渲染风格**（会顺手写回 `config.json`）；
2. 改 `config.json` 里的 `"style"`：`"scatter"` 或 `"line"`，保存后自动热重载。

## 快速开始

1. 便携程序在 **`../字幕工作台/`**，整个文件夹可复制到其他位置，无需安装 Python。
2. 双击其中的 **`字幕工作台.exe`**。项目根目录的 `启动字幕.bat` 也会优先打开它。
   会打开字幕工作台；关闭窗口后字幕继续运行。双击托盘图标或再次双击启动脚本可重新打开工作台。
3. 在网易云里放歌，字幕自动出现；托盘图标可显示/隐藏、切风格、重载歌词、退出。
4. 想先看效果：双击 **`预览效果.bat`**（示例句子循环，不需要放歌）。
5. 想看某首歌的真实歌词效果（不用播放）：
   ```
   python main.py --preview              # 当前网易云里那首
   python main.py --preview 2023212662   # 指定歌曲 id
   ```
6. 出问题双击 **`诊断.bat`**。

## 字幕工作台

- **外观与字幕**：切换散落/整句风格，选择系统字体、字号、字重、字距、文字颜色、渐变、落影或泛光、不透明度；设置双语开关、译文字号和原译文间距。
- **布局与动画**：散落模式可选随机/上方/居中/下方位置、行宽、同屏句数、倾斜、抖动、逐字速度和淡出；整句模式可调垂直位置、滑动速度与距离、淡出和泛光。
- **播放与同步**：精确校准提前/延后时间，调整暂停隐藏、其他播放器和启动时是否打开窗口。
- **左侧预览**：嵌入实际字幕渲染器，用可编辑的示例原文和译文放大展示效果，支持柔光/暗色背景和重播动画；不会在桌面再生成一套字幕。随机散落模式在此居中展示样式，实际桌面仍按原设置随机出现。
- **配色和备份**：八种配色预设、一键恢复原配色、设置导入/导出、按页恢复默认。修改后自动写入当前配置文件，不需要点击保存。
- **当前歌曲**：显示歌曲、播放进度、原文及译文句数，可重新获取歌词、显示/隐藏桌面字幕。

顶部切换外观、布局和同步，右侧统一调整属性；1120×760 小窗口下保持预览和输入区独立，属性区可滚动。

描边默认关闭，原文与译文默认同时显示。窗口右下角的「退出程序」会关闭字幕；「收起到托盘」保留后台运行。

想直接后台启动：`pythonw main.py --background`。工作台关闭后也可从托盘菜单「打开字幕工作台」进入。

## 文件

```
limbus-lyric-overlay/
├─ 启动字幕.bat / 预览效果.bat / 诊断.bat
├─ main.py          入口：播放状态、歌词调度、托盘、风格切换
├─ settings_ui.py   设置工作台、嵌入式实时预览、设置导入导出
├─ ui_assets/       工作台界面资源
├─ overlay.py       两套渲染器：SubtitleView（整句）/ ScatterView（散落）
├─ lyrics.py        网易云歌词：按 id 或按歌名+歌手匹配，LRC 解析
├─ netease_elog.py  从 cloudmusic.elog 读歌曲 id / 播放状态 / 进度
├─ smtc_bridge.ps1  Windows 媒体会话（给非网易云的播放器兜底）
├─ config.json      全部参数，改完自动热重载
├─ overlay.log      运行日志
└─ preview/         效果图
```

## 配置

### 通用

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `style` | `scatter` | `scatter` 散落逐字 / `line` 整句滑动 |
| `offset_sec` | `0.0` | 整体时间偏移，正数=字幕提前 |
| `hide_on_pause` | `true` | 暂停时隐藏 |
| `netease_elog` | `true` | 用网易云本地日志取歌曲 id 与播放状态 |
| `prefer_app` | `cloudmusic`… | 多个播放器同时在响时优先谁 |
| `debug` | `false` | 日志每 3 秒打印同步状态 |
| `show_translation` | `true` | 同时显示原文与网易云提供的译文；没有译文时只显示原文 |
| `translation_scale` | `0.55` | 译文字号相对原文的比例，两种风格均生效 |
| `translation_gap` | `10` | 原文与译文间距（像素） |
| `opacity` | `1.0` | 字幕不透明度，工作台使用百分比显示 |
| `settings_on_start` | `true` | 启动时打开设置工作台；`--background` 可临时跳过 |

### 散落逐字（`scatter_*`）

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `scatter_font_size` | `36` | 字号（1080p 基准，自动缩放） |
| `scatter_font_family` | `Microsoft YaHei UI` | 字体 |
| `scatter_font_weight` | `bold` | 字重，`normal` / `bold` |
| `scatter_position` | `random` | 字幕出现位置，`random` / `top` / `center` / `bottom` |
| `scatter_char_spacing` | `5` | 字距 |
| `scatter_char_interval` | `0.10` | 逐字出现间隔上限（秒），短句会按歌词时长加快；跳转后按当前进度恢复 |
| `scatter_angle_min/max` | `-10 / 10` | 每句的随机倾斜角度 |
| `scatter_shake` | `2` | 抖动幅度（像素） |
| `scatter_shake_interval` | `143` | 抖动重定向间隔（毫秒） |
| `scatter_shake_follow` | `0.3` | 抖动跟随系数（越大越跳） |
| `scatter_lifetime` | `9.0` | 无歌词时间轴时的单句寿命；正常播放按歌词结束时间淡出 |
| `scatter_overlap` | `0.3` | 多句模式中新句出现后旧句继续保留多久；单句模式直接替换 |
| `scatter_fade` | `0.35` | 淡出时长 |
| `scatter_max_lines` | `1` | 同屏最多几句。**默认 1 = 一句一条**；调到 3–5 就是那个仓库的堆叠效果 |
| `scatter_text_color` / `scatter_shadow_color` | `#FFFEEF` / `#D8A523` | 字色 / 金色落影 |
| `scatter_shadow_dx/dy` | `3 / 3` | 落影偏移 |
| `scatter_outline_width` | `0.0` | 描边粗细，默认关闭；需要时可设为正数 |
| `scatter_outline_color/alpha` | `#0B0B10` / `0.85` | 描边颜色与不透明度 |

### 整句滑动（`line` 模式）

| 键 | 默认 | 说明 |
| --- | --- | --- |
| `baseline` | `0.255` | 基线位置（屏高比例） |
| `font_size` / `font_family` | `72` / `Source Han Sans Heavy` | 字号、字体 |
| `text_color_top/mid/bottom` | 白→浅金→金 | 竖向渐变 |
| `glow_radius` / `glow_strength` | `16` / `1.08` | 金色泛光 |
| `slide_ms` / `slide_ratio` | `950` / `0.45` | 换句滑动时长与距离 |
| `fade_out_ms` | `420` | 句尾淡出 |

## 它是怎么知道在放哪首歌的

1. **网易云自己的日志**（`%LOCALAPPDATA%\NetEase\CloudMusic\cloudmusic.elog`）
   - 客户端 3.x **不上报** Windows 媒体会话，所以 SMTC 抓不到网易云；
   - 日志里逐条记录了真实 `songId`、播放/暂停（`native播放state`）、拖动位置（`setPlayingPosition`）；
   - 按 id 直接取歌词，**不会匹配到翻唱**，也不用靠歌名猜。
2. **SMTC 兜底**：其他播放器（QQ 音乐、酷狗、浏览器）通过 Windows 媒体会话读取，进度按时间线的 `LastUpdatedTime` 插值，支持播放器不持续更新进度的情况（[微软接口说明](https://learn.microsoft.com/en-us/uwp/api/windows.media.control.globalsystemmediatransportcontrolssessiontimelineproperties)）。
3. **歌词**：网易云官方接口的 LRC（含翻译轨），只在本机内存里解析，不落盘。

双语字幕的原文在上，较小的译文在下。散落模式的两行共用位置、倾斜角度和显示时间，作为一组替换，
不会挤占两句字幕名额。译文较长时自动换行；没有官方译文时只显示原文，不会生成机器翻译。

## 常见问题

**感觉字幕比网易云面板快/慢一点？**
托盘右键有「时间校准」：**字幕提前 0.2s / 字幕延后 0.2s**，点几下对到你耳朵满意为止，
会自动写回 `config.json` 的 `offset_sec`（正值=提前）。也可以直接改这个值，热重载生效。
另外程序会自动跳过歌词文件开头的「作词/作曲/编曲」署名行和「纯音乐请欣赏」提示。

**放歌了但没字幕？**
- 先跑 `诊断.bat`：`sessions` 里有没有 `cloudmusic.elog` 那条？`status` 是不是 `Playing`？
- 日志（`overlay.log`）里 `track:` 后面有没有 `-> id …`；`lyrics:` 有没有行数；
- 纯音乐、播客、无版权歌曲没有歌词，属正常；
- 全屏**独占**游戏里悬浮窗不显示，改成无边框窗口/窗口化全屏。

**字看起来怪、笔画糊在一起？** 别用可变字体（如 `Noto Sans SC`）配 `font_weight: "black"`，
Qt5 对这种组合的轮廓实例化会出错；用静态字重的 `Source Han Sans Heavy/Bold`。

**散落模式字太多挡住画面？** 默认已经是「一句一条」（`scatter_max_lines: 1`）；
想要那个仓库的堆叠效果，把它调到 3–5；嫌字大就把 `scatter_font_size` 降到 30。

## 同步与重影修复（2026-10-20）

- 日志首次读取历史，此后只读新增字节，避免旧的切歌/拖动事件反复重置进度；支持半行写入、日志截断和替换。
- 暂停、切歌、隐藏和拖动进度会清除旧字幕；恢复时按当前歌词位置显示，最后一帧淡出后刷新透明背景。
- 默认单句模式不再保留旧句的淡出层；预览和正式播放共用单实例锁，避免多个字幕窗口同时运行。
- 歌曲优先按真实 ID 识别，旧异步请求不能覆盖新歌曲；已知 ID 无歌词时不改用其他版本。修正 LRC 小数精度并保留空白时间标记。

修改代码后可运行：

```powershell
python -m unittest discover -s tests -v
python tests/integration_smoke.py
```

第一项检查日志、时间轴和两套渲染器；第二项在离屏 Qt 窗口中检查切歌请求竞争、暂停恢复、托盘显隐、风格热重载、校准保存和单实例锁。实际歌曲仍可用托盘的 ±0.2s 校准微调。

## 参考与致谢

- 整句滑动的视觉：《边狱巴士》9-50 战斗实机录像。
- 散落逐字的算法（随机位置/倾斜、逐字、抖动、金色落影）与网易云 `elog` 取 id 的思路：
  [LKornway/LimbuslikeLrc](https://github.com/LKornway/LimbuslikeLrc)（MIT），本项目为独立实现。
- 歌词来自网易云音乐官方接口，仅用于本机显示；请支持正版。
