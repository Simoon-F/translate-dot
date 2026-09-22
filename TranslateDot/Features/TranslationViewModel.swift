import AppKit
import Combine
import Foundation
import os

enum TranslationViewState: Equatable {
    case idle
    case loading(original: String)
    case preparing(original: String)
    case success(original: String, translated: String, source: String, target: String, copied: Bool)
    case permissionRequired
    case noSelection(message: String)
    case unsupported(message: String)
    case failure(message: String)
}

@MainActor
final class TranslationViewModel: ObservableObject {
    @Published private(set) var state: TranslationViewState = .idle

    var onOpenAccessibilitySettings: (() -> Void)?
    var onRetryAccessibility: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "ViewModel")
    private var currentRequestID: UUID?
    private var activeTask: Task<Void, Never>?

    func showLoading(for request: TranslationRequest) {
        activeTask?.cancel()
        currentRequestID = request.id
        state = .loading(original: request.text)
        logger.debug("State changed to loading")
    }

    func showPreparing(for request: TranslationRequest) {
        guard currentRequestID == request.id else { return }
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
                self.state = .success(
                    original: request.text,
                    translated: result.translatedText,
                    source: Self.displayName(result.sourceLanguage, fallback: sourceLabel),
                    target: Self.displayName(result.targetLanguage, fallback: targetLabel),
                    copied: false
                )
            } catch is CancellationError {
                self.logger.debug("Translation request cancelled")
            } catch let error as TranslationWorkflowError {
                guard self.currentRequestID == request.id else { return }
                self.logger.error("Translation workflow error: \(String(describing: error), privacy: .public)")
                self.state = .failure(message: error.userMessage)
            } catch {
                guard self.currentRequestID == request.id else { return }
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
        let elapsed = request.createdAt.duration(to: .now)
        logger.info("Translation request completed in \(String(describing: elapsed), privacy: .public)")
        state = .success(
            original: request.text,
            translated: result.translatedText,
            source: Self.displayName(result.sourceLanguage, fallback: sourceLabel),
            target: Self.displayName(result.targetLanguage, fallback: targetLabel),
            copied: false
        )
    }

    func showPermissionRequired() {
        cancelAndResetRequest()
        state = .permissionRequired
    }

    func showSelectionError(_ error: SelectedTextError) {
        cancelAndResetRequest()
        switch error {
        case .permissionRequired:
            state = .permissionRequired
        case .selectedTextUnsupported:
            state = .unsupported(message: error.userMessage)
        default:
            state = .noSelection(message: error.userMessage)
        }
    }

    func showNoSelection(message: String) {
        cancelAndResetRequest()
        state = .noSelection(message: message)
    }

    func showFailure(_ message: String, requestID: UUID? = nil) {
        if let requestID, currentRequestID != requestID { return }
        if requestID == nil { cancelAndResetRequest() }
        state = .failure(message: message)
    }

    func showUnsupported(_ message: String, requestID: UUID? = nil) {
        if let requestID, currentRequestID != requestID { return }
        if requestID == nil { cancelAndResetRequest() }
        state = .unsupported(message: message)
    }

    func copyTranslation() {
        guard case .success(let original, let translated, let source, let target, _) = state else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translated, forType: .string)
        state = .success(original: original, translated: translated, source: source, target: target, copied: true)
    }

    func openAccessibilitySettings() {
        onOpenAccessibilitySettings?()
    }

    func retryAccessibility() {
        onRetryAccessibility?()
    }

    func dismiss() {
        onDismiss?()
    }

    private func cancelAndResetRequest() {
        cancelActiveTranslation()
        currentRequestID = nil
    }

    private static func displayName(_ language: Locale.Language, fallback: String) -> String {
        Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? fallback
    }
}
