import Foundation
import NaturalLanguage

struct LanguageRoute: Sendable, Equatable {
    let source: Locale.Language?
    let target: Locale.Language
    let sourceWasRecognized: Bool
}

struct LanguageRouter: Sendable {
    private static let chineseLanguageCodes: Set<String> = ["zh", "yue", "cmn", "wuu", "hak", "nan"]

    func route(text: String) -> LanguageRoute {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage.map { Locale.Language(identifier: $0.rawValue) }
        return route(detectedLanguage: language)
    }

    func route(detectedLanguage: Locale.Language?) -> LanguageRoute {
        let isChinese = detectedLanguage.map(Self.isChinese) ?? false
        return LanguageRoute(
            source: detectedLanguage,
            target: Locale.Language(identifier: isChinese ? "en" : "zh-Hans"),
            sourceWasRecognized: detectedLanguage != nil
        )
    }

    static func isChinese(_ language: Locale.Language) -> Bool {
        let identifier = language.minimalIdentifier.lowercased()
        let primaryCode = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? identifier
        return chineseLanguageCodes.contains(primaryCode)
    }
}
