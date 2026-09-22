import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import os

extension KeyboardShortcuts.Name {
    static let translateSelection = Self(
        "translateSelection",
        initial: .init(.d, modifiers: [.option])
    )
}

@MainActor
final class HotKeyManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "HotKey")
    private var isRunning = false
    private(set) var registrationErrorMessage: String?

    init(action: @escaping @MainActor () -> Void) {
        let name = KeyboardShortcuts.Name.translateSelection
        let defaultShortcut = KeyboardShortcuts.Shortcut(.d, modifiers: [.option])
        if KeyboardShortcuts.getShortcut(for: name) == nil {
            KeyboardShortcuts.setShortcut(defaultShortcut, for: name)
        }

        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            registrationErrorMessage = L10n.string(
                "hotkey.registration_failed",
                defaultValue: "Couldn't register global shortcut ⌥D. Restart the app."
            )
            logger.error("Global shortcut registration could not be configured")
            return
        }

        guard Self.canRegister(shortcut) else {
            registrationErrorMessage = L10n.string(
                "hotkey.conflict",
                defaultValue: "Global shortcut ⌥D is used by another app. Close the conflicting app and restart TranslateDot."
            )
            logger.error("Global shortcut registration preflight failed")
            return
        }

        KeyboardShortcuts.onKeyUp(for: name) {
            Task { @MainActor in action() }
        }
        isRunning = true
        logger.info("Global shortcut handler installed")
    }

    func stop() {
        guard isRunning else { return }
        KeyboardShortcuts.removeHandler(for: .translateSelection)
        isRunning = false
    }

    private static func canRegister(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x54444F54), id: 1) // "TDOT"
        let status = RegisterEventHotKey(
            UInt32(shortcut.carbonKeyCode),
            UInt32(shortcut.carbonModifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if let reference {
            UnregisterEventHotKey(reference)
        }
        return status == noErr
    }
}
