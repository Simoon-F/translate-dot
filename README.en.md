# TranslateDot

<div align="center">

**Lightweight, fully local selection and screenshot translation for macOS**

Select text in any app, and the translation appears instantly in a floating panel next to your selection.

[简体中文](README.md) · English

</div>

---

## Overview

TranslateDot is a native macOS menu bar app. It reads the current text selection through the macOS Accessibility API, translates it on-device with the Apple Translation framework, and presents the result in a non-activating floating panel — without interrupting your workflow and without any cloud translation service.

Core flow: **select text or a screen region → press a hotkey → local recognition and translation → floating result**.

<!-- Screenshot placeholder: after code signing and Accessibility approval, add light/dark mode screenshots under docs/screenshots/ and reference them here. -->

## Features

**Text capture and translation**

- Global hotkey ⌥D (default; re-recordable in Settings)
- Screenshot translation with ⌥S: drag over a screen region, run OCR locally with Apple Vision, then translate automatically
- Reads the selected text and selection bounds of the focused element via the macOS Accessibility API; falls back to the frontmost application when system-level focus is unavailable, and supports controls that expose the selection on a parent element
- When Accessibility data is unavailable, invokes the host app's Copy command to capture the selection and restores the original clipboard afterwards
- On-device translation through the Apple Translation framework, including system language model preparation and download flows
- Automatic source-language detection: Chinese (Simplified/Traditional, Cantonese) is translated to English, other languages to Simplified Chinese; source language, default target language, and automatic reverse target are all customizable, with the language list provided by the system's Apple Translation

**UI and experience**

- Menu bar resident, no Dock icon (`LSUIElement`)
- Non-activating `NSPanel` with multi-display, Space, and full-screen support
- New requests cancel stale ones; outdated results never overwrite current results
- Translation window defaults to 640 × 500, resizable from the bottom-right corner, with the size remembered
- Source text and translation can be copied independently
- Fully localized in Simplified Chinese and English, following the app language setting in macOS

## Requirements

| Item | Requirement |
| --- | --- |
| Operating system | macOS 15.0 or later |
| Tooling | Xcode with Swift 6 and the macOS 15 SDK (Xcode 16+ recommended) |
| Verified environment | Xcode 26.2 / Swift 6.2.3 |
| Architecture | Apple Silicon and Intel (standard build settings, no Intel-specific code) |

Dependency: [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (≥ 3.1.0, managed via Swift Package Manager and resolved automatically on first open).

## Getting Started

1. Open `TranslateDot.xcodeproj` in Xcode.
2. Select the `TranslateDot` scheme and the `My Mac` destination.
3. Choose your Development Team under Target → Signing & Capabilities. The project intentionally disables App Sandbox so that directly distributed builds can access other apps' Accessibility elements.
4. Click Run. After launch, TranslateDot only appears as a character-bubble icon in the menu bar.
5. Select text in an app such as TextEdit and press **⌥D**. For images, PDFs, or video subtitles, press **⌥S** and drag over the content.
6. On first use, follow the panel's prompt to enable TranslateDot under System Settings → Privacy & Security → Accessibility, then select text again and press **⌥D**.
7. If the required language model is not installed, macOS presents the system download/authorization dialog; translation continues automatically once it completes.

### Command-line build and test

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

## System Permissions

macOS does not allow a regular app to read another app's current selection. TranslateDot uses `AXFocusedUIElement`, `AXSelectedText`, `AXSelectedTextRange`, and `AXBoundsForRange`, and only reads the selection and its position when the user explicitly presses the hotkey. If the permission is denied or revoked, the app shows guidance instead of crashing.

Screenshot translation requires macOS Screen & System Audio Recording access. TranslateDot captures only the region you deliberately select after invoking the shortcut; it does not record continuously or request Input Monitoring access. Global hotkeys use a Carbon hot key wrapper rather than global keyboard event monitoring.

## Privacy

- Translation runs entirely on-device through the Apple Translation framework and system language models; no cloud translation API or API key is involved
- Screenshot OCR runs on-device through Apple Vision; screenshots are neither uploaded nor saved
- No translation history, source text, or translations are stored
- Logs contain only permission state, error types, state transitions, and request durations — never selected content
- When direct capture fails, the host app's Copy command is invoked briefly and the clipboard is restored afterwards; source text never remains on the clipboard, and a translation is only placed on the clipboard after clicking "Copy Translation"

## Known Limitations

- Some Electron apps, custom-drawn UIs, terminals, and PDF readers may not expose `AXSelectedText`; use ⌥S screenshot translation instead
- OCR quality depends on image clarity, text size, rotation, and languages supported by the system Vision framework
- Automatic language detection may be ambiguous for very short or mixed-language text; unrecognized input defaults to Simplified Chinese
- Language model availability, first-use authorization, and download progress are managed by macOS
- "Translate Selection" in the menu bar makes the menu the active responder; the global hotkey ⌥D is the most reliable capture entry point

## Troubleshooting

### Changing the Bundle ID

The default Bundle ID is `com.simon.translatedot`; change it under Target → Signing & Capabilities → Bundle Identifier in Xcode. If you later regenerate the project files, also update `PRODUCT_BUNDLE_IDENTIFIER` in `scripts/generate_project.rb`.

After changing the Bundle ID, macOS treats it as a new app identity and Accessibility permission must be granted again.

### Resetting Accessibility Permission

Quit TranslateDot, then run:

```bash
tccutil reset Accessibility com.simon.translatedot
```

Relaunch and press ⌥D to walk through the authorization flow again. If you changed the Bundle ID, substitute it in the command.

### Prompted Again Despite Approval

Do not run two copies of TranslateDot — one from Xcode's DerivedData and one from `/Applications` — at the same time. Stop the Xcode-run process, quit every TranslateDot instance, run the `tccutil reset` command above, relaunch from `/Applications/TranslateDot.app`, and grant permission again.

The app requests the system authorization prompt at most once per launch and re-checks permission automatically while System Settings is open. If multiple prompts appear within a single launch, another copy of TranslateDot is likely still running.

## Development

- `scripts/generate_project.rb`: rebuilds the Xcode project with the local `xcodeproj` Ruby gem; not needed for day-to-day builds
- `scripts/generate_app_icons.swift`: regenerates the app icon size set from the brand master image

  ```bash
  swift scripts/generate_app_icons.swift \
    TranslateDot/Resources/Brand/TranslateDotIconMaster.png \
    TranslateDot/Resources/Assets.xcassets/AppIcon.appiconset
  ```

## Roadmap

- [ ] Optional on-screen OCR text capture
- [ ] Launch at login
- [ ] Developer ID signing, notarization, and direct distribution
