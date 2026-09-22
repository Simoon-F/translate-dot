import AVFoundation
import os
import SwiftUI

struct TranslationSuccessContent: View {
    @ObservedObject var viewModel: TranslationViewModel
    let translated: String
    let source: String
    let target: String
    let copied: TranslationCopyTarget?
    @StateObject private var speechController = TextSpeechController()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LanguageRouteBar(source: source, target: target)
            Divider().opacity(0.45)
            OriginalEditorCard(
                viewModel: viewModel,
                copied: copied == .original,
                speechController: speechController
            )
            Divider().opacity(0.45)
            TranslationResultCard(
                viewModel: viewModel,
                translated: translated,
                copied: copied == .translation,
                speechController: speechController
            )
            .frame(minHeight: 120, maxHeight: .infinity)
        }
        .onDisappear {
            speechController.stop()
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
    @ObservedObject var speechController: TextSpeechController

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
            SpeechActionButton(
                title: speechController.activeTarget == .original
                    ? L10n.string("panel.stop_reading", defaultValue: "Stop Reading")
                    : L10n.string("panel.read_original", defaultValue: "Read Original"),
                isSpeaking: speechController.activeTarget == .original,
                isDisabled: viewModel.draftOriginal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                action: {
                    speechController.toggle(
                        target: .original,
                        text: viewModel.draftOriginal,
                        languageIdentifier: viewModel.sourceLanguageIdentifier
                    )
                }
            )
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
    @ObservedObject var speechController: TextSpeechController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    L10n.string("panel.translation", defaultValue: "Translation"),
                    systemImage: "character.bubble"
                )
                .font(.system(size: 12, weight: .semibold))
                Spacer()
                SpeechActionButton(
                    title: speechController.activeTarget == .translation
                        ? L10n.string("panel.stop_reading", defaultValue: "Stop Reading")
                        : L10n.string("panel.read_translation", defaultValue: "Read Translation"),
                    isSpeaking: speechController.activeTarget == .translation,
                    isDisabled: translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: {
                        speechController.toggle(
                            target: .translation,
                            text: translated,
                            languageIdentifier: viewModel.targetLanguageIdentifier
                        )
                    }
                )
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

private enum SpeechTarget: Equatable {
    case original
    case translation
}

@MainActor
private final class TextSpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var activeTarget: SpeechTarget?

    private let synthesizer = AVSpeechSynthesizer()
    private var mandarinProcess: Process?
    private var mandarinProcessIdentifier: UUID?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot",
        category: "Speech"
    )
    private var activeUtteranceIdentifier: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(target: SpeechTarget, text: String, languageIdentifier: String?) {
        if activeTarget == target {
            stop()
            return
        }

        stop()

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if SpeechVoiceResolver.requiresPinnedMandarinVoice(for: languageIdentifier),
           startMandarinSpeech(trimmedText) {
            activeTarget = target
            activeUtteranceIdentifier = nil
            logger.info(
                "Speech engine=say selectedLanguage=zh-CN selectedName=\(SpeechVoiceResolver.mandarinVoiceName, privacy: .public)"
            )
            return
        }

        let utterance = AVSpeechUtterance(string: trimmedText)
        if let voice = SpeechVoiceResolver.voice(for: languageIdentifier) {
            utterance.voice = voice
            logger.info(
                "Speech voice requested=\(languageIdentifier ?? "system", privacy: .public) selectedLanguage=\(voice.language, privacy: .public) selectedName=\(voice.name, privacy: .public) selectedIdentifier=\(voice.identifier, privacy: .public)"
            )
        } else {
            logger.error("No speech voice found for \(languageIdentifier ?? "system", privacy: .public)")
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        activeTarget = target
        activeUtteranceIdentifier = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
    }

    func stop() {
        activeTarget = nil
        activeUtteranceIdentifier = nil
        mandarinProcessIdentifier = nil
        if mandarinProcess?.isRunning == true {
            mandarinProcess?.terminate()
        }
        mandarinProcess = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func startMandarinSpeech(_ text: String) -> Bool {
        let process = Process()
        let inputPipe = Pipe()
        let processIdentifier = UUID()
        process.executableURL = SpeechVoiceResolver.sayExecutableURL
        process.arguments = ["-v", SpeechVoiceResolver.mandarinVoiceName]
        process.standardInput = inputPipe
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard self?.mandarinProcessIdentifier == processIdentifier else { return }
                self?.mandarinProcess = nil
                self?.mandarinProcessIdentifier = nil
                self?.activeTarget = nil
            }
        }

        do {
            try process.run()
            mandarinProcess = process
            mandarinProcessIdentifier = processIdentifier
            inputPipe.fileHandleForWriting.write(Data(text.utf8))
            try inputPipe.fileHandleForWriting.close()
            return true
        } catch {
            logger.error("Unable to launch pinned Mandarin voice: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        finishIfActive(utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        finishIfActive(utterance)
    }

    nonisolated private func finishIfActive(_ utterance: AVSpeechUtterance) {
        let identifier = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in
            guard self?.activeUtteranceIdentifier == identifier else { return }
            self?.activeTarget = nil
            self?.activeUtteranceIdentifier = nil
        }
    }

}

enum SpeechVoiceResolver {
    static let mandarinVoiceIdentifier = "com.apple.voice.compact.zh-CN.Tingting"
    static let mandarinVoiceName = "Tingting"
    static let sayExecutableURL = URL(fileURLWithPath: "/usr/bin/say")

    private static let mandarinFallbackIdentifiers = [
        mandarinVoiceIdentifier,
        "com.apple.ttsbundle.siri_yushu_zh-CN_compact",
        "com.apple.ttsbundle.siri_limu_zh-CN_compact"
    ]

    static func voice(for languageIdentifier: String?) -> AVSpeechSynthesisVoice? {
        guard let languageIdentifier else { return nil }

        if LanguageRouter.isChinese(Locale.Language(identifier: languageIdentifier)) {
            for identifier in mandarinFallbackIdentifiers {
                if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                    return voice
                }
            }
            if let installedMandarinVoice = AVSpeechSynthesisVoice.speechVoices().first(where: {
                $0.language.caseInsensitiveCompare("zh-CN") == .orderedSame
            }) {
                return installedMandarinVoice
            }
            return AVSpeechSynthesisVoice(language: "zh-CN")
        }

        if let exactVoice = AVSpeechSynthesisVoice(language: languageIdentifier) {
            return exactVoice
        }
        guard let languageCode = Locale.Language(identifier: languageIdentifier).languageCode?.identifier else {
            return nil
        }
        return AVSpeechSynthesisVoice(language: languageCode)
    }

    static func requiresPinnedMandarinVoice(for languageIdentifier: String?) -> Bool {
        guard let languageIdentifier else { return false }
        return LanguageRouter.isChinese(Locale.Language(identifier: languageIdentifier))
    }
}

private struct SpeechActionButton: View {
    let title: String
    let isSpeaking: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSpeaking ? Color.accentColor : Color.primary)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isSpeaking
                                ? Color.accentColor.opacity(0.13)
                                : Color.primary.opacity(isHovering ? 0.075 : 0)
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(title)
        .accessibilityLabel(title)
    }
}
