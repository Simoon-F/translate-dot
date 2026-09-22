import CoreGraphics
import XCTest
@testable import TranslateDot

final class PanelPositionerTests: XCTestCase {
    private let positioner = PanelPositioner(gap: 10, edgeInset: 12)
    private let size = CGSize(width: 400, height: 300)

    func testPlacesBelowWhenThereIsEnoughSpace() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let anchor = CGRect(x: 600, y: 600, width: 120, height: 20)
        let result = positioner.placement(panelSize: size, selectionBounds: anchor, visibleScreenFrames: [screen], mouseLocation: .zero)
        XCTAssertEqual(result.origin.y, 290)
    }

    func testPlacesAboveWhenBelowIsTooSmall() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let anchor = CGRect(x: 600, y: 100, width: 120, height: 20)
        let result = positioner.placement(panelSize: size, selectionBounds: anchor, visibleScreenFrames: [screen], mouseLocation: .zero)
        XCTAssertEqual(result.origin.y, 130)
    }

    func testClampsHorizontalEdges() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let left = positioner.placement(panelSize: size, selectionBounds: CGRect(x: -20, y: 500, width: 10, height: 20), visibleScreenFrames: [screen], mouseLocation: .zero)
        let right = positioner.placement(panelSize: size, selectionBounds: CGRect(x: 990, y: 500, width: 20, height: 20), visibleScreenFrames: [screen], mouseLocation: .zero)
        XCTAssertEqual(left.origin.x, 12)
        XCTAssertEqual(right.origin.x, 588)
    }

    func testSelectsDisplayWithNonZeroOrigin() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let secondary = CGRect(x: -1200, y: 120, width: 1200, height: 800)
        let anchor = CGRect(x: -800, y: 500, width: 50, height: 20)
        let result = positioner.placement(panelSize: size, selectionBounds: anchor, visibleScreenFrames: [primary, secondary], mouseLocation: .zero)
        XCTAssertEqual(result.screenFrame, secondary)
        XCTAssertGreaterThanOrEqual(result.origin.x, secondary.minX + 12)
    }

    func testUsesMouseWhenSelectionBoundsAreUnavailable() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let result = positioner.placement(panelSize: size, selectionBounds: nil, visibleScreenFrames: [screen], mouseLocation: CGPoint(x: 700, y: 600))
        XCTAssertEqual(result.origin.x, 500)
        XCTAssertEqual(result.origin.y, 289)
    }
}
