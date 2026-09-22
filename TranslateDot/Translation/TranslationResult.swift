import Foundation

struct TranslationResult: Sendable, Equatable {
    let translatedText: String
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
}

enum TranslationWorkflowError: Error, Equatable {
    case unsupportedLanguagePair
    case sameLanguage
    case emptyResult
    case frameworkFailure

    var userMessage: String {
        switch self {
        case .unsupportedLanguagePair:
            return L10n.string(
                "error.translation_unsupported",
                defaultValue: "Apple Translation doesn't support this language pair."
            )
        case .sameLanguage:
            return L10n.string("error.same_language", defaultValue: "The source and target languages are the same.")
        case .emptyResult:
            return L10n.string("error.empty_translation", defaultValue: "The system returned no translation. Try again.")
        case .frameworkFailure:
            return L10n.string(
                "error.translation_failed",
                defaultValue: "Translation failed. Check the language model and try again."
            )
        }
    }
}
