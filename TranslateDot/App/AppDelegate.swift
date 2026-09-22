import AppKit
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "App")
    private var appState: AppState?
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let state = AppState()
        appState = state

        let hotKeys = HotKeyManager(
            selectionAction: { [weak state] in state?.translateSelection() },
            screenshotAction: { [weak state] in state?.translateScreenshot() }
        )
        hotKeyManager = hotKeys

        if let message = hotKeys.registrationErrorMessage {
            state.showHotKeyFailure(message)
        }
        logger.info("TranslateDot launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager?.stop()
    }

    var isAccessibilityTrusted: Bool {
        appState?.permissionManager.isTrusted ?? false
    }

    var accessibilityPermissionTitle: String {
        isAccessibilityTrusted
            ? L10n.string("menu.accessibility_granted", defaultValue: "Accessibility Permission: Granted")
            : L10n.string("menu.open_accessibility_settings", defaultValue: "Open Accessibility Settings…")
    }

    func translateSelection() {
        appState?.translateSelection()
    }

    func translateScreenshot() {
        appState?.translateScreenshot()
    }

    func activateSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        bringSettingsWindowForward(after: 0)
        bringSettingsWindowForward(after: 0.15)
        bringSettingsWindowForward(after: 0.4)
    }

    private func bringSettingsWindowForward(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSApp.activate(ignoringOtherApps: true)
            let settingsWindow = NSApp.windows.first { window in
                window.identifier?.rawValue == "TranslateDot.SettingsWindow"
                    || (window.isVisible && window.canBecomeKey && !(window is NSPanel))
            }
            settingsWindow?.level = .floating
            settingsWindow?.hidesOnDeactivate = false
            settingsWindow?.collectionBehavior.insert(.moveToActiveSpace)
            settingsWindow?.orderFrontRegardless()
            settingsWindow?.makeKey()
        }
    }

    func openAccessibilitySettings() {
        appState?.permissionManager.openSystemSettings()
    }

    func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "TranslateDot",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            .applicationIcon: NSApp.applicationIconImage as Any
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
