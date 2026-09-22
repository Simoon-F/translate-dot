import AppKit
import Foundation
import XCTest
@testable import TranslateDot

@MainActor
final class TranslationViewModelTests: XCTestCase {
    func testLoadingToSuccess() async {
        let viewModel = TranslationViewModel()
        let request = TranslationRequest(text: "Hello")
        viewModel.showLoading(for: request)
        XCTAssertEqual(viewModel.state, .loading(original: "Hello"))

        await viewModel.execute(request: request, sourceLabel: "English", targetLabel: "Chinese") {
            TranslationResult(
                translatedText: "你好",
                sourceLanguage: Locale.Language(identifier: "en"),
                targetLanguage: Locale.Language(identifier: "zh-Hans")
            )
        }

        guard case .success(_, let translated, _, _, _) = viewModel.state else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(translated, "你好")
    }

    func testLoadingToFailure() async {
        let viewModel = TranslationViewModel()
        let request = TranslationRequest(text: "Hello")
        viewModel.showLoading(for: request)

        await viewModel.execute(request: request, sourceLabel: "English", targetLabel: "Chinese") {
            throw TranslationWorkflowError.unsupportedLanguagePair
        }

        XCTAssertEqual(viewModel.state, .failure(message: TranslationWorkflowError.unsupportedLanguagePair.userMessage))
    }

    func testNewRequestCancelsOldRequest() async {
        let viewModel = TranslationViewModel()
        let first = TranslationRequest(text: "First")
        let second = TranslationRequest(text: "Second")
        viewModel.showLoading(for: first)

        let firstTask = Task { @MainActor in
            await viewModel.execute(request: first, sourceLabel: "English", targetLabel: "Chinese") {
                try await Task.sleep(for: .seconds(2))
                return Self.result("旧结果")
            }
        }
        await Task.yield()
        viewModel.showLoading(for: second)
        await viewModel.execute(request: second, sourceLabel: "English", targetLabel: "Chinese") {
            Self.result("新结果")
        }
        await firstTask.value

        guard case .success(_, let translated, _, _, _) = viewModel.state else {
            return XCTFail("Expected latest request to succeed")
        }
        XCTAssertEqual(translated, "新结果")
    }

    func testOldResultCannotOverwriteNewResultEvenWhenOperationIgnoresCancellation() async {
        let viewModel = TranslationViewModel()
        let first = TranslationRequest(text: "First")
        let second = TranslationRequest(text: "Second")
        viewModel.showLoading(for: first)

        let firstTask = Task { @MainActor in
            await viewModel.execute(request: first, sourceLabel: "English", targetLabel: "Chinese") {
                do { try await Task.sleep(for: .milliseconds(150)) } catch { }
                return Self.result("过期结果")
            }
        }
        await Task.yield()
        viewModel.showLoading(for: second)
        await viewModel.execute(request: second, sourceLabel: "English", targetLabel: "Chinese") {
            Self.result("最新结果")
        }
        await firstTask.value

        guard case .success(_, let translated, _, _, _) = viewModel.state else {
            return XCTFail("Expected latest request to remain visible")
        }
        XCTAssertEqual(translated, "最新结果")
    }

    func testCopiesOriginalAndTranslationSeparately() {
        let pasteboard = NSPasteboard(name: .init("TranslateDotTests.\(UUID().uuidString)"))
        let viewModel = TranslationViewModel(pasteboard: pasteboard)
        let request = TranslationRequest(text: "Hello")
        viewModel.showLoading(for: request)
        viewModel.showSuccess(
            Self.result("你好"),
            for: request,
            sourceLabel: "English",
            targetLabel: "Chinese"
        )

        viewModel.copyOriginal()
        XCTAssertEqual(pasteboard.string(forType: .string), "Hello")
        guard case .success(_, _, _, _, let copiedOriginal) = viewModel.state else {
            return XCTFail("Expected success state")
        }
        XCTAssertEqual(copiedOriginal, .original)

        viewModel.copyTranslation()
        XCTAssertEqual(pasteboard.string(forType: .string), "你好")
        guard case .success(_, _, _, _, let copiedTranslation) = viewModel.state else {
            return XCTFail("Expected success state")
        }
        XCTAssertEqual(copiedTranslation, .translation)
    }

    private static func result(_ text: String) -> TranslationResult {
        TranslationResult(
            translatedText: text,
            sourceLanguage: Locale.Language(identifier: "en"),
            targetLanguage: Locale.Language(identifier: "zh-Hans")
        )
    }
}
