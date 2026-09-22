import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import os

extension KeyboardShortcuts.Name {
    static let translateSelection = Self(
        "translateSelection",
        initial: .init(.d, modifiers: [.option])
    )
    static let translateScreenshot = Self(
        "translateScreenshot",
        initial: .init(.s, modifiers: [.option])
    )
}

@MainActor
final class HotKeyManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "HotKey")
    private var isRunning = false
    private(set) var registrationErrorMessage: String?

    init(
        selectionAction: @escaping @MainActor () -> Void,
        screenshotAction: @escaping @MainActor () -> Void
    ) {
        configure(
            name: .translateSelection,
            defaultShortcut: .init(.d, modifiers: [.option]),
            identifier: 1,
            fallbackDescription: "⌥D",
            action: selectionAction
        )
        configure(
            name: .translateScreenshot,
            defaultShortcut: .init(.s, modifiers: [.option]),
            identifier: 2,
            fallbackDescription: "⌥S",
            action: screenshotAction
        )
        isRunning = true
        logger.info("Global shortcut handlers installed")
    }

    func stop() {
        guard isRunning else { return }
        KeyboardShortcuts.removeHandler(for: .translateSelection)
        KeyboardShortcuts.removeHandler(for: .translateScreenshot)
        isRunning = false
    }

    private func configure(
        name: KeyboardShortcuts.Name,
        defaultShortcut: KeyboardShortcuts.Shortcut,
        identifier: UInt32,
        fallbackDescription: String,
        action: @escaping @MainActor () -> Void
    ) {
        if KeyboardShortcuts.getShortcut(for: name) == nil {
            KeyboardShortcuts.setShortcut(defaultShortcut, for: name)
        }
        guard let shortcut = KeyboardShortcuts.getShortcut(for: name) else {
            registrationErrorMessage = registrationErrorMessage ?? L10n.formatted(
                "hotkey.registration_failed_named",
                defaultValue: "Couldn't register global shortcut %@. Restart the app.",
                fallbackDescription
            )
            logger.error("Global shortcut could not be configured: \(fallbackDescription, privacy: .public)")
            return
        }
        guard Self.canRegister(shortcut, identifier: identifier) else {
            registrationErrorMessage = registrationErrorMessage ?? L10n.formatted(
                "hotkey.conflict_named",
                defaultValue: "Global shortcut %@ is used by another app. Change it in TranslateDot Settings.",
                fallbackDescription
            )
            logger.error("Global shortcut preflight failed: \(fallbackDescription, privacy: .public)")
            return
        }
        KeyboardShortcuts.onKeyUp(for: name) {
            Task { @MainActor in action() }
        }
    }

    private static func canRegister(_ shortcut: KeyboardShortcuts.Shortcut, identifier: UInt32) -> Bool {
        var reference: EventHotKeyRef?
        let hotKeyIdentifier = EventHotKeyID(signature: OSType(0x54444F54), id: identifier) // "TDOT"
        let status = RegisterEventHotKey(
            UInt32(shortcut.carbonKeyCode),
            UInt32(shortcut.carbonModifiers),
            hotKeyIdentifier,
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
