import XCTest
@testable import FusionhaKit

/// The desktop Week timeline (web `WeekView`, `calendar-format.ts` bands).
final class CalendarWeekBandsTests: XCTestCase {
    private let utc = CalendarMath.gregorian(TimeZone(identifier: "UTC")!)

    private func entry(item: Int = 8, type: String = "episode", ep: Int = 1, air: String?) throws -> CalendarEntry {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let airJSON = air.map { "\"\($0)\"" } ?? "null"
        return try d.decode(CalendarEntry.self, from: Data("""
            {"type":"\(type)","date":"2026-10-04","item_id":\(item),"title":"Show",
             "media_kind":"\(type == "movie" ? "movie" : "series")","is_anime":false,
             "season_number":2,"episode_number":\(ep),"air_datetime":\(airJSON),
             "editions":[{"edition_id":1,"tier":"HD-1080p","monitored":true,"status":"wanted"}]}
            """.utf8))
    }

    private func at(_ s: String) -> Date { CalendarMath.parseUTC(s)! }

    func testLayoutResolvesToTimelineByDefault() {
        XCTAssertEqual(WeekLayout.resolve(nil), .timeline)
        XCTAssertEqual(WeekLayout.resolve("bogus"), .timeline)
        XCTAssertEqual(WeekLayout.resolve("timeline"), .timeline)
        XCTAssertEqual(WeekLayout.resolve("stacked"), .stacked)
    }

    func testBandsSplitTheDayAtTheWebsHours() {
        XCTAssertEqual(CalendarBand.allCases, [.early, .day, .prime, .late])
        XCTAssertEqual(CalendarBand.of(hour: 0), .early)
        XCTAssertEqual(CalendarBand.of(hour: 5.99), .early)
        XCTAssertEqual(CalendarBand.of(hour: 6), .day)
        XCTAssertEqual(CalendarBand.of(hour: 16.99), .day)
        XCTAssertEqual(CalendarBand.of(hour: 17), .prime)
        XCTAssertEqual(CalendarBand.of(hour: 21), .late)
        XCTAssertEqual(CalendarBand.allCases.map(\.timeLabel), ["12a", "6a", "5p", "9p"])
    }

    func testEntryBandUsesTheLocalAirHourAndDateOnlyIsDay() throws {
        XCTAssertEqual(CalendarBand.of(try entry(air: "2026-10-04T02:00:00Z"), utc), .early)
        XCTAssertEqual(CalendarBand.of(try entry(air: "2026-10-04T20:30:00Z"), utc), .prime)
        XCTAssertEqual(CalendarBand.of(try entry(air: "2026-10-04T22:00:00Z"), utc), .late)
        XCTAssertEqual(CalendarBand.of(try entry(type: "movie", air: nil), utc), .day)
    }

    func testNowBand() {
        XCTAssertEqual(CalendarBand.now(at("2026-10-04T16:59:00Z"), utc), .day)
        XCTAssertEqual(CalendarBand.now(at("2026-10-04T17:00:00Z"), utc), .prime)
    }

    func testCellKeepsOnlyItsBand() throws {
        let morning = try entry(item: 1, air: "2026-10-04T09:00:00Z")
        let evening = try entry(item: 2, air: "2026-10-04T19:00:00Z")
        let cell = WeekBandCell.make(seasons: [], singles: [morning, evening], band: .prime,
                                     isNowCell: false, now: at("2026-10-04T12:00:00Z"), utc)
        XCTAssertEqual(cell.cards, [.single(evening)])
        XCTAssertNil(cell.nowIndex)
    }

    func testNowCellPutsAiredFirstAndSplitsAtTheBoundary() throws {
        let late = try entry(item: 1, air: "2026-10-04T16:00:00Z")
        let early = try entry(item: 2, air: "2026-10-04T08:00:00Z")
        let upcoming = try entry(item: 3, air: "2026-10-04T13:00:00Z")
        let cell = WeekBandCell.make(seasons: [], singles: [upcoming, late, early], band: .day,
                                     isNowCell: true, now: at("2026-10-04T12:00:00Z"), utc)
        XCTAssertEqual(cell.cards, [.single(early), .single(upcoming), .single(late)])
        XCTAssertEqual(cell.nowIndex, 1)
    }

    func testSeasonDropSitsInItsFirstEpisodesBand() throws {
        let eps = try (1...3).map { try entry(item: 5, ep: $0, air: "2026-10-04T0\($0 + 6):00:00Z") }
        let grouped = CalendarMath.groupWeekDay(eps)
        XCTAssertEqual(grouped.seasons.count, 1)
        let day = WeekBandCell.make(seasons: grouped.seasons, singles: grouped.singles, band: .day,
                                    isNowCell: false, now: at("2026-10-04T12:00:00Z"), utc)
        XCTAssertEqual(day.cards.count, 1)
        let early = WeekBandCell.make(seasons: grouped.seasons, singles: grouped.singles, band: .early,
                                      isNowCell: false, now: at("2026-10-04T12:00:00Z"), utc)
        XCTAssertTrue(early.cards.isEmpty)
    }
}
