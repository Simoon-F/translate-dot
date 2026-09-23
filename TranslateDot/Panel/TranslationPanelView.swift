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
            TranslationPanelContent(
                viewModel: viewModel,
                statusMessage: L10n.string("panel.checking_language", defaultValue: "Checking language…")
            )

        case .preparing(let original):
            TranslationPanelContent(
                viewModel: viewModel,
                statusMessage: L10n.string("panel.preparing_model", defaultValue: "Preparing language model…")
            )

        case .success(let original, let translated, let source, let target, let copied):
            TranslationPanelContent(
                viewModel: viewModel,
                source: source,
                target: target,
                translated: translated
            )

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

        case .manualInput(let hint):
            TranslationPanelContent(viewModel: viewModel, hint: hint)

        case .unsupported(let message):
            languageSwitchableMessageView(
                icon: "exclamationmark.bubble",
                title: L10n.string("panel.unsupported_title", defaultValue: "Not Supported"),
                message: message
            )

        case .modelDownloadRequired(_, let sourceLabel, let targetLabel):
            modelDownloadView(sourceLabel: sourceLabel, targetLabel: targetLabel)

        case .failure(let message):
            languageSwitchableMessageView(
                icon: "exclamationmark.triangle",
                title: L10n.string("panel.failure_title", defaultValue: "Translation Incomplete"),
                message: message
            )
        }
    }

    /// Failure states keep the language bar visible so the user can switch to
    /// another installed language and retry without leaving the panel — e.g.
    /// after dismissing the system model-download prompt.
    private func languageSwitchableMessageView(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            languageRouteBar
            Divider().opacity(0.45)
            messageView(
                icon: icon,
                title: title,
                message: message + "\n\n" + L10n.string(
                    "panel.language_retry_hint",
                    defaultValue: "You can pick a different source or target language above, then try again."
                )
            )
        }
    }

    private var languageRouteBar: some View {
        LanguageRouteBar(
            source: AppSettings.shared.sourceLanguageIdentifier.isEmpty
                ? L10n.string("language.auto_detect", defaultValue: "Auto-detect")
                : AppSettings.shared.languageDisplayName(for: AppSettings.shared.sourceLanguageIdentifier),
            target: AppSettings.shared.languageDisplayName(
                for: AppSettings.shared.targetLanguageIdentifier
            ),
            settings: AppSettings.shared,
            onLanguageChanged: { viewModel.retranslateWithCurrentLanguages() }
        )
    }

    private func modelDownloadView(sourceLabel: String, targetLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            languageRouteBar
            Divider().opacity(0.45)
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    L10n.string("panel.model_download_title", defaultValue: "Language Model Needed"),
                    systemImage: "arrow.down.circle"
                )
                    .font(.system(size: 14, weight: .semibold))
                Text(L10n.formatted(
                    "panel.model_download_message",
                    defaultValue: "The model for %@ → %@ isn't downloaded yet. Download it to translate, or pick another language above.",
                    sourceLabel,
                    targetLabel
                ))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L10n.string("panel.download_model", defaultValue: "Download Language Model")) {
                    viewModel.downloadModel()
                }
                    .buttonStyle(.borderedProminent)
            }
            .padding(20)
        }
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
