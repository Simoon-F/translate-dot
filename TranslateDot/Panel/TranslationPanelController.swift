import AppKit
import SwiftUI

@MainActor
final class TranslationPanelController {
    private let panelSize = CGSize(width: 440, height: 350)
    private let panel: TranslationPanel
    private let positioner = PanelPositioner()
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    init(viewModel: TranslationViewModel, coordinator: TranslationCoordinator) {
        panel = TranslationPanel(
            contentRect: CGRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false

        let root = AppleTranslationHost(coordinator: coordinator) {
            TranslationPanelView(viewModel: viewModel)
        }
        let hostingController = NSHostingController(rootView: root)
        hostingController.view.frame = CGRect(origin: .zero, size: panelSize)
        panel.contentViewController = hostingController

        installOutsideClickMonitors()
    }

    func show(anchor: CGRect?) {
        let frames = NSScreen.screens.map(\.visibleFrame)
        let placement = positioner.placement(
            panelSize: panelSize,
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
}
