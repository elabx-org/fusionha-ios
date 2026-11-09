import XCTest
@testable import FusionhaKit

final class RecentArrivalsTests: XCTestCase {
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    static let now = ISO8601DateFormatter().date(from: "2026-11-09T12:00:00Z")!

    static func imp(_ item: Int, _ at: String, tier: QualityTier = .hd, path: String? = nil,
                    source: String? = nil, type: String = "IMPORTED") -> [String: Any] {
        let id = abs("\(item)\(at)\(source ?? "")\(path ?? "")\(type)".hashValue % 1_000_000)
        var json: [String: Any] = ["id": id, "event_type": type, "created_at": at, "media_item_id": item,
                                   "item_title": "T\(item)", "tier": tier.rawValue]
        if let path { json["data"] = ["relative_path": path] }
        if let source { json["source_title"] = source }
        return json
    }

    static func entries(_ list: [[String: Any]]) throws -> [HistoryEntry] {
        try APIClient.decoder.decode([HistoryEntry].self, from: JSONSerialization.data(withJSONObject: list))
    }

    func testGroupsPerTitlePerDayNewestFirst() throws {
        let rows = RecentArrivals.rows(try Self.entries([
            Self.imp(1, "2026-11-08T08:03:00", path: "Show/Season 02/Show - S02E02 - A.mkv"),
            Self.imp(2, "2026-11-09T11:31:00", tier: .uhd),
            Self.imp(1, "2026-11-09T09:00:00", path: "Show/Season 02/Show - S02E01 - A.mkv"),
            Self.imp(2, "2026-11-09T11:30:00"),
            Self.imp(3, "2026-11-09T10:00:00", type: "GRABBED"),
        ]), calendar: Self.utc)
        XCTAssertEqual(rows.map(\.itemId), [2, 1, 1])
        XCTAssertEqual(rows[0].tiers, [.hd, .uhd])
        XCTAssertEqual(rows[0].imports, 2)
        XCTAssertEqual(RecentArrivals.what(rows[0]), "HD and 4K copies")
        XCTAssertEqual(RecentArrivals.note(rows[1], now: Self.now, calendar: Self.utc), "S02E01 · 3 h ago")
        XCTAssertNotEqual(rows[1].day, rows[2].day)
    }

    func testEpisodeWordsPreferThePathOverAPackName() throws {
        let pack = (1...6).map { Self.imp(1, "2026-11-09T09:0\($0):00", path: "S/Season 01/S - S01E0\($0) - x.mkv",
                                          source: "Show.S01.1080p.WEB-DL") }
        XCTAssertEqual(RecentArrivals.what(RecentArrivals.rows(try Self.entries(pack), calendar: Self.utc)[0]), "S01E01–E06")

        let gaps = [Self.imp(1, "2026-11-09T09:00:00", source: "Show.S01E13.1080p"),
                    Self.imp(1, "2026-11-09T09:01:00", source: "Show.S01E01.1080p")]
        XCTAssertEqual(RecentArrivals.what(RecentArrivals.rows(try Self.entries(gaps), calendar: Self.utc)[0]), "S01E01, E13")

        let many = [2, 5, 9, 12].map { Self.imp(1, "2026-11-09T09:00:00", source: "Show.S03E\($0)") }
        XCTAssertEqual(RecentArrivals.what(RecentArrivals.rows(try Self.entries(many), calendar: Self.utc)[0]), "4 episodes · S03")

        let seasons = [Self.imp(1, "2026-11-09T09:00:00", source: "Show.S01E01"),
                       Self.imp(1, "2026-11-09T09:00:00", source: "Show.S02E01")]
        XCTAssertEqual(RecentArrivals.what(RecentArrivals.rows(try Self.entries(seasons), calendar: Self.utc)[0]), "2 episodes")
    }

    func testWhenReadsAgoTodayAndTheTimeBefore() throws {
        let rows = RecentArrivals.rows(try Self.entries([
            Self.imp(1, "2026-11-09T11:31:00", tier: .uhd),
            Self.imp(2, "2026-11-09T11:59:50"),
            Self.imp(3, "2026-11-08T08:03:00"),
        ]), calendar: Self.utc)
        XCTAssertEqual(rows.map { RecentArrivals.when($0, now: Self.now, calendar: Self.utc) }.prefix(2), ["Just now", "29 min ago"])
        XCTAssertEqual(RecentArrivals.what(rows[1]), "4K copy")
        XCTAssertTrue(RecentArrivals.when(rows[2], now: Self.now, calendar: Self.utc).contains(":03"))
    }
}
