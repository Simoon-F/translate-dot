import SwiftUI
@preconcurrency import Translation

/// A long-lived host view owns every TranslationSession through `translationTask`.
/// The non-Sendable session never leaves the framework-provided task closure.
struct AppleTranslationHost<Content: View>: View {
    @ObservedObject var coordinator: TranslationCoordinator
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .translationTask(coordinator.configuration) { session in
                guard let work = coordinator.currentWork() else { return }

                if work.needsPreparation {
                    coordinator.translationWillPrepare(work)
                }

                do {
                    try Task.checkCancellation()
                    if work.needsPreparation {
                        try await session.prepareTranslation()
                    }
                    try Task.checkCancellation()
                    let response = try await session.translate(work.request.text)
                    try Task.checkCancellation()
                    coordinator.translationDidComplete(work, response: response)
                } catch is CancellationError {
                    coordinator.translationWasCancelled(work)
                } catch let error as TranslationError {
                    let failure: TranslationCoordinator.HostFailure
                    if TranslationError.unsupportedSourceLanguage ~= error
                        || TranslationError.unsupportedTargetLanguage ~= error
                        || TranslationError.unsupportedLanguagePairing ~= error {
                        failure = .unsupportedLanguage
                    } else if TranslationError.unableToIdentifyLanguage ~= error {
                        failure = .unableToIdentifyLanguage
                    } else if TranslationError.nothingToTranslate ~= error {
                        failure = .nothingToTranslate
                    } else {
                        failure = .framework
                    }
                    coordinator.translationDidFail(work, failure: failure)
                } catch {
                    coordinator.translationDidFail(work, failure: .unknown)
                }
            }
    }
}
