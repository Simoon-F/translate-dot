# TranslateDot

TranslateDot 是一款轻量级原生 macOS 划词翻译工具。在其他应用中选中文本后按下 **⌥D**，应用会通过 Accessibility API 读取选区，使用 Apple Translation 在本机翻译，并在选区附近显示一个不抢焦点的悬浮面板。

当前 MVP 只聚焦这条链路：**选中文本 → 按 ⌥D → 本地翻译 → 悬浮显示**。

> 截图占位：完成签名并在真实应用中授权辅助功能后，可将浅色/深色模式截图放入 `docs/screenshots/`。

品牌源图保存在 `TranslateDot/Resources/Brand/TranslateDotLogoOriginal.png`；处理后的 1024px 主图保存在 `TranslateDotIconMaster.png`，完整尺寸集位于 `Assets.xcassets/AppIcon.appiconset`。需要重新生成尺寸时，可运行 `swift scripts/generate_app_icons.swift TranslateDot/Resources/Brand/TranslateDotIconMaster.png TranslateDot/Resources/Assets.xcassets/AppIcon.appiconset`。

## 功能

- 菜单栏常驻，不显示 Dock 图标（`LSUIElement`）
- `KeyboardShortcuts` 提供全局快捷键，默认 **Option + D**
- 通过 macOS Accessibility API 读取焦点元素的选中文本和选区范围；系统级焦点不可用时会按前台应用回退，并兼容部分将选区暴露在父元素上的控件
- 辅助功能无法直接提供选区时，定向调用原应用的复制命令取词，并在读取后恢复原剪贴板
- Apple Translation framework 本地翻译，支持语言模型准备/下载流程
- 自动识别源语言：中文（含简繁体、粤语）翻译为英文，其他语言翻译为简体中文
- 界面完整支持简体中文与英文，并跟随 macOS 的应用语言设置
- 非激活式 `NSPanel`，支持多显示器、Space 和全屏应用
- 新请求取消旧请求，过期结果不会覆盖当前结果
- 可复制译文；不保存历史、不记录原文或译文

## 系统与构建要求

- macOS 15.0 或更高版本
- 支持 Swift 6 和 macOS 15 SDK 的 Xcode（建议 Xcode 16 或更高版本）
- 本项目已使用 Xcode 26.2 / Swift 6.2.3 验证
- Apple Silicon 与 Intel 均使用系统支持的标准构建设置；未添加 Intel 专用逻辑

项目通过 Swift Package Manager 使用 [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)，首次打开时 Xcode 会自动解析依赖。

## 运行

1. 使用 Xcode 打开 `TranslateDot.xcodeproj`。
2. 选择 `TranslateDot` scheme 和 `My Mac`。
3. 在 Target → Signing & Capabilities 中选择自己的 Development Team。项目有意关闭 App Sandbox，以便个人直接分发版本访问其他应用的 Accessibility 元素。
4. 点击 Run。TranslateDot 启动后只在菜单栏显示字符气泡图标。
5. 在 TextEdit 等应用中选择文本并按 **⌥D**。
6. 首次使用时按面板提示打开“系统设置 → 隐私与安全性 → 辅助功能”，启用 TranslateDot；返回原应用后重新选择文本并再次按 **⌥D**。
7. 如果对应语言模型尚未安装，macOS 会显示系统下载/授权界面；完成后翻译会继续。

命令行无签名构建与测试：

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

`scripts/generate_project.rb` 可使用本机 `xcodeproj` Ruby gem 重建工程文件；日常构建不需要运行该脚本。

## 为什么需要辅助功能权限

macOS 不允许普通应用直接读取另一个应用的当前选区。TranslateDot 使用 `AXFocusedUIElement`、`AXSelectedText`、`AXSelectedTextRange` 和 `AXBoundsForRange`，只在用户主动按下快捷键时读取当前选区及其位置。权限被拒绝或撤销时，应用会显示引导，不会崩溃。

