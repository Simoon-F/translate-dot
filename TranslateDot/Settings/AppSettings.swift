import AppKit
import Foundation
@preconcurrency import Translation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let defaultPanelSize = CGSize(width: 640, height: 500)
    static let minimumPanelSize = CGSize(width: 520, height: 400)
    static let maximumPanelSize = CGSize(width: 1_000, height: 800)

    @Published var sourceLanguageIdentifier: String {
        didSet { defaults.set(sourceLanguageIdentifier, forKey: Keys.sourceLanguage) }
    }
    @Published var targetLanguageIdentifier: String {
        didSet { defaults.set(targetLanguageIdentifier, forKey: Keys.targetLanguage) }
    }
    @Published var automaticallyReverseLanguages: Bool {
        didSet { defaults.set(automaticallyReverseLanguages, forKey: Keys.automaticallyReverse) }
    }
    @Published var reverseTargetLanguageIdentifier: String {
        didSet { defaults.set(reverseTargetLanguageIdentifier, forKey: Keys.reverseTargetLanguage) }
    }
    @Published private(set) var supportedLanguageIdentifiers: [String]
    @Published private(set) var panelSize: CGSize

    private let defaults: UserDefaults

    private enum Keys {
        static let sourceLanguage = "settings.sourceLanguage"
        static let targetLanguage = "settings.targetLanguage"
        static let automaticallyReverse = "settings.automaticallyReverseLanguages"
        static let reverseTargetLanguage = "settings.reverseTargetLanguage"
        static let panelWidth = "panel.width"
        static let panelHeight = "panel.height"
    }

    private static let fallbackLanguageIdentifiers = [
        "zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "it",
        "pt-BR", "nl", "pl", "ru", "ar", "th", "tr", "uk", "vi", "id"
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sourceLanguageIdentifier = defaults.string(forKey: Keys.sourceLanguage) ?? ""
        targetLanguageIdentifier = defaults.string(forKey: Keys.targetLanguage) ?? "zh-Hans"
        reverseTargetLanguageIdentifier = defaults.string(forKey: Keys.reverseTargetLanguage) ?? "en"
        automaticallyReverseLanguages = defaults.object(forKey: Keys.automaticallyReverse) as? Bool ?? true
        supportedLanguageIdentifiers = Self.fallbackLanguageIdentifiers

        let storedWidth = defaults.double(forKey: Keys.panelWidth)
        let storedHeight = defaults.double(forKey: Keys.panelHeight)
        panelSize = Self.clampedPanelSize(CGSize(
            width: storedWidth > 0 ? storedWidth : Self.defaultPanelSize.width,
            height: storedHeight > 0 ? storedHeight : Self.defaultPanelSize.height
        ))

        loadSupportedLanguages()
    }

    var routingPreferences: LanguageRoutingPreferences {
        LanguageRoutingPreferences(
            sourceLanguageIdentifier: sourceLanguageIdentifier.isEmpty ? nil : sourceLanguageIdentifier,
            targetLanguageIdentifier: targetLanguageIdentifier,
            automaticallyReverseLanguages: automaticallyReverseLanguages,
            reverseTargetLanguageIdentifier: reverseTargetLanguageIdentifier
        )
    }

    func languageDisplayName(for identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    func updatePanelSize(_ size: CGSize) {
        let clamped = Self.clampedPanelSize(size)
        guard abs(panelSize.width - clamped.width) >= 1 || abs(panelSize.height - clamped.height) >= 1 else {
            return
        }
        panelSize = clamped
        defaults.set(clamped.width, forKey: Keys.panelWidth)
        defaults.set(clamped.height, forKey: Keys.panelHeight)
    }

    func resetPanelSize() {
        panelSize = Self.defaultPanelSize
        defaults.set(panelSize.width, forKey: Keys.panelWidth)
        defaults.set(panelSize.height, forKey: Keys.panelHeight)
    }

    private func loadSupportedLanguages() {
        Task { @MainActor [weak self] in
            let languages = await LanguageAvailability().supportedLanguages
            guard let self else { return }
            let identifiers = languages.map(LanguageRouter.canonicalTranslationIdentifier(for:))
            let requiredIdentifiers = [
                self.targetLanguageIdentifier,
                self.reverseTargetLanguageIdentifier,
                self.sourceLanguageIdentifier
            ].filter { !$0.isEmpty }
            self.supportedLanguageIdentifiers = Array(Set(identifiers + requiredIdentifiers)).sorted {
                self.languageDisplayName(for: $0).localizedStandardCompare(
                    self.languageDisplayName(for: $1)
                ) == .orderedAscending
            }
        }
    }

    private static func clampedPanelSize(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minimumPanelSize.width), maximumPanelSize.width),
            height: min(max(size.height, minimumPanelSize.height), maximumPanelSize.height)
        )
    }
}
