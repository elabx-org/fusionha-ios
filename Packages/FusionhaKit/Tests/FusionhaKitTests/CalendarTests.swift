import XCTest
@testable import FusionhaKit

final class CalendarTests: XCTestCase {
    private let utc = CalendarMath.gregorian(TimeZone(identifier: "UTC")!)
    private let newYork = CalendarMath.gregorian(TimeZone(identifier: "America/New_York")!)

    private func entry(_ json: String) throws -> CalendarEntry {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(CalendarEntry.self, from: Data(json.utf8))
    }

    private func episode(date: String = "2026-10-04", air: String? = nil, runtime: Int? = nil,
                         anime: Bool = false, abs: Int? = nil, status: String = "wanted") throws -> CalendarEntry {
        let airJSON = air.map { "\"\($0)\"" } ?? "null"
        let absJSON = abs.map(String.init) ?? "null"
        let runtimeJSON = runtime.map(String.init) ?? "null"
        return try entry("""
            {"type":"episode","date":"\(date)","item_id":8,"title":"Show","media_kind":"series",
             "is_anime":\(anime),"season_number":1,"episode_number":5,"absolute_number":\(absJSON),
             "air_datetime":\(airJSON),"runtime":\(runtimeJSON),
             "editions":[{"edition_id":1,"tier":"HD-1080p","monitored":true,"status":"\(status)"}]}
            """)
    }

    func testDecodesNewFieldsAndLabels() throws {
        let movie = try entry("""
            {"type":"movie","date":"2026-10-04","release_type":"digital","item_id":2,"title":"Dune",
             "media_kind":"movie","is_anime":false,"backdrop_url":"b.jpg","editions":[]}
            """)
        XCTAssertEqual(movie.movieReleaseType, .digital)
        XCTAssertEqual(movie.label, "Digital")
        XCTAssertEqual(movie.backdropUrl, "b.jpg")
        XCTAssertEqual(try episode().label, "S1·E5")
        XCTAssertEqual(try episode(anime: true, abs: 28).label, "#28")
        XCTAssertEqual(try episode(anime: true, abs: 28).code, "S1·E5")
    }

    func testLocalDayFollowsAirInstant() throws {
        // 02:00 UTC on the 5th is still the 4th in New York.
        let e = try episode(date: "2026-10-05", air: "2026-10-05T02:00:00Z")
        XCTAssertEqual(e.localDay(newYork), "2026-10-04")
        XCTAssertEqual(e.localDay(utc), "2026-10-05")
        XCTAssertEqual(try episode(date: "2026-10-05").localDay(newYork), "2026-10-05")
    }

    func testAirWindowAndNaiveTimestamps() throws {
        let e = try episode(air: "2026-10-04T21:00:00", runtime: 50)
        XCTAssertEqual(e.airTime(TimeZone(identifier: "UTC")!), "9:00 PM – 9:50 PM")
        XCTAssertEqual(e.airStart(TimeZone(identifier: "UTC")!), "9:00 PM")
        XCTAssertNil(try episode().airTime())
    }

    func testUnairedAwareStatus() throws {
        let now = CalendarMath.parseUTC("2026-10-04T12:00:00Z")!
        let future = try episode(air: "2026-10-04T21:00:00Z")
        let past = try episode(air: "2026-10-04T08:00:00Z")
        XCTAssertEqual(future.statusKey(for: future.editions[0], now: now), .unaired)
        XCTAssertEqual(past.statusKey(for: past.editions[0], now: now), .missing)
        let done = try episode(air: "2026-10-04T21:00:00Z", status: "done")
        XCTAssertEqual(done.statusKey(for: done.editions[0], now: now), .downloaded)
    }

    func testMonthGridAndTitles() {
        let oct = CalendarMath.date("2026-10-15", utc)!
        let grid = CalendarMath.monthGrid(oct, firstDay: 0, utc)
        // October 1st 2026 is a Thursday: four leading blanks on a Sunday-first grid.
        XCTAssertEqual(grid.prefix(5).map { $0 ?? "-" }, ["-", "-", "-", "-", "2026-10-01"])
        XCTAssertEqual(grid.count % 7, 0)
        XCTAssertEqual(CalendarMath.weekdayHeaders(firstDay: 1).first, "Mon")
        XCTAssertEqual(CalendarMath.monthTitle(oct, utc), "October 2026")
        let sunday = CalendarMath.date("2026-10-04", utc)!
        XCTAssertEqual(CalendarMath.weekTitle(sunday, firstDay: 0, utc), "Oct 4 – 10, 2026")
        XCTAssertEqual(CalendarMath.weekTitle(CalendarMath.date("2026-09-30", utc)!, firstDay: 0, utc), "Sep 27 – Oct 3, 2026")
        XCTAssertEqual(CalendarMath.dayTitle(sunday, utc), "Sunday, October 4, 2026")
        XCTAssertEqual(CalendarMath.agendaDayLabel("2026-10-04", utc), "Sun, Oct 4")
    }

    func testSortAndSeasonDrops() throws {
        let dateOnly = try episode()
        let late = try episode(air: "2026-10-04T21:00:00Z")
        let early = try episode(air: "2026-10-04T08:00:00Z")
        let sorted = CalendarMath.sortDay([dateOnly, late, early])
        XCTAssertEqual(sorted.map(\.airDatetime), ["2026-10-04T08:00:00Z", "2026-10-04T21:00:00Z", nil])
        let grouped = CalendarMath.groupWeekDay([dateOnly, late, early])
        XCTAssertEqual(grouped.seasons.count, 1)
        XCTAssertEqual(grouped.seasons[0].tiers.first?.total, 3)
        XCTAssertTrue(grouped.singles.isEmpty)
    }

    func testViewResolution() {
        XCTAssertEqual(CalendarViewMode.resolve(stored: "week", settingDefault: "month"), .week)
        XCTAssertEqual(CalendarViewMode.resolve(stored: nil, settingDefault: "month"), .month)
        XCTAssertEqual(CalendarViewMode.resolve(stored: "bogus", settingDefault: nil), .agenda)
    }

    func testFeedURLEncodesTheKey() throws {
        let client = APIClient(baseURL: URL(string: "http://nas:8787")!, token: nil)
        let url = try XCTUnwrap(client.calendarFeedURL(apiKey: "a+b/c"))
        XCTAssertEqual(url.absoluteString, "http://nas:8787/api/v1/calendar/feed.ics?apikey=a%2Bb%2Fc")
    }

    func testMeAccountFields() throws {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let me = try d.decode(Me.self, from: Data("""
            {"id":3,"username":"elmer (plex:123)","is_admin":false,"role_name":"Requestor",
             "plex_username":"elmer","plex_linked":true,
             "credentials":[{"id":1,"provider":"plex","external_id":"123","display_handle":"elmer",
                             "is_primary":true,"is_active":true}]}
            """.utf8))
        XCTAssertEqual(me.displayName, "elmer")
        XCTAssertEqual(me.roleTone, .requestor)
        XCTAssertEqual(me.credentials?.first?.providerLabel, "Plex")
    }
}
