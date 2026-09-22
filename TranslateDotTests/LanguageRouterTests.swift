import Foundation
import XCTest
@testable import TranslateDot

final class LanguageRouterTests: XCTestCase {
    private let router = LanguageRouter()

    func testChineseRoutesToEnglish() {
        assertRoute("zh", target: "en")
    }

    func testSimplifiedChineseRoutesToEnglish() {
        assertRoute("zh-Hans", target: "en")
    }

    func testTraditionalChineseRoutesToEnglish() {
        assertRoute("zh-Hant", target: "en")
    }

    func testCantoneseRoutesToEnglish() {
        assertRoute("yue", target: "en")
    }

    func testEnglishRoutesToSimplifiedChinese() {
        assertRoute("en", target: "zh-Hans")
    }

    func testJapaneseRoutesToSimplifiedChinese() {
        assertRoute("ja", target: "zh-Hans")
    }

    func testUnknownRoutesToSimplifiedChinese() {
        let route = router.route(detectedLanguage: nil)
        assertSimplifiedChinese(route.target)
        XCTAssertNil(route.source)
    }

    func testLowConfidenceCommandLineTextFallsBackToEnglish() {
        assertEnglishTechnicalText("npx changelogithub")
        assertEnglishTechnicalText("npm install")
    }

    func testLowConfidenceProductPhraseFallsBackToEnglish() {
        assertEnglishTechnicalText("Developer Program")
    }

    func testAmbiguousShortChineseTextUsesPreferredSimplifiedModel() {
        let route = router.route(text: "原因")
        XCTAssertEqual(route.source?.languageCode?.identifier, "zh")
        XCTAssertEqual(route.source?.script?.identifier, "Hans")
        XCTAssertEqual(route.target.languageCode?.identifier, "en")
    }

    func testConfidentShortLatinLanguageIsPreserved() {
        let route = router.route(text: "bonjour")
        XCTAssertEqual(route.source?.languageCode?.identifier, "fr")
        assertSimplifiedChinese(route.target)
    }

    func testFixedSourceLanguageOverridesTechnicalTextFallback() {
        let preferences = LanguageRoutingPreferences(
            sourceLanguageIdentifier: "de",
            targetLanguageIdentifier: "zh-Hans",
            automaticallyReverseLanguages: true,
            reverseTargetLanguageIdentifier: "en"
        )
        let route = router.route(text: "Developer Program", preferences: preferences)
        XCTAssertEqual(route.source?.languageCode?.identifier, "de")
    }

    func testCustomFixedTargetLanguage() {
        let preferences = LanguageRoutingPreferences(
            sourceLanguageIdentifier: nil,
            targetLanguageIdentifier: "ja",
            automaticallyReverseLanguages: false,
            reverseTargetLanguageIdentifier: "en"
        )
        let route = router.route(
            detectedLanguage: Locale.Language(identifier: "en"),
            preferences: preferences
        )
        XCTAssertEqual(route.target.languageCode?.identifier, "ja")
    }

    func testCustomReverseLanguage() {
        let preferences = LanguageRoutingPreferences(
            sourceLanguageIdentifier: nil,
            targetLanguageIdentifier: "ja",
            automaticallyReverseLanguages: true,
            reverseTargetLanguageIdentifier: "fr"
        )
        let route = router.route(
            detectedLanguage: Locale.Language(identifier: "ja"),
            preferences: preferences
        )
        XCTAssertEqual(route.target.languageCode?.identifier, "fr")
    }

    func testChineseVariantsBelongToSameLanguageFamily() {
        XCTAssertTrue(LanguageRouter.sameLanguageFamily(
            Locale.Language(identifier: "zh-Hant"),
            Locale.Language(identifier: "zh-Hans")
        ))
    }

    func testAutoDetectedChineseUsesPreferredSimplifiedVariant() {
        let normalized = LanguageRouter.normalizedAutoDetectedLanguage(
            Locale.Language(identifier: "yue"),
            preferredTarget: Locale.Language(identifier: "zh-Hans")
        )
        XCTAssertEqual(normalized?.languageCode?.identifier, "zh")
        XCTAssertEqual(normalized?.script?.identifier, "Hans")
    }

    func testAutoDetectedChineseUsesPreferredTraditionalVariant() {
        let normalized = LanguageRouter.normalizedAutoDetectedLanguage(
            Locale.Language(identifier: "zh-Hans"),
            preferredTarget: Locale.Language(identifier: "zh-Hant")
        )
        XCTAssertEqual(normalized?.languageCode?.identifier, "zh")
        XCTAssertEqual(normalized?.script?.identifier, "Hant")
    }

    func testSupportedChineseIdentifiersRemainVisibleAsSimplifiedAndTraditional() {
        XCTAssertEqual(
            LanguageRouter.canonicalTranslationIdentifier(for: Locale.Language(identifier: "zh")),
            "zh-Hans"
        )
        XCTAssertEqual(
            LanguageRouter.canonicalTranslationIdentifier(for: Locale.Language(identifier: "zh-TW")),
            "zh-Hant"
        )
    }

    private func assertRoute(_ source: String, target: String) {
        let language = Locale.Language(identifier: source)
        let route = router.route(detectedLanguage: language)
        if target == "zh-Hans" {
            assertSimplifiedChinese(route.target)
        } else {
            XCTAssertEqual(route.target.languageCode?.identifier, target)
        }
        XCTAssertEqual(route.source, language)
    }

    private func assertEnglishTechnicalText(_ text: String) {
        let route = router.route(text: text)
        XCTAssertEqual(route.source?.languageCode?.identifier, "en")
        assertSimplifiedChinese(route.target)
    }

    private func assertSimplifiedChinese(_ language: Locale.Language) {
        XCTAssertEqual(language.languageCode?.identifier, "zh")
        XCTAssertEqual(language.script?.identifier, "Hans")
    }
}
