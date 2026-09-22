import AppKit
import SwiftUI

@main
struct TranslateDotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            Button {
                appDelegate.translateSelection()
            } label: {
                Label(
                    L10n.string("menu.translate_selection", defaultValue: "Translate Selection"),
                    systemImage: "character.bubble"
                )
            }


            Button {
                appDelegate.translateScreenshot()
            } label: {
                Label(
                    L10n.string("menu.translate_screenshot", defaultValue: "Screenshot Translation"),
                    systemImage: "viewfinder"
                )
            }

            SettingsLink {
                Label(
                    L10n.string("menu.settings", defaultValue: "Settings…"),
                    systemImage: "gearshape"
                )
            }

            Divider()

            Button {
                appDelegate.openAccessibilitySettings()
            } label: {
                Label(
                    appDelegate.accessibilityPermissionTitle,
                    systemImage: appDelegate.isAccessibilityTrusted ? "checkmark.shield" : "hand.raised"
                )
            }

            Divider()

            Button {
                appDelegate.showAbout()
            } label: {
                Text(L10n.string("menu.about", defaultValue: "About TranslateDot"))
            }

            Button {
                appDelegate.quit()
            } label: {
                Text(L10n.string("menu.quit", defaultValue: "Quit TranslateDot"))
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: menuBarIcon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .accessibilityLabel("TranslateDot")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(settings: settings)
        }
    }

    private var menuBarIcon: NSImage {
        let source = NSApp.applicationIconImage
            ?? NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "TranslateDot")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        let image = (source.copy() as? NSImage) ?? source
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }
}
