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
        .frame(width: 440, height: 350)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
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

    private func successView(original: String, translated: String, source: String, target: String, copied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(source) → \(target)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    viewModel.copyTranslation()
                } label: {
                    Label(
                        copied
                            ? L10n.string("panel.copied", defaultValue: "Copied")
                            : L10n.string("panel.copy_translation", defaultValue: "Copy Translation"),
                        systemImage: copied ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(.borderless)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(original)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                    Text(translated)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
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
