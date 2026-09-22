import Combine
import Foundation
import os
@preconcurrency import Translation

@MainActor
final class TranslationCoordinator: ObservableObject {
    @Published private(set) var configuration: TranslationSession.Configuration?

    struct Work: Sendable, Equatable {
        let request: TranslationRequest
        let route: LanguageRoute
        let needsPreparation: Bool
    }

    enum HostFailure: Sendable {
        case unsupportedLanguage
        case unableToIdentifyLanguage
        case nothingToTranslate
        case framework
        case unknown
    }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simon.translatedot", category: "Translation")
    private let viewModel: TranslationViewModel
    private let settings: AppSettings
    private let router: LanguageRouter
    private let availability: LanguageAvailability
    private var preflightTask: Task<Void, Never>?
    private var pending: Work?
    private var currentRequestID: UUID?

    init(
        viewModel: TranslationViewModel,
        settings: AppSettings = .shared,
        router: LanguageRouter = LanguageRouter(),
        availability: LanguageAvailability = LanguageAvailability()
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.router = router
        self.availability = availability
    }

    func submit(_ request: TranslationRequest) {
        preflightTask?.cancel()
        currentRequestID = request.id
        pending = nil
        viewModel.cancelActiveTranslation()

        preflightTask = Task { @MainActor [weak self] in
            await self?.prepare(request)
        }
    }

    private func prepare(_ request: TranslationRequest) async {
        let route = router.route(text: request.text, preferences: settings.routingPreferences)
        logger.info(
            "Translation route source=\(route.source?.minimalIdentifier ?? "auto", privacy: .public) target=\(route.target.minimalIdentifier, privacy: .public)"
        )
        do {
            let status: LanguageAvailability.Status
            if let source = route.source {
                if source.minimalIdentifier == route.target.minimalIdentifier {
                    throw TranslationWorkflowError.sameLanguage
                }
                status = await availability.status(from: source, to: route.target)
            } else {
                status = try await availability.status(for: request.text, to: route.target)
            }

            try Task.checkCancellation()
            guard currentRequestID == request.id else { return }
            guard status != .unsupported else {
                throw TranslationWorkflowError.unsupportedLanguagePair
            }

            pending = Work(
                request: request,
                route: route,
                needsPreparation: status == .supported
            )
            triggerTranslation(for: route)
        } catch is CancellationError {
            logger.debug("Translation preflight cancelled")
        } catch let error as TranslationWorkflowError {
            guard currentRequestID == request.id else { return }
            logger.error("Translation preflight error: \(String(describing: error), privacy: .public)")
            viewModel.showFailure(error.userMessage, requestID: request.id)
        } catch {
            guard currentRequestID == request.id else { return }
            logger.error("Translation preflight error type: \(String(describing: type(of: error)), privacy: .public)")
            viewModel.showFailure(TranslationWorkflowError.frameworkFailure.userMessage, requestID: request.id)
        }
    }

    private func triggerTranslation(for route: LanguageRoute) {
        if var existing = configuration,
           existing.source == route.source,
           existing.target == route.target {
            existing.invalidate()
            configuration = existing
        } else {
            configuration = TranslationSession.Configuration(source: route.source, target: route.target)
        }
    }

    func currentWork() -> Work? {
        guard let pending, pending.request.id == currentRequestID else { return nil }
        return pending
    }

    func translationWillPrepare(_ work: Work) {
        guard work.request.id == currentRequestID else { return }
        viewModel.showPreparing(for: work.request)
    }

    func translationDidComplete(_ work: Work, response: TranslationSession.Response) {
        guard work.request.id == currentRequestID else { return }
        let translated = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else {
            viewModel.showFailure(TranslationWorkflowError.emptyResult.userMessage, requestID: work.request.id)
            return
        }
        viewModel.showSuccess(
            TranslationResult(
                translatedText: response.targetText,
                sourceLanguage: response.sourceLanguage,
                targetLanguage: response.targetLanguage
            ),
            for: work.request,
            sourceLabel: work.route.source.map(Self.displayName(for:)) ?? L10n.string(
                "language.auto_detect",
                defaultValue: "Auto-detect"
            ),
            targetLabel: Self.displayName(for: work.route.target)
        )
    }

    func translationDidFail(_ work: Work, failure: HostFailure) {
        guard work.request.id == currentRequestID else { return }
        switch failure {
        case .unsupportedLanguage:
            logger.error("Translation framework error type: unsupportedLanguage")
            viewModel.showUnsupported(TranslationWorkflowError.unsupportedLanguagePair.userMessage, requestID: work.request.id)
            return
        case .unableToIdentifyLanguage:
            logger.error("Translation framework error type: unableToIdentifyLanguage")
            viewModel.showFailure(
                L10n.string(
                    "error.unable_identify_language",
                    defaultValue: "Couldn't reliably identify the source language. Select a longer passage and try again."
                ),
                requestID: work.request.id
            )
            return
        case .nothingToTranslate:
            logger.error("Translation framework error type: nothingToTranslate")
            viewModel.showFailure(
                L10n.string("error.nothing_to_translate", defaultValue: "The selected text contains nothing to translate."),
                requestID: work.request.id
            )
            return
        case .framework:
            logger.error("Translation framework error type: frameworkFailure")
        case .unknown:
            logger.error("Translation failed with an unknown error type")
        }
        viewModel.showFailure(TranslationWorkflowError.frameworkFailure.userMessage, requestID: work.request.id)
    }

    func translationWasCancelled(_ work: Work) {
        guard work.request.id == currentRequestID else { return }
        logger.debug("Translation host task cancelled")
    }

    private static func displayName(for language: Locale.Language) -> String {
        let identifier = language.minimalIdentifier
        return Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }
}
