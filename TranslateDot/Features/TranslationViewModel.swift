import AppKit
import Combine
import Foundation
import os

enum TranslationCopyTarget: Equatable {
    case original
    case translation
}

enum TranslationViewState: Equatable {
    case idle
    case recognizingScreenshot
    case loading(original: String)
    case preparing(original: String)
    case success(original: String, translated: String, source: String, target: String, copied: TranslationCopyTarget?)
    case permissionRequired
    case screenCapturePermissionRequired
    case noSelection(message: String)
    case manualInput(hint: String)
    case unsupported(message: String)
    case failure(message: String)
}

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published private(set) var state: TranslationViewState = .idle
    @Published private(set) var draftOriginal = ""
    @Published private(set) var manualInputText = ""
    @Published private(set) var isRetranslating = false
    private(set) var sourceLanguageIdentifier: String?
    private(set) var targetLanguageIdentifier: String?

    static let maximumEditableCharacterCount = AXSelectedTextProvider.maximumCharacterCount

    var onOpenAccessibilitySettings: (() -> Void)?
    var onRetryAccessibility: (() -> Void)?
    var onOpenScreenCaptureSettings: (() -> Void)?
    var onRetryScreenCapture: (() -> Void)?
    var onRetranslate: ((String) -> Void)?
    var onManualTranslate: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "ViewModel")
    private let pasteboard: NSPasteboard
    private var currentRequestID: UUID?
    private var activeTask: Task<Void, Never>?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func showLoading(for request: TranslationRequest) {
        activeTask?.cancel()
        currentRequestID = request.id
        draftOriginal = request.text
        isRetranslating = false
        sourceLanguageIdentifier = nil
        targetLanguageIdentifier = nil
        state = .loading(original: request.text)
        logger.debug("State changed to loading")
    }

    func beginRetranslation(for request: TranslationRequest) {
        guard case .success = state else {
            showLoading(for: request)
            return
        }
        activeTask?.cancel()
        currentRequestID = request.id
        draftOriginal = request.text
        isRetranslating = true
        logger.debug("Retranslation started without replacing the current result")
    }

    func showRecognizingScreenshot() {
        cancelAndResetRequest()
        isRetranslating = false
        state = .recognizingScreenshot
        logger.debug("State changed to screenshot recognition")
    }

    func showPreparing(for request: TranslationRequest) {
        guard currentRequestID == request.id else { return }
        guard !isRetranslating else { return }
        state = .preparing(original: request.text)
        logger.debug("State changed to preparing")
    }

    func execute(
        request: TranslationRequest,
        sourceLabel: String,
        targetLabel: String,
        operation: @escaping @MainActor () async throws -> TranslationResult
    ) async {
        activeTask?.cancel()
        currentRequestID = request.id

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await operation()
                try Task.checkCancellation()
                guard self.currentRequestID == request.id else { return }
                let elapsed = request.createdAt.duration(to: .now)
                self.logger.info("Translation request completed in \(String(describing: elapsed), privacy: .public)")
                self.isRetranslating = false
                self.sourceLanguageIdentifier = Self.speechIdentifier(for: result.sourceLanguage)
                self.targetLanguageIdentifier = Self.speechIdentifier(for: result.targetLanguage)
                self.state = .success(
                    original: request.text,
                    translated: result.translatedText,
                    source: Self.displayName(result.sourceLanguage, fallback: sourceLabel),
                    target: Self.displayName(result.targetLanguage, fallback: targetLabel),
                    copied: nil
                )
            } catch is CancellationError {
                self.logger.debug("Translation request cancelled")
            } catch let error as TranslationWorkflowError {
                guard self.currentRequestID == request.id else { return }
                self.isRetranslating = false
                self.logger.error("Translation workflow error: \(String(describing: error), privacy: .public)")
                self.state = .failure(message: error.userMessage)
            } catch {
                guard self.currentRequestID == request.id else { return }
                self.isRetranslating = false
                self.logger.error("Translation error type: \(String(describing: type(of: error)), privacy: .public)")
                self.state = .failure(message: TranslationWorkflowError.frameworkFailure.userMessage)
            }
        }
        activeTask = task
        await task.value
    }

    func cancelActiveTranslation() {
        activeTask?.cancel()
        activeTask = nil
    }

    func showSuccess(
        _ result: TranslationResult,
        for request: TranslationRequest,
        sourceLabel: String,
        targetLabel: String
    ) {
        guard currentRequestID == request.id else { return }
        draftOriginal = request.text
        isRetranslating = false
        let elapsed = request.createdAt.duration(to: .now)
        logger.info("Translation request completed in \(String(describing: elapsed), privacy: .public)")
        sourceLanguageIdentifier = Self.speechIdentifier(for: result.sourceLanguage)
        targetLanguageIdentifier = Self.speechIdentifier(for: result.targetLanguage)
        state = .success(
            original: request.text,
            translated: result.translatedText,
            source: Self.displayName(result.sourceLanguage, fallback: sourceLabel),
            target: Self.displayName(result.targetLanguage, fallback: targetLabel),
            copied: nil
        )
    }

    func showPermissionRequired() {
        cancelAndResetRequest()
        isRetranslating = false
        state = .permissionRequired
    }

    func showScreenCapturePermissionRequired() {
        cancelAndResetRequest()
        isRetranslating = false
        state = .screenCapturePermissionRequired
    }

    func showSelectionError(_ error: SelectedTextError) {
        cancelAndResetRequest()
        isRetranslating = false
        switch error {
        case .permissionRequired:
            state = .permissionRequired
        case .selectedTextUnsupported:
            state = .unsupported(message: error.userMessage)
        default:
            showManualInput(hint: error.userMessage)
        }
    }

    func showNoSelection(message: String) {
        cancelAndResetRequest()
        isRetranslating = false
        state = .noSelection(message: message)
    }

    func showManualInput(hint: String) {
        cancelAndResetRequest()
        isRetranslating = false
        manualInputText = ""
        state = .manualInput(hint: hint)
        logger.debug("State changed to manual input")
    }

    func showFailure(_ message: String, requestID: UUID? = nil) {
        if let requestID, currentRequestID != requestID { return }
        if requestID == nil { cancelAndResetRequest() }
        isRetranslating = false
        state = .failure(message: message)
    }

    func showUnsupported(_ message: String, requestID: UUID? = nil) {
        if let requestID, currentRequestID != requestID { return }
        if requestID == nil { cancelAndResetRequest() }
        isRetranslating = false
        state = .unsupported(message: message)
    }

    func copyOriginal() {
        copy(.original)
    }

    func copyTranslation() {
        copy(.translation)
    }

    var canRetranslate: Bool {
        guard !isRetranslating else { return false }
        guard case .success(let original, _, _, _, _) = state else { return false }
        let trimmedDraft = draftOriginal.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedDraft.isEmpty
            && trimmedDraft.count <= Self.maximumEditableCharacterCount
            && trimmedDraft != trimmedOriginal
    }

    var isDraftTooLong: Bool {
        draftOriginal.count > Self.maximumEditableCharacterCount
    }

    func updateDraftOriginal(_ text: String) {
        draftOriginal = text
        if case .success(let original, let translated, let source, let target, let copied) = state,
           copied != nil {
            state = .success(
                original: original,
                translated: translated,
                source: source,
                target: target,
                copied: nil
            )
        }
    }

    func retranslateDraft() {
        guard canRetranslate else { return }
        onRetranslate?(draftOriginal.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func updateManualInput(_ text: String) {
        manualInputText = text
    }

    var isManualInputTooLong: Bool {
        manualInputText.count > Self.maximumEditableCharacterCount
    }

    var canSubmitManualInput: Bool {
        !trimmedManualInput.isEmpty && !isManualInputTooLong
    }

    func submitManualInput() {
        guard canSubmitManualInput else { return }
        onManualTranslate?(trimmedManualInput)
    }

    private var trimmedManualInput: String {
        manualInputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func copy(_ target: TranslationCopyTarget) {
        guard case .success(let original, let translated, let source, let targetLanguage, _) = state else { return }
        pasteboard.clearContents()
        pasteboard.setString(target == .original ? draftOriginal : translated, forType: .string)
        state = .success(
            original: original,
            translated: translated,
            source: source,
            target: targetLanguage,
            copied: target
        )
    }

    func openAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    func retryAccessibility() {
        onRetryAccessibility?()
    }

    func openScreenCaptureSettings() {
        onOpenScreenCaptureSettings?()
    }

    func retryScreenCapture() {
        onRetryScreenCapture?()
    }

    func dismiss() {
        onDismiss?()
    }

    private func cancelAndResetRequest() {
        cancelActiveTranslation()
        currentRequestID = nil
        sourceLanguageIdentifier = nil
        targetLanguageIdentifier = nil
    }

    private static func displayName(_ language: Locale.Language, fallback: String) -> String {
        Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? fallback
    }

    static func speechIdentifier(for language: Locale.Language) -> String {
        guard LanguageRouter.isChinese(language) else {
            return language.minimalIdentifier
        }
        return "zh-CN"
    }

}