TranslateDot 不申请屏幕录制权限，也不需要输入监控权限。全局快捷键由 Carbon hot key 机制封装库提供，而不是依赖全局键盘事件监听。

## 隐私

- 翻译由 Apple Translation framework 和系统本地语言模型完成
- 不接入云端翻译 API，不需要 API Key
- 不保存翻译历史、原文或译文
- 日志只记录权限状态、错误类型、状态切换和请求耗时，不记录选择内容
- 直接取词失败时会短暂调用原应用的复制命令，并在读取后恢复原剪贴板；原文不会保留在剪贴板中
- 只有点击“复制译文”后，译文才会保留在系统剪贴板
- 不使用 OCR、截图或屏幕录制权限

## 已知限制

- 部分 Electron 应用、自绘界面、终端和 PDF 阅读器可能不暴露 `AXSelectedText`，此时会显示“当前应用暂不支持直接取词”
- 少数禁止复制或不提供可访问文本的界面仍然无法取词；图片中的文字需要 OCR，本版本不申请屏幕录制权限
- 自动语言识别对很短或混合语言文本可能不确定；无法识别时默认翻译为简体中文
- 语言模型的可用性、首次下载授权与下载进度由 macOS 管理
- 菜单栏中的 “Translate Selection” 会使菜单成为当前交互对象；最可靠的取词入口是全局快捷键 ⌥D

## Bundle ID

默认 Bundle ID 是 `com.simon.translatedot`。可在 Xcode 的 Target → Signing & Capabilities → Bundle Identifier 中修改。若之后会重新运行工程生成脚本，也请同步修改 `scripts/generate_project.rb` 中的 `PRODUCT_BUNDLE_IDENTIFIER`。

修改 Bundle ID 后，macOS 会把它视为新的应用身份，需要重新授予辅助功能权限。

### 已授权但仍提示时

不要同时运行 Xcode DerivedData 和 `/Applications` 中的两个 TranslateDot。先停止 Xcode 中的进程并退出所有 TranslateDot，然后执行下面的重置命令，重新从 `/Applications/TranslateDot.app` 启动并授权：

```bash
tccutil reset Accessibility com.simon.translatedot
```

应用每次启动最多只主动请求一次系统授权弹窗，并会在系统设置打开期间自动复检权限。如果同一次启动中持续出现多个系统授权弹窗，通常表示电脑上还有另一份 TranslateDot 正在运行。

## 重置辅助功能权限

退出 TranslateDot 后执行：

```bash
tccutil reset Accessibility com.simon.translatedot
```

再次运行并按 ⌥D，即可重新走授权流程。若修改过 Bundle ID，请替换命令中的标识符。

## 手动验收清单

- [ ] TextEdit 中选择英文，按 ⌥D，翻译为简体中文
- [ ] TextEdit 中选择中文，按 ⌥D，翻译为英文
- [ ] Safari 网页中选择文本并翻译
- [ ] Xcode 编辑器中选择文本并翻译
- [ ] 翻译多行文本
- [ ] 未选择文本时按 ⌥D，显示明确提示
- [ ] 撤销辅助功能权限后按 ⌥D，显示权限引导
- [ ] 首次缺少语言模型时触发系统下载流程
- [ ] 连续快速按多次 ⌥D，只有最新结果显示
- [ ] 多显示器下靠近屏幕边缘选择文本，面板不越界
- [ ] 全屏应用中触发翻译
- [ ] 检查深色模式和浅色模式
- [ ] 点击“复制译文”并验证轻量成功反馈
- [ ] 确认系统未请求屏幕录制权限
- [ ] 确认系统未请求输入监控权限
- [ ] 确认应用不显示 Dock 图标
- [ ] 确认悬浮面板没有让原应用明显失焦

## 后续路线

- 可选的屏幕 OCR 取词
- 可配置快捷键和快捷键录制界面
- 目标语言设置
- 登录时启动
- Developer ID 签名、公证与直接分发流程
