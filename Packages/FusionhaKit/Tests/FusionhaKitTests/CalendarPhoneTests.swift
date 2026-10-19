import XCTest
@testable import FusionhaKit

final class CalendarPhoneTests: XCTestCase {
    private let utc = CalendarMath.gregorian(TimeZone(identifier: "UTC")!)

    private func entry(item: Int = 8, title: String = "Show", type: String = "episode", ep: Int = 1,
                       air: String? = nil, runtime: Int? = nil, status: String = "wanted") throws -> CalendarEntry {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let airJSON = air.map { "\"\($0)\"" } ?? "null"
        let runtimeJSON = runtime.map(String.init) ?? "null"
        return try d.decode(CalendarEntry.self, from: Data("""
            {"type":"\(type)","date":"2026-10-04","item_id":\(item),"title":"\(title)",
             "media_kind":"\(type == "movie" ? "movie" : "series")","is_anime":false,
             "season_number":2,"episode_number":\(ep),"air_datetime":\(airJSON),"runtime":\(runtimeJSON),
             "editions":[{"edition_id":1,"tier":"HD-1080p","monitored":true,"status":"\(status)"}]}
            """.utf8))
    }

    func testShortLabelsAndPhoneSteps() {
        XCTAssertEqual(CalendarViewMode.allCases.map(\.shortLabel), ["Mo", "Wk", "Fc", "Day", "Ag"])
        XCTAssertEqual(CalendarViewMode.allCases.filter(\.phoneSteps), [.month, .week, .day])
        XCTAssertEqual(CalendarViewMode.day.stepNoun, "day")
        XCTAssertEqual(CalendarViewMode.agenda.stepNoun, "month")
    }

    func testMobileDayLabel() {
        // 2026-10-07 is a Wednesday.
        XCTAssertEqual(CalendarMath.mobileDayLabel("2026-10-07", todayIso: "2026-10-07", utc), "Today · Wed 7")
        XCTAssertEqual(CalendarMath.mobileDayLabel("2026-10-08", todayIso: "2026-10-07", utc), "Tomorrow · Thu 8")
        XCTAssertEqual(CalendarMath.mobileDayLabel("2026-10-09", todayIso: "2026-10-07", utc), "Friday 9")
    }

    func testIsoDaysSpansMonthAndCaps() {
        XCTAssertEqual(CalendarMath.isoDays(from: "2026-10-30", to: "2026-11-02", utc),
                       ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"])
        XCTAssertEqual(CalendarMath.isoDays(from: "2026-01-01", to: "2026-12-31", utc).count, 62)
    }

    func testRunsFoldAtTwoAndKeepClockOrder() throws {
        let a1 = try entry(item: 1, ep: 1, air: "2026-10-04T21:00:00Z", runtime: 50)
        let b = try entry(item: 2, title: "Other", ep: 4, air: "2026-10-04T20:00:00Z")
        let a2 = try entry(item: 1, ep: 2, air: "2026-10-04T22:00:00Z", runtime: 40)
        let items = CalendarMath.dayItems([a1, b, a2])
        XCTAssertEqual(items.count, 2)
        guard case .entry(let first) = items[0], case .run(let run) = items[1] else {
            return XCTFail("expected the single first, then the run")
        }
        XCTAssertEqual(first.itemId, 2)
        XCTAssertEqual(run.entries.count, 2)
        XCTAssertEqual(run.codes, "S02·E01–E02")
        XCTAssertEqual(run.span(TimeZone(identifier: "UTC")!), "9:00 PM – 10:40 PM")
        // Week cards still fold at three.
        XCTAssertTrue(CalendarMath.groupWeekDay([a1, b, a2]).seasons.isEmpty)
    }

    func testTodaySplitsAiredFromUpcoming() throws {
        let now = CalendarMath.parseUTC("2026-10-04T21:30:00Z")!
        let early = try entry(item: 1, air: "2026-10-04T20:00:00Z")
        let late = try entry(item: 2, air: "2026-10-04T23:00:00Z")
        let items = CalendarMath.dayItems([late, early])
        let today = CalendarMath.phoneDay(items, isToday: true, now: now)
        XCTAssertEqual(today.before.map(\.id), [items[0].id])
        XCTAssertEqual(today.after.count, 1)
        XCTAssertTrue(today.showsNow)
        let other = CalendarMath.phoneDay(items, isToday: false, now: now)
        XCTAssertEqual(other.before.count, 2)
        XCTAssertFalse(other.showsNow)
    }

    func testWash() throws {
        let now = CalendarMath.parseUTC("2026-10-05T00:00:00Z")!
        XCTAssertEqual(try entry(air: "2026-10-04T20:00:00Z", status: "grabbing").wash(now: now), .grab)
        XCTAssertEqual(try entry(air: "2026-10-04T20:00:00Z", status: "wanted").wash(now: now), .miss)
        XCTAssertNil(try entry(air: "2026-10-06T20:00:00Z", status: "wanted").wash(now: now))
        XCTAssertNil(try entry(air: "2026-10-04T20:00:00Z", status: "done").wash(now: now))
    }

    func testUpNextTitlesAndSwipe() throws {
        let list = try [entry(title: "A"), entry(title: "A"), entry(title: "B"), entry(title: "C"), entry(title: "D")]
        XCTAssertEqual(CalendarMath.upNextTitles(list), ["A", "B", "C"])
        XCTAssertEqual(CalendarSwipe.step(dx: -80, dy: 10), 1)
        XCTAssertEqual(CalendarSwipe.step(dx: 80, dy: 10), -1)
        XCTAssertNil(CalendarSwipe.step(dx: 50, dy: 0))
        XCTAssertNil(CalendarSwipe.step(dx: 80, dy: 70))
    }
}
