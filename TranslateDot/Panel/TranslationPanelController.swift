import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController: NSObject, NSWindowDelegate {
    private let panel: TranslationPanel
    private let positioner = PanelPositioner()
    private let settings: AppSettings
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    init(viewModel: TranslationViewModel, coordinator: TranslationCoordinator, settings: AppSettings) {
        self.settings = settings
        let panelSize = settings.panelSize
        panel = TranslationPanel(
            contentRect: CGRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.minSize = AppSettings.minimumPanelSize
        panel.maxSize = AppSettings.maximumPanelSize
        panel.delegate = self

        let root = AppleTranslationHost(coordinator: coordinator) {
            TranslationPanelView(viewModel: viewModel)
        }
        let hostingController = NSHostingController(rootView: root)
        hostingController.view.frame = CGRect(origin: .zero, size: panelSize)
        panel.contentViewController = hostingController

        installOutsideClickMonitors()
        installKeyboardMonitors()
    }

    func show(anchor: CGRect?) {
        let desiredSize = settings.panelSize
        if panel.frame.size != desiredSize {
            panel.setContentSize(desiredSize)
        }
        let frames = NSScreen.screens.map(\.visibleFrame)
        let placement = positioner.placement(
            panelSize: panel.frame.size,
            selectionBounds: anchor,
            visibleScreenFrames: frames,
            mouseLocation: NSEvent.mouseLocation
        )
        panel.setFrameOrigin(placement.origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func focusTextInput() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func windowDidResize(_ notification: Notification) {
        settings.updatePanelSize(panel.frame.size)
    }

    private func installOutsideClickMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hideIfPointerIsOutside()
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.hideIfPointerIsOutside()
            }
            return event
        }
    }

    private func hideIfPointerIsOutside() {
        guard panel.isVisible else { return }
        if !panel.frame.contains(NSEvent.mouseLocation) {
            hide()
        }
    }

    private func installKeyboardMonitors() {
        // Esc dismisses the panel while the panel itself is key (e.g. during manual input).
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode, let self else { return event }
            let consumesEvent = MainActor.assumeIsolated {
                guard self.panel.isVisible, self.panel.isKeyWindow else { return false }
                self.hide()
                return true
            }
            return consumesEvent ? nil : event
        }
        // Esc also dismisses when the panel floats above another app and
        // TranslateDot never became the active application.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode else { return }
            Task { @MainActor [weak self] in
                guard let self, self.panel.isVisible, !self.panel.isKeyWindow else { return }
                self.hide()
            }
        }
    }

    private static let escapeKeyCode: UInt16 = 53 // kVK_Escape
}
