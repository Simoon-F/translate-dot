import AppKit
@preconcurrency import ApplicationServices
import os

@MainActor
final class AccessibilityPermissionManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "Accessibility")
    private var hasRequestedSystemPrompt = false
    private var authorizationMonitor: Task<Void, Never>?

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func check() -> Bool {
        let trusted = AXIsProcessTrusted()
        logger.info("Accessibility permission trusted=\(trusted, privacy: .public)")
        return trusted
    }

    /// Requests the macOS prompt at most once during this launch. Subsequent shortcut presses
    /// perform a silent check so the app cannot trap the user in repeated system dialogs.
    @discardableResult
    func requestAccessIfNeeded() -> Bool {
        if check() { return true }
        guard !hasRequestedSystemPrompt else { return false }

        hasRequestedSystemPrompt = true
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        logger.info("Accessibility permission requested; trusted=\(trusted, privacy: .public)")
        return trusted
    }

    /// Accessibility changes are delivered by TCC outside the app. Poll briefly while the user
    /// is in System Settings so the existing process can continue without requiring a relaunch.
    func monitorUntilGranted(onGranted: @escaping @MainActor () -> Void) {
        authorizationMonitor?.cancel()
        authorizationMonitor = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isTrusted {
                    self.logger.info("Accessibility permission change detected: granted")
                    onGranted()
                    self.authorizationMonitor = nil
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            logger.error("Could not form Accessibility settings URL")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
