import Foundation
import NaturalLanguage

struct LanguageRoute: Sendable, Equatable {
    let source: Locale.Language?
    let target: Locale.Language
    let sourceWasRecognized: Bool
}

struct LanguageRoutingPreferences: Sendable, Equatable {
    var sourceLanguageIdentifier: String?
    var targetLanguageIdentifier: String
    var automaticallyReverseLanguages: Bool
    var reverseTargetLanguageIdentifier: String

    static let `default` = LanguageRoutingPreferences(
        sourceLanguageIdentifier: nil,
        targetLanguageIdentifier: "zh-Hans",
        automaticallyReverseLanguages: true,
        reverseTargetLanguageIdentifier: "en"
    )
}

struct LanguageRouter: Sendable {
    private static let chineseLanguageCodes: Set<String> = ["zh", "yue", "cmn", "wuu", "hak", "nan"]

    func route(
        text: String,
        preferences: LanguageRoutingPreferences = .default
    ) -> LanguageRoute {
        let language: Locale.Language?
        if let identifier = preferences.sourceLanguageIdentifier {
            language = Locale.Language(identifier: identifier)
        } else {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            language = recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue) }
        }
        return route(detectedLanguage: language, preferences: preferences)
    }

    func route(
        detectedLanguage: Locale.Language?,
        preferences: LanguageRoutingPreferences = .default
    ) -> LanguageRoute {
        let defaultTarget = Locale.Language(identifier: preferences.targetLanguageIdentifier)
        let shouldReverse = preferences.automaticallyReverseLanguages
            && detectedLanguage.map { Self.sameLanguageFamily($0, defaultTarget) } == true
        let target = shouldReverse
            ? Locale.Language(identifier: preferences.reverseTargetLanguageIdentifier)
            : defaultTarget
        return LanguageRoute(
            source: detectedLanguage,
            target: target,
            sourceWasRecognized: detectedLanguage != nil
        )
    }

    static func isChinese(_ language: Locale.Language) -> Bool {
        let identifier = language.minimalIdentifier.lowercased()
        let primaryCode = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? identifier
        return chineseLanguageCodes.contains(primaryCode)
    }

    static func sameLanguageFamily(_ lhs: Locale.Language, _ rhs: Locale.Language) -> Bool {
        if isChinese(lhs) && isChinese(rhs) { return true }
        return lhs.languageCode?.identifier == rhs.languageCode?.identifier
    }
}
