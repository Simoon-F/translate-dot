import SwiftUI

struct TranslationSuccessContent: View {
    @ObservedObject var viewModel: TranslationViewModel
    let translated: String
    let source: String
    let target: String
    let copied: TranslationCopyTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LanguageRouteBar(source: source, target: target)
            Divider().opacity(0.45)
            OriginalEditorCard(viewModel: viewModel, copied: copied == .original)
            Divider().opacity(0.45)
            TranslationResultCard(
                viewModel: viewModel,
                translated: translated,
                copied: copied == .translation
            )
            .frame(minHeight: 120, maxHeight: .infinity)
        }
    }
}

private struct LanguageRouteBar: View {
    let source: String
    let target: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "globe.asia.australia.fill")
                .foregroundStyle(.tint)
            Text(source)
                .fontWeight(.medium)
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(target)
                .fontWeight(.medium)
            Spacer()
            Text("⌘↩")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(Color.primary.opacity(0.018))
    }
}

private struct OriginalEditorCard: View {
    @ObservedObject var viewModel: TranslationViewModel
    let copied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            editor
            footer
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var header: some View {
        HStack {
            Label(L10n.string("panel.original", defaultValue: "Original"), systemImage: "pencil.line")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            PanelActionButton(
                title: copied
                    ? L10n.string("panel.copied", defaultValue: "Copied")
                    : L10n.string("panel.copy_original", defaultValue: "Copy Original"),
                systemImage: copied ? "checkmark" : "doc.on.doc",
                isConfirmed: copied,
                action: { viewModel.copyOriginal() }
            )
        }
    }

    private var editor: some View {
        TextEditor(text: Binding(
            get: { viewModel.draftOriginal },
            set: { value in viewModel.updateDraftOriginal(value) }
        ))
        .font(.system(size: 13))
        .lineSpacing(2)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.028), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(editorBorderColor, lineWidth: 1)
        }
        .frame(minHeight: 92, maxHeight: 152)
        .disabled(viewModel.isRetranslating)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L10n.string(
                "panel.edit_hint",
                defaultValue: "Edit the original, then translate again."
            ))
            .font(.system(size: 12))
            .lineLimit(1)
            .foregroundStyle(viewModel.isDraftTooLong ? Color.red : Color.secondary)
            Spacer()
            Text("\(viewModel.draftOriginal.count) / \(TranslationViewModel.maximumEditableCharacterCount)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(viewModel.isDraftTooLong ? Color.red : Color.secondary.opacity(0.75))
            Button {
                viewModel.retranslateDraft()
            } label: {
                if viewModel.isRetranslating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                } else {
                    Label(
                        L10n.string("panel.retranslate", defaultValue: "Translate Again"),
                        systemImage: "arrow.clockwise"
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .font(.system(size: 12, weight: .medium))
            .disabled(!viewModel.canRetranslate)
            .keyboardShortcut(.return, modifiers: [.command])
        }
    }

    private var editorBorderColor: Color {
        viewModel.isDraftTooLong ? Color.red.opacity(0.8) : Color.primary.opacity(0.10)
    }
}

private struct TranslationResultCard: View {
    @ObservedObject var viewModel: TranslationViewModel
    let translated: String
    let copied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    L10n.string("panel.translation", defaultValue: "Translation"),
                    systemImage: "character.bubble"
                )
                .font(.system(size: 12, weight: .semibold))
                Spacer()
                PanelActionButton(
                    title: copied
                        ? L10n.string("panel.copied", defaultValue: "Copied")
                        : L10n.string("panel.copy_translation", defaultValue: "Copy Translation"),
                    systemImage: copied ? "checkmark" : "doc.on.doc",
                    isConfirmed: copied,
                    action: { viewModel.copyTranslation() }
                )
            }
            ScrollView {
                Text(translated)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.accentColor.opacity(0.028))
    }
}

struct PanelCard<Content: View>: View {
    let tinted: Bool
    private let content: Content

    init(tinted: Bool = false, @ViewBuilder content: () -> Content) {
        self.tinted = tinted
        self.content = content()
    }

    var body: some View {
        content.panelCard(tinted: tinted)
    }
}

private struct PanelCardModifier: ViewModifier {
    let tinted: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
    }

    private var backgroundColor: Color {
        tinted ? Color.accentColor.opacity(0.045) : Color.primary.opacity(0.025)
    }

    private var borderColor: Color {
        tinted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.07)
    }
}

private extension View {
    func panelCard(tinted: Bool = false) -> some View {
        modifier(PanelCardModifier(tinted: tinted))
    }
}

private struct PanelActionButton: View {
    let title: String
    let systemImage: String
    let isConfirmed: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isConfirmed
                                ? Color.green.opacity(0.12)
                                : Color.primary.opacity(isHovering ? 0.075 : 0)
                        )
                }
                .foregroundStyle(isConfirmed ? Color.green : Color.primary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }
}
