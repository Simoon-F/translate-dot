import CoreGraphics
import Foundation

struct TranslationRequest: Identifiable, Sendable, Equatable {
    let id: UUID
    let text: String
    let selectionBounds: CGRect?
    let createdAt: ContinuousClock.Instant

    init(
        id: UUID = UUID(),
        text: String,
        selectionBounds: CGRect? = nil,
        createdAt: ContinuousClock.Instant = .now
    ) {
        self.id = id
        self.text = text
        self.selectionBounds = selectionBounds
        self.createdAt = createdAt
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.text == rhs.text && lhs.selectionBounds == rhs.selectionBounds
    }
}
