import AppKit
import SwiftUI
@preconcurrency import Translation

struct LanguageModelPair: Identifiable, Hashable, Sendable {
    let sourceIdentifier: String
    let targetIdentifier: String

    var id: String { "\(sourceIdentifier)->\(targetIdentifier)" }
    var source: Locale.Language { Locale.Language(identifier: sourceIdentifier) }
    var target: Locale.Language { Locale.Language(identifier: targetIdentifier) }
}

private enum LanguageModelInstallState: Equatable {
    case checking
    case installed
    case available
    case unsupported
}

struct LanguageModelsView: View {
    @ObservedObject var settings: AppSettings

    @State private var searchText = ""
    @State private var pairs: [LanguageModelPair] = []
    @State private var states: [String: LanguageModelInstallState] = [:]
    @State private var configuration: TranslationSession.Configuration?
    @State private var pendingPair: LanguageModelPair?
    @State private var errorMessage: String?
    @State private var isRefreshing = false

    private let recommendedPair = LanguageModelPair(
        sourceIdentifier: "en",
        targetIdentifier: "zh-Hans"
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            recommendedSection

            HStack {
                Text(L10n.string("models.all_pairs", defaultValue: "Languages for Current Target"))
                    .font(.headline)
                Spacer()
                if isRefreshing {
                    ProgressView().controlSize(.small)
                }
                Button {
                    Task { await refreshStatuses() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(L10n.string("models.refresh", defaultValue: "Refresh Status"))
            }

            TextField(
                L10n.string("models.search", defaultValue: "Search languages"),
                text: $searchText
            )
            .textFieldStyle(.roundedBorder)

            modelList

            HStack {
                Button(L10n.string("models.system_settings", defaultValue: "Manage in System Settings…")) {
                    openSystemLanguageSettings()
                }
                .buttonStyle(.link)
                Spacer()
                Text(L10n.string(
                    "models.delete_note",
                    defaultValue: "Downloaded models can only be removed in System Settings."
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .task(id: refreshID) {
            await refreshStatuses()
        }
        .translationTask(configuration) { session in
            guard let pair = pendingPair else { return }
            do {
                try await session.prepareTranslation()
                await refreshStatuses()
            } catch is CancellationError {
                // The system sheet was dismissed; keep the current availability state.
            } catch {
                errorMessage = L10n.string(
                    "models.download_failed",
                    defaultValue: "The language download couldn't be completed. Try again."
                )
            }
            if pendingPair?.id == pair.id {
                pendingPair = nil
            }
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.string("models.recommended", defaultValue: "Recommended Setup"))
                        .font(.headline)
                    Text(L10n.string(
                        "models.recommended_message",
                        defaultValue: "Prepare English and Simplified Chinese once for uninterrupted offline translation."
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                modelAction(for: recommendedPair, prominent: true)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var modelList: some View {
        List(filteredPairs) { pair in
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(pair.sourceIdentifier))
                    Text(L10n.formatted(
                        "models.pair_target",
                        defaultValue: "Translate to %@",
                        displayName(pair.targetIdentifier)
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                statusLabel(for: pair)
                modelAction(for: pair, prominent: false)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.inset)
        .overlay {
            if filteredPairs.isEmpty && !isRefreshing {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    @ViewBuilder
    private func statusLabel(for pair: LanguageModelPair) -> some View {
        switch states[pair.id] ?? .checking {
        case .checking:
            ProgressView().controlSize(.small)
        case .installed:
            Label(L10n.string("models.installed", defaultValue: "Installed"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .available:
            Text(L10n.string("models.not_downloaded", defaultValue: "Not Downloaded"))
                .foregroundStyle(.secondary)
        case .unsupported:
            Text(L10n.string("models.unsupported", defaultValue: "Unsupported"))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func modelAction(for pair: LanguageModelPair, prominent: Bool) -> some View {
        let state = states[pair.id] ?? .checking
        if pendingPair?.id == pair.id {
            ProgressView()
                .controlSize(.small)
                .frame(minWidth: 74)
        } else if state == .installed {
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
                .frame(minWidth: 74)
                .accessibilityLabel(L10n.string("models.installed", defaultValue: "Installed"))
        } else {
            if prominent {
                Button(L10n.string("models.download", defaultValue: "Download")) {
                    prepare(pair)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state == .checking || state == .unsupported || pendingPair != nil)
            } else {
                Button(L10n.string("models.download", defaultValue: "Download")) {
                    prepare(pair)
                }
                .buttonStyle(.bordered)
                .disabled(state == .checking || state == .unsupported || pendingPair != nil)
            }
        }
    }

    private var filteredPairs: [LanguageModelPair] {
        guard !searchText.isEmpty else { return pairs }
        return pairs.filter {
            displayName($0.sourceIdentifier).localizedCaseInsensitiveContains(searchText)
                || $0.sourceIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var refreshID: String {
        "\(settings.targetLanguageIdentifier)|\(settings.supportedLanguageIdentifiers.joined(separator: ","))"
    }

    @MainActor
    private func refreshStatuses() async {
        isRefreshing = true
        let targetIdentifier = settings.targetLanguageIdentifier
        pairs = settings.supportedLanguageIdentifiers
            .filter { identifier in
                // Keep sibling variants (e.g. Traditional Chinese when the target is
                // Simplified Chinese) because variant-to-variant translation is
                // supported; only the exact target itself is not a meaningful pair.
                identifier != targetIdentifier
            }
            .map { LanguageModelPair(sourceIdentifier: $0, targetIdentifier: targetIdentifier) }

        let pairsToCheck = Array(Set(pairs + [recommendedPair])).sorted { $0.id < $1.id }
        let availability = LanguageAvailability()
        for pair in pairsToCheck {
            guard !Task.isCancelled else { break }
            states[pair.id] = .checking
            let status = await availability.status(from: pair.source, to: pair.target)
            guard !Task.isCancelled else { break }
            switch status {
            case .installed:
                states[pair.id] = .installed
            case .supported:
                states[pair.id] = .available
            case .unsupported:
                states[pair.id] = .unsupported
            @unknown default:
                states[pair.id] = .unsupported
            }
        }
        isRefreshing = false
    }

    private func prepare(_ pair: LanguageModelPair) {
        errorMessage = nil
        pendingPair = pair
        var newConfiguration = TranslationSession.Configuration(source: pair.source, target: pair.target)
        newConfiguration.invalidate()
        configuration = newConfiguration
    }

    private func displayName(_ identifier: String) -> String {
        settings.languageDisplayName(for: identifier)
    }

    private func openSystemLanguageSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
