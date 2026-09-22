import AppKit
import SwiftUI

struct TranslationPanelView: View {
    @ObservedObject var viewModel: TranslationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.65)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
        }
        .frame(
            minWidth: AppSettings.minimumPanelSize.width,
            minHeight: AppSettings.minimumPanelSize.height
        )
        .background(.regularMaterial)
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
        HStack(spacing: 8) {
            Image(systemName: "character.bubble.fill")
                .foregroundStyle(.tint)
            Text("TranslateDot")
                .font(.headline)
            Spacer()
            Button {
                viewModel.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(L10n.string("panel.close", defaultValue: "Close"))
        }
        .padding(.horizontal, 16)
        .frame(height: 45)
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
                .font(.title3.weight(.semibold))
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text(L10n.string(
                        "panel.recognizing_screenshot_message",
                        defaultValue: "Text recognition runs locally on this Mac."
                    ))
                    .foregroundStyle(.secondary)
                }
            }

        case .loading(let original):
            translationProgress(
                original: original,
                title: L10n.string("panel.checking_language", defaultValue: "Checking language…")
            )

        case .preparing(let original):
            translationProgress(
                original: original,
                title: L10n.string("panel.preparing_model", defaultValue: "Preparing language model…")
            )

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
        VStack(alignment: .leading, spacing: 14) {
            sourceSection(original)
            HStack(spacing: 9) {
                ProgressView().controlSize(.small)
                Text(title).foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("\(source) → \(target)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            VSplitView {
                textSection(
                    title: L10n.string("panel.original", defaultValue: "Original"),
                    text: original,
                    isOriginal: true,
                    copied: copied == .original,
                    copyTitle: L10n.string("panel.copy_original", defaultValue: "Copy Original"),
                    action: viewModel.copyOriginal
                )
                .frame(minHeight: 110)

                textSection(
                    title: L10n.string("panel.translation", defaultValue: "Translation"),
                    text: translated,
                    isOriginal: false,
                    copied: copied == .translation,
                    copyTitle: L10n.string("panel.copy_translation", defaultValue: "Copy Translation"),
                    action: viewModel.copyTranslation
                )
                .frame(minHeight: 140)
            }
        }
    }

    private func textSection(
        title: String,
        text: String,
        isOriginal: Bool,
        copied: Bool,
        copyTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: action) {
                    Label(
                        copied ? L10n.string("panel.copied", defaultValue: "Copied") : copyTitle,
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.borderless)
            }
            ScrollView {
                Text(text)
                    .font(isOriginal ? .callout : .body)
                    .foregroundStyle(isOriginal ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 10)
            }
        }
        .padding(.vertical, 6)
    }

    private var permissionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                L10n.string("panel.permission_title", defaultValue: "Accessibility Permission Required"),
                systemImage: "hand.raised.fill"
            )
                .font(.title3.weight(.semibold))
            Text(L10n.string(
                "panel.permission_message",
                defaultValue: "TranslateDot only uses this permission to read text you explicitly select. After granting access, the app checks automatically."
            ))
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
    }

    private var screenCapturePermissionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                L10n.string("panel.screen_permission_title", defaultValue: "Screen Recording Permission Required"),
                systemImage: "rectangle.dashed.badge.record"
            )
                .font(.title3.weight(.semibold))
            Text(L10n.string(
                "panel.screen_permission_message",
                defaultValue: "TranslateDot needs Screen & System Audio Recording access to capture only the area you select. You may need to reopen the app after granting access."
            ))
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
    }

    private func sourceSection(_ original: String) -> some View {
        ScrollView {
            Text(original)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 205)
    }

    private func messageView(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
