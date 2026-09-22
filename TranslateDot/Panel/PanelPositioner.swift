import CoreGraphics
import Foundation

struct PanelPlacement: Equatable, Sendable {
    let origin: CGPoint
    let screenFrame: CGRect
}

struct PanelPositioner: Sendable {
    var gap: CGFloat = 10
    var edgeInset: CGFloat = 12

    func placement(
        panelSize: CGSize,
        selectionBounds: CGRect?,
        visibleScreenFrames: [CGRect],
        mouseLocation: CGPoint
    ) -> PanelPlacement {
        let fallback = CGRect(x: mouseLocation.x - 1, y: mouseLocation.y - 1, width: 2, height: 2)
        let anchor = selectionBounds ?? fallback
        let screen = bestScreen(for: anchor, mouseLocation: mouseLocation, frames: visibleScreenFrames)
            ?? CGRect(origin: .zero, size: panelSize)

        let minX = screen.minX + edgeInset
        let maxX = max(minX, screen.maxX - edgeInset - panelSize.width)
        let proposedX = anchor.midX - panelSize.width / 2
        let x = min(max(proposedX, minX), maxX)

        let spaceBelow = anchor.minY - screen.minY
        let spaceAbove = screen.maxY - anchor.maxY
        let belowY = anchor.minY - gap - panelSize.height
        let aboveY = anchor.maxY + gap
        let proposedY: CGFloat
        if spaceBelow >= panelSize.height + gap || spaceBelow >= spaceAbove {
            proposedY = belowY
        } else {
            proposedY = aboveY
        }

        let minY = screen.minY + edgeInset
        let maxY = max(minY, screen.maxY - edgeInset - panelSize.height)
        let y = min(max(proposedY, minY), maxY)
        return PanelPlacement(origin: CGPoint(x: x, y: y), screenFrame: screen)
    }

    private func bestScreen(for anchor: CGRect, mouseLocation: CGPoint, frames: [CGRect]) -> CGRect? {
        if let containingCenter = frames.first(where: { $0.contains(CGPoint(x: anchor.midX, y: anchor.midY)) }) {
            return containingCenter
        }

        let intersecting = frames
            .map { ($0, $0.intersection(anchor)) }
            .filter { !$0.1.isNull }
            .max { lhs, rhs in lhs.1.width * lhs.1.height < rhs.1.width * rhs.1.height }
        if let intersecting { return intersecting.0 }

        return frames.first(where: { $0.contains(mouseLocation) }) ?? frames.first
    }
}
