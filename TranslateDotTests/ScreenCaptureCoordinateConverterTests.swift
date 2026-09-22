import CoreGraphics
import XCTest
@testable import TranslateDot

final class ScreenCaptureCoordinateConverterTests: XCTestCase {
    func testConvertsAppKitBottomLeftCoordinatesToDisplayTopLeftCoordinates() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let selection = CGRect(x: 100, y: 650, width: 300, height: 120)

        XCTAssertEqual(
            ScreenCaptureCoordinateConverter.sourceRect(
                selectionBounds: selection,
                screenFrame: screen
            ),
            CGRect(x: 100, y: 130, width: 300, height: 120)
        )
    }

    func testConvertsCoordinatesForOffsetSecondaryDisplay() {
        let screen = CGRect(x: 1_440, y: -200, width: 1_920, height: 1_080)
        let selection = CGRect(x: 1_540, y: 500, width: 400, height: 200)

        XCTAssertEqual(
            ScreenCaptureCoordinateConverter.sourceRect(
                selectionBounds: selection,
                screenFrame: screen
            ),
            CGRect(x: 100, y: 180, width: 400, height: 200)
        )
    }
}
