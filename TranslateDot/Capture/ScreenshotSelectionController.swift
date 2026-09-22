import AppKit

struct ScreenshotSelection {
    let bounds: CGRect
    let screen: NSScreen
}

@MainActor
final class ScreenshotSelectionController {
    private var panels: [CaptureOverlayPanel] = []
    private var completion: ((ScreenshotSelection?) -> Void)?

    func beginSelection(completion: @escaping (ScreenshotSelection?) -> Void) {
        cancel(notify: false)
        self.completion = completion

        panels = NSScreen.screens.map { screen in
            let panel = CaptureOverlayPanel(screen: screen)
            panel.onSelection = { [weak self, weak panel] localBounds in
                guard let self, let panel else { return }
                let globalBounds = panel.convertToScreen(localBounds)
                self.finish(ScreenshotSelection(bounds: globalBounds, screen: screen))
            }
            panel.onCancel = { [weak self] in
                self?.cancel(notify: true)
            }
            panel.orderFrontRegardless()
            panel.makeKey()
            return panel
        }
        NSApp.activate(ignoringOtherApps: true)
        panels.first?.makeKey()
    }

    func cancel(notify: Bool = true) {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        let callback = completion
        completion = nil
        if notify { callback?(nil) }
    }

    private func finish(_ selection: ScreenshotSelection) {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        let callback = completion
        completion = nil
        callback?(selection)
    }
}

private final class CaptureOverlayPanel: NSPanel {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        isReleasedWhenClosed = false

        let overlay = CaptureOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
        overlay.onSelection = { [weak self] rect in self?.onSelection?(rect) }
        overlay.onCancel = { [weak self] in self?.onCancel?() }
        contentView = overlay
        makeFirstResponder(overlay)
    }
}

private final class CaptureOverlayView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var selectionRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let shadePath = NSBezierPath(rect: bounds)
        if let selectionRect {
            shadePath.appendRect(selectionRect)
            shadePath.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.36).setFill()
        shadePath.fill()

        if let selectionRect {
            NSColor.controlAccentColor.setStroke()
            let border = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = 2
            border.stroke()

            let sizeText = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            drawBadge(sizeText, at: CGPoint(x: selectionRect.minX, y: max(8, selectionRect.minY - 28)))
        } else {
            let instruction = L10n.string(
                "capture.instruction",
                defaultValue: "Drag to select text · Esc to cancel"
            )
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            let size = instruction.size(withAttributes: attributes)
            instruction.draw(
                at: CGPoint(x: (bounds.width - size.width) / 2, y: bounds.maxY - size.height - 56),
                withAttributes: attributes
            )
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        ).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selectionRect,
              selectionRect.width >= 4,
              selectionRect.height >= 4 else {
            startPoint = nil
            self.selectionRect = nil
            needsDisplay = true
            return
        }
        onSelection?(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    private func drawBadge(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let badgeRect = CGRect(
            x: point.x,
            y: point.y,
            width: textSize.width + 14,
            height: textSize.height + 8
        )
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5).fill()
        text.draw(
            at: CGPoint(x: badgeRect.minX + 7, y: badgeRect.minY + 4),
            withAttributes: attributes
        )
    }
}
