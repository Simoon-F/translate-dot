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

    private func assertSimplifiedChinese(_ language: Locale.Language) {
        XCTAssertEqual(language.languageCode?.identifier, "zh")
        XCTAssertEqual(language.script?.identifier, "Hans")
    }
}
