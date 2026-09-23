# TranslateDot

<div align="center">

**轻量、完全本地的 macOS 划词与截图翻译工具**

在任意应用中选中文本，译文即刻显示在选区旁的悬浮面板中。

简体中文 · [English](README.en.md)

</div>

---

## 概述

TranslateDot 是一款原生 macOS 菜单栏应用。它通过 Accessibility API 读取当前应用中的选中文本，调用 Apple Translation framework 在本机完成翻译，并以非激活式悬浮面板呈现结果——全程不打断当前工作流，不依赖任何云端翻译服务。

核心链路：**选中文本或框选屏幕区域 → 按快捷键 → 本地识别与翻译 → 悬浮显示**。

<!-- 截图占位：完成签名并授权辅助功能后，将浅色/深色模式截图放入 docs/screenshots/ 并在此引用。 -->

## 功能特性

**取词与翻译**

- 全局快捷键 ⌥D（默认值，可在设置中自定义录制）
- 截图翻译快捷键 ⌥S：拖动框选屏幕区域，使用 Apple Vision 在本机 OCR 后自动翻译
- 通过 macOS Accessibility API 读取焦点元素的选中文本与选区范围；系统级焦点不可用时按前台应用回退，并兼容部分将选区暴露在父元素上的控件
- 辅助功能无法直接提供选区时，定向调用原应用的复制命令取词，读取后恢复原剪贴板
- Apple Translation framework 本地翻译，支持系统语言模型的准备与下载流程
- 设置中的“语言模型”页面可查看各语言组合的安装状态、提前下载中英模型，并跳转系统设置管理已下载模型
- 自动识别源语言：中文（含简繁体、粤语）译为英文，其他语言译为简体中文；源语言、默认目标语言与自动反向目标语言均可自定义，语言列表来自当前系统的 Apple Translation
- 翻译窗口顶部的“源语言 → 目标语言”可直接点击切换，选择结果自动保存并在下次翻译时沿用

**界面与体验**

- 菜单栏常驻，不显示 Dock 图标（`LSUIElement`）
- 非激活式 `NSPanel`，支持多显示器、Space 与全屏应用
- 新请求自动取消旧请求，过期结果不会覆盖当前结果
- 翻译窗口默认 640 × 500，可拖拽右下角调整大小并自动记忆
- 原文可直接编辑并重新翻译（支持 ⌘Return），原文与译文均可单独复制
- 界面完整支持简体中文与英文，跟随 macOS 应用语言设置

## 系统要求

| 项目 | 要求 |
| --- | --- |
| 操作系统 | macOS 15.0 或更高版本 |
| 开发工具 | 支持 Swift 6 与 macOS 15 SDK 的 Xcode（建议 Xcode 16+） |
| 已验证环境 | Xcode 26.2 / Swift 6.2.3 |
| 架构 | Apple Silicon 与 Intel（标准构建设置，无 Intel 专用逻辑） |

依赖：[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)（≥ 3.1.0，经 Swift Package Manager 管理，Xcode 首次打开时自动解析）。

## 快速开始

1. 使用 Xcode 打开 `TranslateDot.xcodeproj`。
2. 选择 `TranslateDot` scheme 与 `My Mac` 目标。
3. 在 Target → Signing & Capabilities 中选择你的 Development Team。项目有意关闭 App Sandbox，以便直接分发版本访问其他应用的 Accessibility 元素。
4. 点击 Run。应用启动后仅在菜单栏显示字符气泡图标。
5. 在 TextEdit 等应用中选中文本并按 **⌥D**；无法选中的图片、PDF 或视频字幕可按 **⌥S** 框选截图翻译。
6. 首次使用时，按面板提示前往"系统设置 → 隐私与安全性 → 辅助功能"启用 TranslateDot，返回原应用后重新选择文本并再次按 **⌥D**。
7. 若对应语言模型尚未安装，macOS 会弹出系统下载/授权界面，完成后翻译自动继续。

