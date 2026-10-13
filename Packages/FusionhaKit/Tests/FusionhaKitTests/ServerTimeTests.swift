import XCTest
@testable import FusionhaKit

final class ServerTimeTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func components(_ date: Date?) -> DateComponents? {
        guard let date else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    func testNaiveTimestampIsUTC() {
        let c = components(ServerTime.parse("2026-10-02T02:52:39"))
        XCTAssertEqual(c?.hour, 2)
        XCTAssertEqual(c?.minute, 52)
    }

    func testMicrosecondsAndZoneForms() {
        let naive = ServerTime.parse("2026-10-02T02:52:39.007478")
        let zulu = ServerTime.parse("2026-10-02T02:52:39.007Z")
        let offset = ServerTime.parse("2026-10-02T04:52:39.007+02:00")
        XCTAssertNotNil(naive)
        XCTAssertEqual(naive!.timeIntervalSince1970, zulu!.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(zulu!.timeIntervalSince1970, offset!.timeIntervalSince1970, accuracy: 0.001)
    }

    func testSpaceSeparatorAndBareDay() {
        XCTAssertEqual(components(ServerTime.parse("2026-10-02 02:52:39"))?.minute, 52)
        let day = components(ServerTime.parse("2026-10-02"))
        XCTAssertEqual(day?.day, 2)
        XCTAssertEqual(day?.hour, 0)
    }

    func testRejectsJunk() {
        XCTAssertNil(ServerTime.parse(nil))
        XCTAssertNil(ServerTime.parse(""))
        XCTAssertNil(ServerTime.parse("soon"))
    }

    /// The same instant whatever the device's time zone: the old trap read
    /// naive UTC as local time.
    func testIndependentOfDeviceZone() {
        let a = ServerTime.parse("2026-10-02T23:30:00")
        XCTAssertEqual(components(a)?.day, 2)
        XCTAssertEqual(components(a)?.hour, 23)
    }

    func testOldEntryPointsAgree() {
        let raw = "2026-10-02T02:52:39.007478"
        XCTAssertEqual(DetailText.instant(raw), ServerTime.parse(raw))
        XCTAssertEqual(CalendarMath.parseUTC(raw), ServerTime.parse(raw))
    }

    func testLocalMidnightCarriesTheViewersOffset() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London")!
        let now = ServerTime.parse("2026-10-13T22:30:00Z")!   // 23:30 BST
        XCTAssertEqual(ServerTime.localMidnightISO(now: now, calendar: cal), "2026-10-13T00:00:00+01:00")
    }
}
