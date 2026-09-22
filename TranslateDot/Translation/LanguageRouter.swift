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
    private static let lowConfidenceThreshold = 0.60

    func route(
        text: String,
        preferences: LanguageRoutingPreferences = .default
    ) -> LanguageRoute {
        let language: Locale.Language?
        if let identifier = preferences.sourceLanguageIdentifier {
            language = Locale.Language(identifier: identifier)
        } else {
            language = Self.normalizedAutoDetectedLanguage(
                detectLanguage(in: text),
                preferredTarget: Locale.Language(identifier: preferences.targetLanguageIdentifier)
            )
        }
        return route(detectedLanguage: language, preferences: preferences)
    }

    private func detectLanguage(in text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        let strongest = hypotheses.max(by: { $0.value < $1.value })
        if Self.isASCIILatinText(text),
           strongest.map(\.value) ?? 0 < Self.lowConfidenceThreshold {
            // Product names and command-line snippets are frequently misclassified as
            // unrelated languages because they are short and absent from the language model.
            return Locale.Language(identifier: "en")
        }

        return recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue) }
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

    static func normalizedAutoDetectedLanguage(
        _ detectedLanguage: Locale.Language?,
        preferredTarget: Locale.Language
    ) -> Locale.Language? {
        guard let detectedLanguage,
              isChinese(detectedLanguage),
              isChinese(preferredTarget) else {
            return detectedLanguage
        }

        // Very short Chinese text is frequently classified as Traditional Chinese or Cantonese
        // even when its characters are shared with Simplified Chinese. Reuse the user's chosen
        // Chinese variant so the same installed model works consistently in both directions.
        return Locale.Language(identifier: canonicalTranslationIdentifier(for: preferredTarget))
    }

    static func canonicalTranslationIdentifier(for language: Locale.Language) -> String {
        guard language.languageCode?.identifier == "zh" else {
            return language.minimalIdentifier
        }
        return language.script?.identifier == "Hant" ? "zh-Hant" : "zh-Hans"
    }

    private static func isASCIILatinText(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { scalar in
            (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
        }
    }
}
