import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "App")
    private var appState: AppState?
    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = AppState()
        appState = state
        configureStatusItem(for: state)

        let hotKeys = HotKeyManager { [weak state] in
            state?.translateSelection()
        }
        hotKeyManager = hotKeys

        if let message = hotKeys.registrationErrorMessage {
            state.showHotKeyFailure(message)
        }
        logger.info("TranslateDot launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.stop()
    }

    private func configureStatusItem(for state: AppState) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menuBarIcon = NSApp.applicationIconImage.copy() as? NSImage
        menuBarIcon?.size = NSSize(width: 18, height: 18)
        menuBarIcon?.isTemplate = false
        item.button?.image = menuBarIcon
        item.button?.image?.accessibilityDescription = "TranslateDot"

        let menu = NSMenu()
        let translate = NSMenuItem(
            title: L10n.string("menu.translate_selection", defaultValue: "Translate Selection"),
            action: #selector(translateSelection),
            keyEquivalent: ""
        )
        translate.target = self
        menu.addItem(translate)

        let permission = NSMenuItem(title: permissionTitle(for: state), action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permission.target = self
        permission.tag = 100
        menu.addItem(permission)
        menu.addItem(.separator())

        let about = NSMenuItem(
            title: L10n.string("menu.about", defaultValue: "About TranslateDot"),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: L10n.string("menu.quit", defaultValue: "Quit TranslateDot"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    private func permissionTitle(for state: AppState) -> String {
        state.permissionManager.isTrusted
            ? L10n.string("menu.accessibility_granted", defaultValue: "Accessibility Permission: Granted")
            : L10n.string("menu.open_accessibility_settings", defaultValue: "Open Accessibility Settings…")
    }

    @objc private func translateSelection() {
        appState?.translateSelection()
    }

    @objc private func openAccessibilitySettings() {
        appState?.permissionManager.openSystemSettings()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "TranslateDot",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            .applicationIcon: NSApp.applicationIconImage as Any
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    nonisolated func menuWillOpen(_ menu: NSMenu) {
        Task { @MainActor [weak self] in
            guard let self, let state = self.appState else { return }
            self.statusItem?.menu?.item(withTag: 100)?.title = self.permissionTitle(for: state)
        }
    }
}
