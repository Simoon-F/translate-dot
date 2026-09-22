import AppKit
import SwiftUI

struct TranslationPanelView: View {
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.45)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .font(.system(size: 12))
        .frame(
            minWidth: AppSettings.minimumPanelSize.width,
            minHeight: AppSettings.minimumPanelSize.height
        )
        .background {
            Rectangle().fill(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            PanelResizeHandle()
                .frame(width: 28, height: 28)
                .padding(3)
                .accessibilityLabel(L10n.string("panel.resize", defaultValue: "Resize Window"))
        }
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            PanelDragRegion()
            HStack(spacing: 8) {
                Image(systemName: "character.bubble.fill")
                    .foregroundStyle(.tint)
                Text("TranslateDot")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .allowsHitTesting(false)

            PanelCloseButton(action: viewModel.dismiss)
                .padding(.trailing, 12)
        }
        .frame(height: 48)
        .background(.thinMaterial.opacity(0.45))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            messageView(
                icon: "text.cursor",
                title: L10n.string("panel.idle_title", defaultValue: "Select text, then press ⌥D"),
                message: L10n.string(
                    "panel.idle_message",
                    defaultValue: "TranslateDot will show the system translation here."
                )
            )

        case .recognizingScreenshot:
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    L10n.string("panel.recognizing_screenshot", defaultValue: "Recognizing screenshot…"),
                    systemImage: "viewfinder"
                )
                .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text(L10n.string(
                        "panel.recognizing_screenshot_message",
                        defaultValue: "Text recognition runs locally on this Mac."
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)

        case .loading(let original):
            translationProgress(
                original: original,
                title: L10n.string("panel.checking_language", defaultValue: "Checking language…")
            )
            .padding(20)

        case .preparing(let original):
            translationProgress(
                original: original,
                title: L10n.string("panel.preparing_model", defaultValue: "Preparing language model…")
            )
            .padding(20)

        case .success(let original, let translated, let source, let target, let copied):
            successView(original: original, translated: translated, source: source, target: target, copied: copied)

        case .permissionRequired:
            permissionView

        case .screenCapturePermissionRequired:
            screenCapturePermissionView

        case .noSelection(let message):
            messageView(
                icon: "selection.pin.in.out",
                title: L10n.string("panel.no_selection_title", defaultValue: "No translatable selection"),
                message: message
            )

        case .unsupported(let message):
            messageView(
                icon: "exclamationmark.bubble",
                title: L10n.string("panel.unsupported_title", defaultValue: "Not Supported"),
                message: message
            )

        case .failure(let message):
            messageView(
                icon: "exclamationmark.triangle",
                title: L10n.string("panel.failure_title", defaultValue: "Translation Incomplete"),
                message: message
            )
        }
    }

    private func translationProgress(original: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label(L10n.string("panel.original", defaultValue: "Original"), systemImage: "text.alignleft")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(original)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            PanelCard(tinted: true) {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
            }
        }
    }

    private func successView(
        original: String,
        translated: String,
        source: String,
        target: String,
        copied: TranslationCopyTarget?
    ) -> some View {
        TranslationSuccessContent(
            viewModel: viewModel,
            translated: translated,
            source: source,
            target: target,
            copied: copied
        )
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                L10n.string("panel.permission_title", defaultValue: "Accessibility Permission Required"),
                systemImage: "hand.raised.fill"
            )
                .font(.system(size: 14, weight: .semibold))
            Text(L10n.string(
                "panel.permission_message",
                defaultValue: "TranslateDot only uses this permission to read text you explicitly select. After granting access, the app checks automatically."
            ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L10n.string("panel.open_settings", defaultValue: "Open System Settings")) {
                    viewModel.openAccessibilitySettings()
                }
                    .buttonStyle(.borderedProminent)
                Button(L10n.string("panel.check_again", defaultValue: "Check Again")) {
                    viewModel.retryAccessibility()
                }
                    .buttonStyle(.bordered)
            }
        }
        .padding(20)
    }

    private var screenCapturePermissionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                L10n.string("panel.screen_permission_title", defaultValue: "Screen Recording Permission Required"),
                systemImage: "rectangle.dashed.badge.record"
            )
                .font(.system(size: 14, weight: .semibold))
            Text(L10n.string(
                "panel.screen_permission_message",
                defaultValue: "TranslateDot needs Screen & System Audio Recording access to capture only the area you select. You may need to reopen the app after granting access."
            ))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L10n.string("panel.open_settings", defaultValue: "Open System Settings")) {
                    viewModel.openScreenCaptureSettings()
                }
                    .buttonStyle(.borderedProminent)
                Button(L10n.string("panel.check_again", defaultValue: "Check Again")) {
                    viewModel.retryScreenCapture()
                }
                    .buttonStyle(.bordered)
            }
        }
        .padding(20)
    }

    private func messageView(icon: String, title: String, message: String) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
    }
}

private struct PanelCloseButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 26, height: 26)
                .background {
                    Circle()
                        .fill(.primary.opacity(isHovering ? 0.12 : 0))
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(L10n.string("panel.close", defaultValue: "Close"))
        .accessibilityLabel(L10n.string("panel.close", defaultValue: "Close"))
    }
}

private struct PanelDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelDragView {
        PanelDragView()
    }

    func updateNSView(_ nsView: PanelDragView, context: Context) {}
}

private final class PanelDragView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct PanelResizeHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView()
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {}
}

private final class ResizeHandleView: NSView {
    private var initialWindowFrame: CGRect?
    private var initialMouseLocation: CGPoint?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let image = NSImage(
            systemSymbolName: "arrow.up.left.and.arrow.down.right",
            accessibilityDescription: nil
        ) else { return }
        image.isTemplate = true
        image.draw(
            in: bounds.insetBy(dx: 7, dy: 7),
            from: .zero,
            operation: .sourceOver,
            fraction: 0.45,
            respectFlipped: true,
            hints: nil
        )
    }

    override func mouseDown(with event: NSEvent) {
        initialWindowFrame = window?.frame
        initialMouseLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let initialWindowFrame,
              let initialMouseLocation else { return }

        let currentMouseLocation = NSEvent.mouseLocation
        let width = min(
            max(initialWindowFrame.width + currentMouseLocation.x - initialMouseLocation.x, window.minSize.width),
            window.maxSize.width
        )
        let height = min(
            max(initialWindowFrame.height - currentMouseLocation.y + initialMouseLocation.y, window.minSize.height),
            window.maxSize.height
        )
        let frame = CGRect(
            x: initialWindowFrame.minX,
            y: initialWindowFrame.maxY - height,
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
    }
}
