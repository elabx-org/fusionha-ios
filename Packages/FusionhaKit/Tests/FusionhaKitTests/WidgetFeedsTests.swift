import XCTest
@testable import FusionhaKit

final class WidgetFeedsTests: XCTestCase {
    private let utc = CalendarMath.gregorian(TimeZone(identifier: "UTC")!)
    private let now = CalendarMath.parseUTC("2026-10-04T12:00:00Z")!

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    private func episode(item: Int = 8, date: String, air: String? = nil, episode: Int = 5,
                         monitored: Bool = true) throws -> CalendarEntry {
        let airJSON = air.map { "\"\($0)\"" } ?? "null"
        return try decode(CalendarEntry.self, """
            {"type":"episode","date":"\(date)","item_id":\(item),"title":"Show \(item)","media_kind":"series",
             "is_anime":false,"season_number":1,"episode_number":\(episode),"episode_title":"Ep \(episode)",
             "air_datetime":\(airJSON),
             "editions":[{"edition_id":2,"tier":"UHD-2160p","monitored":\(monitored),"status":"wanted"},
                         {"edition_id":1,"tier":"HD-1080p","monitored":\(monitored),"status":"grabbing"}]}
            """)
    }

    private func movie(item: Int, date: String) throws -> CalendarEntry {
        try decode(CalendarEntry.self, """
            {"type":"movie","date":"\(date)","release_type":"digital","item_id":\(item),"title":"Movie \(item)",
             "media_kind":"movie","is_anime":false,
             "editions":[{"edition_id":9,"tier":"HD-1080p","monitored":true,"status":"wanted"}]}
            """)
    }

    func testUpNextSkipsAiredAndUnmonitoredAndSortsSoonestFirst() throws {
        let entries = [
            try episode(item: 1, date: "2026-10-04", air: "2026-10-04T08:00:00Z"),        // aired
            try episode(item: 2, date: "2026-10-05", air: "2026-10-05T01:00:00Z"),
            try movie(item: 3, date: "2026-10-04"),                                     // today, date only
            try episode(item: 4, date: "2026-10-04", air: "2026-10-04T21:00:00Z", monitored: false),
            try movie(item: 5, date: "2026-10-03"),                                     // yesterday
        ]
        let rows = WidgetFeeds.upNext(entries, now: now, calendar: utc, limit: 5)
        XCTAssertEqual(rows.map(\.itemId), [3, 2])
        XCTAssertFalse(rows[0].hasTime)
        XCTAssertEqual(rows[0].code, "Digital")
        XCTAssertTrue(rows[1].hasTime)
        // HD first, statuses unaired-aware.
        XCTAssertEqual(rows[1].editions.map(\.tier), [.hd, .uhd])
        XCTAssertEqual(rows[1].editions.map(\.status), [.downloading, .unaired])
        XCTAssertEqual(rows[1].editions[1].status.editionStatus, .unaired)
    }

    func testUpNextCollapsesSameDayDropAndHonoursLimit() throws {
        let entries = [
            try episode(item: 8, date: "2026-10-05", air: "2026-10-05T07:00:00Z", episode: 1),
            try episode(item: 8, date: "2026-10-05", air: "2026-10-05T07:00:00Z", episode: 2),
            try episode(item: 8, date: "2026-10-05", air: "2026-10-05T07:00:00Z", episode: 3),
            try episode(item: 9, date: "2026-10-06", air: "2026-10-06T07:00:00Z"),
            try episode(item: 10, date: "2026-10-07", air: "2026-10-07T07:00:00Z"),
        ]
        let rows = WidgetFeeds.upNext(entries, now: now, calendar: utc, limit: 2)
        XCTAssertEqual(rows.map(\.itemId), [8, 9])
        XCTAssertEqual(rows[0].code, "S1·E1 +2")
        XCTAssertNil(rows[0].episodeTitle)
        XCTAssertEqual(rows[1].episodeTitle, "Ep 5")
    }

    func testRecentImportsGroupsByTitleNewestFirst() throws {
        let page = try decode(HistoryPage.self, """
            {"total":5,"items":[
              {"id":1,"event_type":"IMPORTED","created_at":"2026-10-02T10:00:00","media_item_id":1,
               "item_title":"The Matrix","tier":"UHD-2160p","poster_url":"m.jpg"},
              {"id":2,"event_type":"GRABBED","created_at":"2026-10-04T10:00:00","media_item_id":4,"item_title":"Dune"},
              {"id":3,"event_type":"IMPORTED","created_at":"2026-10-03T21:00:00","media_item_id":1,
               "item_title":"The Matrix","tier":"HD-1080p","poster_url":"m.jpg"},
              {"id":4,"event_type":"IMPORTED","created_at":"2026-10-03T15:00:00","media_item_id":2,
               "item_title":"Inception","tier":"HD-1080p"},
              {"id":5,"event_type":"IMPORTED","created_at":"2026-10-01T15:00:00","media_item_id":3,
               "item_title":"Old","tier":"HD-1080p"}
            ]}
            """)
        let rows = WidgetFeeds.recentImports(page.items, limit: 2)
        XCTAssertEqual(rows.map(\.title), ["The Matrix", "Inception"])
        XCTAssertEqual(rows[0].tiers, [.hd, .uhd])
        XCTAssertEqual(rows[0].count, 2)
        XCTAssertEqual(rows[0].posterUrl, "m.jpg")
        XCTAssertEqual(rows[0].importedAt, CalendarMath.parseUTC("2026-10-03T21:00:00"))
    }