### 命令行构建与测试

```bash
xcodebuild -project TranslateDot.xcodeproj \
  -scheme TranslateDot \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project TranslateDot.xcodeproj \
  -scheme TranslateDot \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

## 系统权限说明

macOS 不允许普通应用直接读取其他应用的当前选区。TranslateDot 使用 `AXFocusedUIElement`、`AXSelectedText`、`AXSelectedTextRange` 与 `AXBoundsForRange`，且仅在用户主动按下快捷键时读取当前选区及其位置；权限被拒绝或撤销时，应用会显示引导界面，不会崩溃。

截图翻译需要 macOS 的“屏幕与系统音频录制”权限。TranslateDot 仅在用户按下截图快捷键并主动框选后捕获该区域，不持续录屏，也不申请输入监控权限。全局快捷键由 Carbon hot key 机制的封装库提供，而非全局键盘事件监听。

## 隐私

- 翻译由 Apple Translation framework 与系统本地语言模型完成，不接入云端翻译 API，无需 API Key
- 截图 OCR 使用 Apple Vision 在本机完成，截图不会上传，也不会保存
- 不保存翻译历史、原文或译文
- 日志仅记录权限状态、错误类型、状态切换与请求耗时，不记录选择内容
- 直接取词失败时短暂调用原应用的复制命令，读取后恢复原剪贴板，原文不会保留在剪贴板中；仅当点击"复制译文"后译文才会进入系统剪贴板

## 已知限制

- 部分 Electron 应用、自绘界面、终端与 PDF 阅读器可能不暴露 `AXSelectedText`，可改用 ⌥S 截图翻译
- OCR 效果受图片清晰度、字号、旋转角度与系统 Vision 支持语言影响
- 自动语言识别对很短或混合语言的文本可能不确定；无法识别时默认翻译为简体中文
- 语言模型的可用性、首次下载授权与下载进度由 macOS 管理
- 菜单栏中的"Translate Selection"会使菜单成为当前交互对象，最可靠的取词入口是全局快捷键 ⌥D

## 故障排查

### 修改 Bundle ID

默认 Bundle ID 为 `com.simon.translatedot`，可在 Xcode 的 Target → Signing & Capabilities → Bundle Identifier 中修改。若之后重新运行工程生成脚本，请同步修改 `scripts/generate_project.rb` 中的 `PRODUCT_BUNDLE_IDENTIFIER`。

修改 Bundle ID 后，macOS 会将其视为新的应用身份，需要重新授予辅助功能权限。

### 重置辅助功能权限

退出 TranslateDot 后执行：

```bash
tccutil reset Accessibility com.simon.translatedot
```

再次运行并按 ⌥D 即可重新走授权流程。若修改过 Bundle ID，请替换命令中的标识符。

### 已授权但仍提示授权

不要同时运行 Xcode DerivedData 与 `/Applications` 中的两份 TranslateDot。先停止 Xcode 中的进程并退出所有 TranslateDot 实例，然后执行上述 `tccutil reset` 命令，从 `/Applications/TranslateDot.app` 重新启动并授权。

应用每次启动最多主动请求一次系统授权弹窗，并在系统设置打开期间自动复检权限。如果同一次启动中持续出现多个授权弹窗，通常表示还有另一份 TranslateDot 正在运行。

## 开发

- `scripts/generate_project.rb`：使用本机 `xcodeproj` Ruby gem 重建工程文件，日常构建不需要运行
- `scripts/generate_app_icons.swift`：从品牌源图重新生成应用图标尺寸集

  ```bash
  swift scripts/generate_app_icons.swift \
    TranslateDot/Resources/Brand/TranslateDotIconMaster.png \
    TranslateDot/Resources/Assets.xcassets/AppIcon.appiconset
  ```

## Roadmap

- [ ] 登录时启动
- [ ] Developer ID 签名、公证与直接分发流程
