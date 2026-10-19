import XCTest
@testable import FusionhaKit

/// Mirrors the web's `idle-derive.test.ts` (Coming up next, Recently finished, balance).
final class IdleDeriveTests: XCTestCase {
    static let now = ISO8601DateFormatter().date(from: "2026-10-07T19:50:00Z")!
    static var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    static func ep(_ title: String, item: Int? = nil, air: String?, s: Int, e: Int,
                   versions: [(QualityTier, Bool, String)] = [(.hd, true, "wanted")],
                   type: String = "episode", date: String? = nil, releaseType: String? = nil) -> [String: Any] {
        var json: [String: Any] = [
            "type": type, "date": date ?? String((air ?? "").prefix(10)), "item_id": item ?? title.count,
            "title": title, "media_kind": type == "movie" ? "movie" : "series", "is_anime": false,
            "poster_url": "https://img/\(title).jpg", "episode_title": "Ep \(e)",
            "editions": versions.enumerated().map { i, v in
                ["edition_id": i + 1, "tier": v.0.rawValue, "monitored": v.1, "status": v.2] as [String: Any]
            },
        ]
        if type == "episode" { json["season_number"] = s; json["episode_number"] = e }
        if let air { json["air_datetime"] = air }
        if let releaseType { json["release_type"] = releaseType }
        return json
    }

    static func entries(_ list: [[String: Any]]) throws -> [CalendarEntry] {
        try APIClient.decoder.decode([CalendarEntry].self, from: JSONSerialization.data(withJSONObject: list))
    }

    static func hours(_ h: Int) -> String {
        ISO8601DateFormatter().string(from: now.addingTimeInterval(Double(h) * 3600))
    }

    private func sample() throws -> ComingUp {
        let list = try Self.entries([
            Self.ep("Aired", air: "2026-10-07T04:00:00Z", s: 1, e: 1),
            Self.ep("Scrubs", item: 1, air: "2026-10-08T00:00:00Z", s: 2, e: 3),
            Self.ep("Abbott", item: 2, air: "2026-10-08T00:30:00Z", s: 6, e: 1),
            Self.ep("AHS", item: 3, air: "2026-10-09T01:00:00Z", s: 13, e: 7),
            Self.ep("Elsbeth", item: 4, air: "2026-10-09T01:02:00Z", s: 4, e: 1),
            Self.ep("AHS", item: 3, air: "2026-10-09T01:33:00Z", s: 13, e: 8),
            Self.ep("Dark Matter", item: 5, air: "2026-10-09T04:00:00Z", s: 2, e: 7,
                    versions: [(.uhd, true, "wanted"), (.hd, true, "wanted")]),
            Self.ep("Below", item: 6, air: "2026-10-08T07:00:00Z", s: 1, e: 1, versions: [(.hd, true, "done")]),
            Self.ep("Below", item: 6, air: "2026-10-08T07:00:00Z", s: 1, e: 2, versions: [(.hd, true, "done")]),
            Self.ep("Unmonitored", item: 7, air: "2026-10-08T07:00:00Z", s: 1, e: 5, versions: [(.hd, false, "wanted")]),
            Self.ep("Outlander", item: 8, air: "2026-10-10T00:00:00Z", s: 2, e: 4),
            Self.ep("Other Mommy", item: 9, air: nil, s: 0, e: 0, type: "movie", date: "2026-10-09", releaseType: "theatrical"),
        ])
        return IdleComingUp.derive(list, now: Self.now, calendar: Self.utc)
    }

    func testKeepsWantedAiringsInTheWindowSoonestFirst() throws {
        let rows = try sample().rows
        XCTAssertEqual(rows.map(\.title), ["Scrubs", "Abbott", "AHS", "Elsbeth", "Dark Matter"])
        XCTAssertTrue(rows[0].next)
        XCTAssertFalse(rows[1].next)
    }

    func testFoldsOneTitleTwiceADayIntoARange() throws {
        let ahs = try XCTUnwrap(try sample().rows.first { $0.title == "AHS" })
        XCTAssertEqual(ahs.se, "S13E07–E08")
        XCTAssertEqual(ahs.count, 2)
        XCTAssertEqual(ahs.episodeTitle, "Ep 7 · Ep 8")
    }

    func testPremieresAndTiersHDFirst() throws {
        let rows = try sample().rows
        XCTAssertEqual(rows.first { $0.title == "Abbott" }?.premiere, true)
        XCTAssertEqual(rows.first { $0.title == "Scrubs" }?.premiere, false)
        XCTAssertEqual(rows.first { $0.title == "Dark Matter" }?.tiers, [.hd, .uhd])
    }

    func testCountsAndAsides() throws {
        let out = try sample()
        XCTAssertEqual(out.episodes, 6)
        XCTAssertEqual(out.titles, 5)
        XCTAssertEqual(out.already, [ComingAside(key: "6", title: "Below", se: "S01E01–E02", tiers: [.hd], note: nil)])
        XCTAssertEqual(out.later.map(\.title), ["Other Mommy", "Outlander"])
        XCTAssertEqual(out.later.first?.note, "theatrical")
        XCTAssertEqual(out.days.map(\.count), [2, 4])
    }

    func testEmptyFeed() {
        let none = IdleComingUp.derive([], now: Self.now, calendar: Self.utc)
        XCTAssertTrue(none.days.isEmpty)
        XCTAssertEqual(none.episodes, 0)
    }

    func testWindowFilter() {
        XCTAssertFalse(IdleComingUp.inWindow(Self.now, now: Self.now))
        XCTAssertTrue(IdleComingUp.inWindow(Self.now.addingTimeInterval(48 * 3600), now: Self.now))
        XCTAssertFalse(IdleComingUp.inWindow(Self.now.addingTimeInterval(48 * 3600 + 1), now: Self.now))
    }

    func testEpisodeRange() {
        XCTAssertEqual(IdleComingUp.episodeRange(season: 2, episodes: [5, 2]), "S02E02 · E05")
        XCTAssertEqual(IdleComingUp.episodeRange(season: 2, episodes: [3, 1, 2, 2]), "S02E01–E03")
        XCTAssertEqual(IdleComingUp.episodeRange(season: 1, episodes: [4]), "S01E04")
    }
}
