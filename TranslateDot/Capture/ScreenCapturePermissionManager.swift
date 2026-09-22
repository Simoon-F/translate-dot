import AppKit
import CoreGraphics

@MainActor
final class ScreenCapturePermissionManager {
    var isAuthorized: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestAccessIfNeeded() -> Bool {
        isAuthorized || CGRequestScreenCaptureAccess()
    }

    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