    func testRecentImportsKeepsAnyGroupedItemId() throws {
        // A title-grouped row whose newest event lost its item id still links.
        let page = try decode(HistoryPage.self, """
            {"total":2,"items":[
              {"id":1,"event_type":"IMPORTED","created_at":"2026-10-03T10:00:00","source_title":"Arrival",
               "tier":"HD-1080p"},
              {"id":2,"event_type":"IMPORTED","created_at":"2026-10-02T10:00:00","source_title":"Arrival",
               "tier":"UHD-2160p"}
            ]}
            """)
        let rows = WidgetFeeds.recentImports(page.items, limit: 5)
        XCTAssertEqual(rows.count, 1)
        XCTAssertNil(rows[0].itemId)
        XCTAssertEqual(WidgetRoute.item(rows[0].itemId, fallback: .library).url.absoluteString, "fusionha://library")

        let linked = try decode(HistoryPage.self, """
            {"total":1,"items":[
              {"id":3,"event_type":"IMPORTED","created_at":"2026-10-03T10:00:00","media_item_id":42,
               "item_title":"Arrival","tier":"HD-1080p"}
            ]}
            """)
        let row = WidgetFeeds.recentImports(linked.items, limit: 5)[0]
        XCTAssertEqual(row.itemId, 42)
        XCTAssertEqual(WidgetRoute.item(row.itemId, fallback: .library).url.absoluteString, "fusionha://item/42")
    }

    func testWidgetRoutes() {
        XCTAssertEqual(WidgetRoute.item(0, fallback: .library), .library)
        XCTAssertEqual(WidgetRoute.item(nil, fallback: .calendar), .calendar)
        XCTAssertEqual(WidgetRoute.item(7, fallback: .library), .item(7))
        // Downloading: Activity, whatever the family.
        XCTAssertEqual(WidgetRoute.downloads(idle: false, small: false, upNextIds: [1], recentIds: [2]), .activity)
        XCTAssertEqual(WidgetRoute.downloads(idle: false, small: true, upNextIds: [], recentIds: []), .activity)
        // Idle small: the title it shows.
        XCTAssertEqual(WidgetRoute.downloads(idle: true, small: true, upNextIds: [5], recentIds: [6]), .item(5))
        XCTAssertEqual(WidgetRoute.downloads(idle: true, small: true, upNextIds: [], recentIds: [6]), .item(6))
        XCTAssertEqual(WidgetRoute.downloads(idle: true, small: true, upNextIds: [], recentIds: [nil]), .library)
        // Idle medium/large never fall back to Activity.
        XCTAssertEqual(WidgetRoute.downloads(idle: true, small: false, upNextIds: [5], recentIds: [6]), .library)
        XCTAssertEqual(WidgetRoute.downloads(idle: true, small: false, upNextIds: [5], recentIds: []), .calendar)
        XCTAssertEqual(WidgetRoute.downloads(idle: true, small: false, upNextIds: [], recentIds: []), .library)
    }

    func testLabels() {
        let at = CalendarMath.parseUTC("2026-10-04T21:00:00Z")!
        XCTAssertEqual(WidgetFeeds.whenLabel(at, hasTime: true, now: now, calendar: utc), "Today · 9:00 PM")
        XCTAssertEqual(WidgetFeeds.whenLabel(at.addingTimeInterval(86_400), hasTime: false, now: now, calendar: utc), "Tomorrow")
        // 2026-10-08 is a Thursday.
        XCTAssertEqual(WidgetFeeds.whenLabel(at.addingTimeInterval(4 * 86_400), hasTime: true, now: now, calendar: utc),
                       "Thu · 9:00 PM")
        XCTAssertEqual(WidgetFeeds.whenLabel(at.addingTimeInterval(8 * 86_400), hasTime: false, now: now, calendar: utc), "Oct 12")
        XCTAssertEqual(WidgetFeeds.agoLabel(now.addingTimeInterval(-30), now: now), "just now")
        XCTAssertEqual(WidgetFeeds.agoLabel(now.addingTimeInterval(-720), now: now), "12m ago")
        XCTAssertEqual(WidgetFeeds.agoLabel(now.addingTimeInterval(-3 * 3600), now: now), "3h ago")
        XCTAssertEqual(WidgetFeeds.agoLabel(now.addingTimeInterval(-2 * 86_400), now: now), "2d ago")
    }
}
