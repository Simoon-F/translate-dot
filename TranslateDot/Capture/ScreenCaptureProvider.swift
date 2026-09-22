import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case displayUnavailable
    case invalidSelection

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            return L10n.string(
                "error.capture_display_unavailable",
                defaultValue: "The selected display is no longer available. Try again."
            )
        case .invalidSelection:
            return L10n.string(
                "error.capture_invalid_selection",
                defaultValue: "The screenshot area is too small. Drag to select a larger area."
            )
        }
    }
}

enum ScreenCaptureCoordinateConverter {
    static func sourceRect(selectionBounds: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: selectionBounds.minX - screenFrame.minX,
            y: screenFrame.maxY - selectionBounds.maxY,
            width: selectionBounds.width,
            height: selectionBounds.height
        )
    }
}

@MainActor
final class ScreenCaptureProvider {
    func capture(selectionBounds: CGRect, on screen: NSScreen) async throws -> CGImage {
        guard selectionBounds.width >= 4, selectionBounds.height >= 4 else {
            throw ScreenCaptureError.invalidSelection
        }
        guard let displayNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else {
            throw ScreenCaptureError.displayUnavailable
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first(where: {
            $0.displayID == CGDirectDisplayID(displayNumber.uint32Value)
        }) else {
            throw ScreenCaptureError.displayUnavailable
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentApplication = content.applications.filter { $0.processID == currentPID }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: currentApplication,
            exceptingWindows: []
        )
        let sourceRect = ScreenCaptureCoordinateConverter.sourceRect(
            selectionBounds: selectionBounds,
            screenFrame: screen.frame
        )
        let scale = screen.backingScaleFactor
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = max(1, Int((sourceRect.width * scale).rounded()))
        configuration.height = max(1, Int((sourceRect.height * scale).rounded()))
        configuration.showsCursor = false
        configuration.capturesAudio = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }
}
