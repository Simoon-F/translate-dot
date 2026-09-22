import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        TabView {
            translationSettings
                .tabItem {
                    Label(
                        L10n.string("settings.translation_tab", defaultValue: "Translation"),
                        systemImage: "character.bubble"
                    )
                }

            generalSettings
                .tabItem {
                    Label(
                        L10n.string("settings.general_tab", defaultValue: "General"),
                        systemImage: "gearshape"
                    )
                }
        }
        .frame(width: 620, height: 430)
        .background(SettingsWindowActivationView())
    }

    private var translationSettings: some View {
        Form {
            Section {
                Picker(
                    L10n.string("settings.source_language", defaultValue: "Source Language"),
                    selection: $settings.sourceLanguageIdentifier
                ) {
                    Text(L10n.string("language.auto_detect", defaultValue: "Auto-detect"))
                        .tag("")
                    languageChoices
                }

                Picker(
                    L10n.string("settings.target_language", defaultValue: "Default Target Language"),
                    selection: $settings.targetLanguageIdentifier
                ) {
                    languageChoices
                }

                Toggle(
                    L10n.string(
                        "settings.auto_reverse",
                        defaultValue: "Automatically reverse when the source matches the target"
                    ),
                    isOn: $settings.automaticallyReverseLanguages
                )

                if settings.automaticallyReverseLanguages {
                    Picker(
                        L10n.string("settings.reverse_target", defaultValue: "Reverse Target Language"),
                        selection: $settings.reverseTargetLanguageIdentifier
                    ) {
                        languageChoices
                    }
                }
            } header: {
                Text(L10n.string("settings.languages", defaultValue: "Languages"))
            } footer: {
                Text(L10n.string(
                    "settings.language_footer",
                    defaultValue: "Languages are provided by Apple Translation. A language model may download the first time you use a pair."
                ))
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    private var generalSettings: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder(
                    L10n.string("settings.selection_shortcut", defaultValue: "Translate Selection"),
                    name: .translateSelection
                )
                KeyboardShortcuts.Recorder(
                    L10n.string("settings.screenshot_shortcut", defaultValue: "Screenshot Translation"),
                    name: .translateScreenshot
                )
            } header: {
                Text(L10n.string("settings.shortcuts", defaultValue: "Keyboard Shortcut"))
            } footer: {
                Text(L10n.string(
                    "settings.shortcut_footer",
                    defaultValue: "Use selection translation for selectable text, or drag an area with screenshot translation."
                ))
            }

            Section {
                LabeledContent(L10n.string("settings.saved_size", defaultValue: "Saved Size")) {
                    Text("\(Int(settings.panelSize.width)) × \(Int(settings.panelSize.height))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Button(L10n.string("settings.reset_panel_size", defaultValue: "Reset Window Size")) {
                    settings.resetPanelSize()
                }
            } header: {
                Text(L10n.string("settings.translation_window", defaultValue: "Translation Window"))
            } footer: {
                Text(L10n.string(
                    "settings.window_footer",
                    defaultValue: "Drag the lower-right corner of the translation window to resize it. The size is remembered automatically."
                ))
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var languageChoices: some View {
        ForEach(settings.supportedLanguageIdentifiers, id: \.self) { identifier in
            Text(settings.languageDisplayName(for: identifier))
                .tag(identifier)
        }
    }
}

private struct SettingsWindowActivationView: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsWindowActivationNSView {
        SettingsWindowActivationNSView()
    }

    func updateNSView(_ nsView: SettingsWindowActivationNSView, context: Context) {}
}

private final class SettingsWindowActivationNSView: NSView {
    static let windowIdentifier = NSUserInterfaceItemIdentifier("TranslateDot.SettingsWindow")

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            window.identifier = Self.windowIdentifier
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior.insert(.moveToActiveSpace)
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKey()
        }
    }
}
