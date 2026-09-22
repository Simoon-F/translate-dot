import AppKit
import Carbon.HIToolbox
import CoreGraphics
import os

@MainActor
struct ClipboardSelectedTextProvider {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot",
        category: "ClipboardSelection"
    )

    func readSelection(from applicationPID: pid_t?) async -> Result<SelectedTextResult, SelectedTextError> {
        guard let applicationPID,
              applicationPID != ProcessInfo.processInfo.processIdentifier else {
            return .failure(.focusedElementUnavailable(.noValue))
        }

        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let initialChangeCount = pasteboard.changeCount

        guard postCopyShortcut(to: applicationPID) else {
            return .failure(.accessibilityFailure(.cannotComplete))
        }

        var didCopy = false
        for _ in 0..<20 {
            do {
                try await Task.sleep(for: .milliseconds(25))
            } catch {
                return .failure(.noSelection)
            }
            if pasteboard.changeCount != initialChangeCount {
                didCopy = true
                break
            }
        }

        guard didCopy else {
            logger.error("Target application did not update the pasteboard after Command-C")
            return .failure(.noSelection)
        }

        let copiedChangeCount = pasteboard.changeCount
        let selectedText = pasteboard.string(forType: .string)

        // Do not overwrite a clipboard change made by the user or another app while waiting.
        if pasteboard.changeCount == copiedChangeCount {
            snapshot.restore(to: pasteboard)
        }

        guard let selectedText else {
            return .failure(.selectedTextUnsupported)
        }
        let trimmed = selectedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.noSelection)
        }
        guard selectedText.count <= AXSelectedTextProvider.maximumCharacterCount else {
            return .failure(.selectionTooLong(limit: AXSelectedTextProvider.maximumCharacterCount))
        }

        logger.info("Read selection using the clipboard fallback")
        return .success(SelectedTextResult(text: selectedText, bounds: nil))
    }

    private func postCopyShortcut(to applicationPID: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: true
              ),
              let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(kVK_ANSI_C),
                keyDown: false
              ) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(applicationPID)
        keyUp.postToPid(applicationPID)
        return true
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restoredItems = items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}
