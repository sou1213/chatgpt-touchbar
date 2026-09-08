import XCTest
@testable import ChatGPTTouchBarCore

final class SurvivalMeterTests: XCTestCase {
    func testHalfSlotBoundaries() {
        for half in 0...20 {
            XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: Double(half * 5)), half)
        }
        XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: 84.9), 16)
        XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: 0.1), 0)
    }

    func testInvalidAndClampedValues() {
        XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: -1), 0)
        XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: 101), 20)
        XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: .nan), 0)
        XCTAssertEqual(SurvivalMeter.halfSlots(remainingPercent: .infinity), 0)
    }
}
