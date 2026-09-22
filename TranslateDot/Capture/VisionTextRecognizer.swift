import CoreGraphics
import Foundation
@preconcurrency import Vision

enum VisionTextRecognitionError: LocalizedError {
    case noText

    var errorDescription: String? {
        L10n.string(
            "error.screenshot_no_text",
            defaultValue: "No recognizable text was found in the selected area."
        )
    }
}

final class VisionTextRecognizer: @unchecked Sendable {
    func recognizeText(in image: CGImage, sourceLanguageIdentifier: String?) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            if let sourceLanguageIdentifier, !sourceLanguageIdentifier.isEmpty {
                let supportedLanguages = try request.supportedRecognitionLanguages()
                let normalizedSource = sourceLanguageIdentifier.lowercased()
                if let recognitionLanguage = supportedLanguages.first(where: {
                    let candidate = $0.lowercased()
                    return candidate == normalizedSource
                        || candidate.hasPrefix("\(normalizedSource)-")
                        || normalizedSource.hasPrefix("\(candidate)-")
                }) {
                    request.recognitionLanguages = [recognitionLanguage]
                }
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            try Task.checkCancellation()

            let observations = (request.results ?? []).sorted { lhs, rhs in
                let verticalDistance = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
                if verticalDistance > 0.02 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { throw VisionTextRecognitionError.noText }
            return text
        }.value
    }
}
