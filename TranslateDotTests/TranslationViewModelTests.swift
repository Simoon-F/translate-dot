import AVFoundation
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
        XCTAssertEqual(viewModel.sourceLanguageIdentifier, "en")
        XCTAssertEqual(viewModel.targetLanguageIdentifier, "zh-CN")
    }

    func testChineseSpeechDefaultsToMandarinVoices() {
        XCTAssertEqual(
            TranslationViewModel.speechIdentifier(for: Locale.Language(identifier: "zh-Hans")),
            "zh-CN"
        )
        XCTAssertEqual(
            TranslationViewModel.speechIdentifier(for: Locale.Language(identifier: "zh-Hant")),
            "zh-CN"
        )
        XCTAssertEqual(
            TranslationViewModel.speechIdentifier(for: Locale.Language(identifier: "yue")),
            "zh-CN"
        )
        XCTAssertEqual(
            TranslationViewModel.speechIdentifier(for: Locale.Language(identifier: "zh-HK")),
            "zh-CN"
        )
    }

    func testChineseSpeechPinsTingtingMandarinVoice() {
        let voice = SpeechVoiceResolver.voice(for: "zh-CN")
        XCTAssertEqual(voice?.identifier, SpeechVoiceResolver.mandarinVoiceIdentifier)
        XCTAssertEqual(voice?.language, "zh-CN")
        XCTAssertTrue(SpeechVoiceResolver.requiresPinnedMandarinVoice(for: "zh-CN"))
        XCTAssertTrue(SpeechVoiceResolver.requiresPinnedMandarinVoice(for: "zh-HK"))
        XCTAssertFalse(SpeechVoiceResolver.requiresPinnedMandarinVoice(for: "en"))
        XCTAssertEqual(SpeechVoiceResolver.mandarinVoiceName, "Tingting")
        XCTAssertEqual(SpeechVoiceResolver.sayExecutableURL.path, "/usr/bin/say")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: SpeechVoiceResolver.sayExecutableURL.path))
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

    func testEditedOriginalCanBeRetranslatedAndCopied() {
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

        var submittedText: String?
        viewModel.onRetranslate = { submittedText = $0 }
        viewModel.updateDraftOriginal("  Hello, world  ")

        XCTAssertTrue(viewModel.canRetranslate)
        viewModel.copyOriginal()
        XCTAssertEqual(pasteboard.string(forType: .string), "  Hello, world  ")
        viewModel.retranslateDraft()
        XCTAssertEqual(submittedText, "Hello, world")
    }

    func testUnchangedOrOversizedOriginalCannotBeRetranslated() {
        let viewModel = TranslationViewModel()
        let request = TranslationRequest(text: "Hello")
        viewModel.showLoading(for: request)
        viewModel.showSuccess(
            Self.result("你好"),
            for: request,
            sourceLabel: "English",
            targetLabel: "Chinese"
        )
        XCTAssertFalse(viewModel.canRetranslate)

        viewModel.updateDraftOriginal(String(
            repeating: "a",
            count: TranslationViewModel.maximumEditableCharacterCount + 1
        ))
        XCTAssertTrue(viewModel.isDraftTooLong)
        XCTAssertFalse(viewModel.canRetranslate)
    }

    func testRetranslationKeepsCurrentResultVisibleUntilReplacementArrives() {
        let viewModel = TranslationViewModel()
        let firstRequest = TranslationRequest(text: "Hello")
        viewModel.showLoading(for: firstRequest)
        viewModel.showSuccess(
            Self.result("你好"),
            for: firstRequest,
            sourceLabel: "English",
            targetLabel: "Chinese"
        )
        let visibleState = viewModel.state

        let editedRequest = TranslationRequest(text: "Hello, world")
        viewModel.beginRetranslation(for: editedRequest)
        XCTAssertTrue(viewModel.isRetranslating)
        XCTAssertEqual(viewModel.state, visibleState)
        XCTAssertFalse(viewModel.canRetranslate)

        viewModel.showPreparing(for: editedRequest)
        XCTAssertEqual(viewModel.state, visibleState)

        viewModel.showSuccess(
            Self.result("你好，世界"),
            for: editedRequest,
            sourceLabel: "English",
            targetLabel: "Chinese"
        )
        XCTAssertFalse(viewModel.isRetranslating)
        guard case .success(let original, let translated, _, _, _) = viewModel.state else {
            return XCTFail("Expected replacement result")
        }
        XCTAssertEqual(original, "Hello, world")
        XCTAssertEqual(translated, "你好，世界")
    }

    func testSelectionErrorFallsBackToManualInput() {
        let viewModel = TranslationViewModel()
        viewModel.showLoading(for: TranslationRequest(text: "Hello"))
        viewModel.showSelectionError(.noSelection)

        XCTAssertEqual(
            viewModel.state,
            .manualInput(hint: SelectedTextError.noSelection.userMessage)
        )
        XCTAssertEqual(viewModel.manualInputText, "")
    }

    func testManualInputSubmitsTrimmedTextAndRejectsOversizedInput() {
        let viewModel = TranslationViewModel()
        viewModel.showSelectionError(.noSelection)
        XCTAssertFalse(viewModel.canSubmitManualInput)

        var submittedText: String?
        viewModel.onManualTranslate = { submittedText = $0 }
        viewModel.updateManualInput("  Bonjour le monde  ")
        XCTAssertTrue(viewModel.canSubmitManualInput)
        XCTAssertFalse(viewModel.isManualInputTooLong)
        viewModel.submitManualInput()
        XCTAssertEqual(submittedText, "Bonjour le monde")

        viewModel.updateManualInput(String(
            repeating: "a",
            count: TranslationViewModel.maximumEditableCharacterCount + 1
        ))
        XCTAssertTrue(viewModel.isManualInputTooLong)
        XCTAssertFalse(viewModel.canSubmitManualInput)
        viewModel.submitManualInput()
        XCTAssertEqual(submittedText, "Bonjour le monde")
    }

    private static func result(_ text: String) -> TranslationResult {
        TranslationResult(
            translatedText: text,
            sourceLanguage: Locale.Language(identifier: "en"),
            targetLanguage: Locale.Language(identifier: "zh-Hans")
        )
    }
}
