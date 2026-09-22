import CoreGraphics
import Foundation
import ApplicationServices

struct SelectedTextResult: Sendable, Equatable {
    let text: String
    /// AppKit global screen coordinates (origin at the lower-left of the main display).
    let bounds: CGRect?
}

enum SelectedTextError: Error, Equatable {
    case permissionRequired
    case focusedElementUnavailable(AXError)
    case selectedTextUnsupported
    case noSelection
    case selectionTooLong(limit: Int)
    case accessibilityFailure(AXError)

    var userMessage: String {
        switch self {
        case .permissionRequired:
            return L10n.string(
                "error.permission_required",
                defaultValue: "Accessibility permission is required to read selected text in other apps."
            )
        case .focusedElementUnavailable:
            return L10n.string(
                "error.focus_unavailable",
                defaultValue: "Couldn't read the current focus. Return to the original app and select the text again."
            )
        case .selectedTextUnsupported:
            return L10n.string(
                "error.selection_unsupported",
                defaultValue: "This app doesn't currently support direct text selection."
            )
        case .noSelection:
            return L10n.string("error.no_selection", defaultValue: "Select some text first.")
        case .selectionTooLong(let limit):
            return L10n.formatted(
                "error.selection_too_long",
                defaultValue: "The selected text is too long. Keep it under %lld characters.",
                Int64(limit)
            )
        case .accessibilityFailure:
            return L10n.string("error.ax_failure", defaultValue: "Couldn't read the selected text. Try again.")
        }
    }

    var logDescription: String {
        switch self {
        case .permissionRequired: return "permissionRequired"
        case .focusedElementUnavailable(let error): return "focusedElementUnavailable(\(error.rawValue))"
        case .selectedTextUnsupported: return "selectedTextUnsupported"
        case .noSelection: return "noSelection"
        case .selectionTooLong: return "selectionTooLong"
        case .accessibilityFailure(let error): return "accessibilityFailure(\(error.rawValue))"
        }
    }
}
