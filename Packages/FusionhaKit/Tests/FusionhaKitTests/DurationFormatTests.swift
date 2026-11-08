import XCTest
@testable import FusionhaKit

/// How Settings says a duration (owner-approved number controls, 2026-11-08).
final class DurationFormatTests: XCTestCase {
    func testWholeUnits() {
        XCTAssertEqual(DurationFormat.short(43_200), "12 hours")
        XCTAssertEqual(DurationFormat.short(3600), "1 hour")
        XCTAssertEqual(DurationFormat.short(86_400), "1 day")
        XCTAssertEqual(DurationFormat.short(2_592_000), "30 days")
        XCTAssertEqual(DurationFormat.short(604_800), "1 week")
        XCTAssertEqual(DurationFormat.short(1_209_600), "2 weeks")
        XCTAssertEqual(DurationFormat.short(1800), "30 minutes")
        XCTAssertEqual(DurationFormat.short(5), "5 seconds")
        XCTAssertEqual(DurationFormat.short(0), "0 minutes")
    }

    func testMixedValuesUseTheTwoLargestParts() {
        XCTAssertEqual(DurationFormat.short(45_000), "12 h 30 min")
        XCTAssertEqual(DurationFormat.short(90_061), "1 d 1 h")
        XCTAssertEqual(DurationFormat.short(150), "2 min 30 s")
    }

    func testLongFormSpellsEveryPart() {
        XCTAssertEqual(DurationFormat.long(45_000), "12 hours 30 minutes")
        XCTAssertEqual(DurationFormat.long(90_061), "1 day 1 hour 1 minute 1 second")
        XCTAssertEqual(DurationFormat.long(604_800), "1 week")
    }

    func testWheelPartsRoundTrip() {
        let cols: [DurationUnit] = [.hours, .minutes]
        XCTAssertEqual(DurationFormat.parts(45_000, columns: cols), [12, 30])
        XCTAssertEqual(DurationFormat.seconds([12, 30], columns: cols), 45_000)
        // The first column takes everything above it.
        XCTAssertEqual(DurationFormat.parts(259_200, columns: cols), [72, 0])
        XCTAssertEqual(DurationFormat.parts(93_600, columns: [.days, .hours]), [1, 2])
    }

    func testDayOffsets() {
        XCTAssertEqual(DayOffsetFormat.text(-5), "5 days before")
        XCTAssertEqual(DayOffsetFormat.text(-1), "1 day before")
        XCTAssertEqual(DayOffsetFormat.text(0), "On the day")
        XCTAssertEqual(DayOffsetFormat.text(3), "3 days after")
    }
}
