import XCTest
@testable import FusionhaKit

/// Recently finished, `balanceLayout`, the idle time helpers, readiness copy and the quip.
final class IdleRecentLayoutTests: XCTestCase {
    private let now = IdleDeriveTests.now

    private func hist(_ id: Int, item: Int = 1, edition: Int = 1, title: String = "Loki", source: String = "Some.Release",
                      tier: String = "HD-1080p", quality: String = "WEBDL_1080P",
                      chips: [(String, String)] = [], data: [String: Any] = [:],
                      at: String = "2026-10-07T19:28:44") -> [String: Any] {
        ["id": id, "event_type": "IMPORTED", "source_title": source, "quality": quality, "data": data,
         "created_at": at, "media_item_id": item, "edition_id": edition, "item_title": title, "tier": tier,
         "chips": chips.map { ["kind": $0.0, "label": $0.1] }]
    }

    private func history(_ list: [[String: Any]]) throws -> [HistoryEntry] {
        try APIClient.decoder.decode([HistoryEntry].self, from: JSONSerialization.data(withJSONObject: list))
    }

    func testFoldsConsecutiveImportsOfOneVersion() throws {
        let rows = IdleRecent.derive(try history([
            hist(5, source: "Loki.S02E05.2160p", tier: "UHD-2160p", quality: "REMUX_2160P",
                 chips: [("group", "FraMeSToR"), ("source", "Remux"), ("range", "DV"), ("protocol", "Usenet")]),
            hist(4, source: "Loki.S02E02.2160p", tier: "UHD-2160p", at: "2026-10-07T19:25:00"),
            hist(3, item: 2, edition: 2, title: "Batman & Robin", source: "Batman.and.Robin.1997.1080p",
                 data: ["relative_path": "Batman & Robin (1997)/x.mkv"]),
            hist(2, item: 3, edition: 3, title: "Ludwig", source: "Ludwig.S02E02.1080p"),
            hist(1, item: 3, edition: 3, title: "Ludwig", source: "Ludwig.S02E01.1080p"),
        ]))
        XCTAssertEqual(rows.map(\.title), ["Loki", "Batman & Robin", "Ludwig"])
        XCTAssertEqual(rows.map(\.label), ["S02E02 · E05", "1997", "S02E01–E02"])
        XCTAssertEqual(rows.map(\.count), [2, 1, 2])
        XCTAssertEqual(rows[0].quality, "Bluray-2160p Remux")
        XCTAssertEqual(rows[0].extra, "DV · FraMeSToR")
        XCTAssertEqual(rows[0].at, "2026-10-07T19:28:44")
        XCTAssertEqual(rows[0].tier, .uhd)
    }

    func testCapsAtSix() throws {
        let many = try history((0..<10).map { hist($0, item: $0, edition: $0, title: "T\($0)") })
        XCTAssertEqual(IdleRecent.derive(many).count, 6)
    }

    // MARK: balanceLayout

    private func recent(_ n: Int) throws -> [FinishedRow] {
        IdleRecent.derive(try history((0..<n).map { hist($0, item: $0, edition: $0) }), limit: 20)
    }

    private func coming(_ rows: Int, twoTiers: Bool = false) throws -> ComingUp {
        let versions: [(QualityTier, Bool, String)] = twoTiers ? [(.hd, true, "wanted"), (.uhd, true, "wanted")] : [(.hd, true, "wanted")]
        let list = try IdleDeriveTests.entries((0..<rows).map {
            IdleDeriveTests.ep("T\($0)", item: 100 + $0, air: IdleDeriveTests.hours($0 + 1), s: 1, e: 2, versions: versions)
        })
        return IdleComingUp.derive(list, now: now, calendar: IdleDeriveTests.utc)
    }

    func testBalanceGrowsRecentToMatchComing() throws {
        XCTAssertEqual(IdleLayout.balance(coming: try coming(10), recent: try recent(12)),
                       .init(arrangement: .columns, recentCount: 12))
        XCTAssertEqual(IdleLayout.balance(coming: try coming(3), recent: try recent(12)),
                       .init(arrangement: .columns, recentCount: 6))
        XCTAssertEqual(IdleLayout.balance(coming: try coming(16), recent: try recent(20)),
                       .init(arrangement: .columns, recentCount: 16))
    }

    func testTwoTierRowsCountTaller() throws {
        XCTAssertGreaterThan(IdleLayout.balance(coming: try coming(8, twoTiers: true), recent: try recent(20)).recentCount,
                             IdleLayout.balance(coming: try coming(8), recent: try recent(20)).recentCount)
    }

    func testStacksWhenUneven() throws {
        XCTAssertEqual(IdleLayout.balance(coming: try coming(30), recent: try recent(12)).arrangement, .stack)
        XCTAssertEqual(IdleLayout.balance(coming: try coming(0), recent: try recent(12)).arrangement, .stack)
        XCTAssertEqual(IdleLayout.balance(coming: nil, recent: nil).arrangement, .columns)
    }

    func testWidthRules() {
        XCTAssertEqual(IdleLayout.width(390), .phone)
        XCTAssertEqual(IdleLayout.width(680), .phone)
        XCTAssertEqual(IdleLayout.width(700), .medium)
        XCTAssertEqual(IdleLayout.width(940), .wide)
        XCTAssertEqual(IdleLayout.tileColumns(width: 294, tiles: 4), 2)
        XCTAssertEqual(IdleLayout.tileColumns(width: 700, tiles: 5), 4)
        XCTAssertEqual(IdleLayout.tileColumns(width: 1100, tiles: 5), 5)
        let balance = IdleLayout.Balance(arrangement: .columns, recentCount: 12)
        XCTAssertFalse(IdleLayout.sideBySide(width: 800, balance))
        XCTAssertTrue(IdleLayout.sideBySide(width: 1000, balance))
        XCTAssertEqual(IdleLayout.visibleRecent(width: 390, balance), 6)
        XCTAssertEqual(IdleLayout.visibleRecent(width: 1000, balance), 12)
    }

    // MARK: Time

    func testCountdownAndUntil() {
        XCTAssertEqual(IdleTime.until(now.addingTimeInterval(30), now: now), "in <1m")
        XCTAssertEqual(IdleTime.until(now.addingTimeInterval(2 * 3600 + 5 * 60), now: now), "in 2h 05m")
        XCTAssertEqual(IdleTime.until(now.addingTimeInterval(42 * 60), now: now), "in 42m")
        XCTAssertEqual(IdleTime.countdown(to: now.addingTimeInterval(342), now: now).text, "in 5:42")
        XCTAssertTrue(IdleTime.countdown(to: now.addingTimeInterval(-1), now: now).due)
        XCTAssertEqual(IdleTime.countdown(to: nil, now: now).text, "—")
        XCTAssertEqual(IdleTime.tileState(running: false, IdleTime.countdown(to: now.addingTimeInterval(50), now: now)), .soon)
        XCTAssertEqual(IdleTime.tileState(running: true, IdleTime.countdown(to: now.addingTimeInterval(500), now: now)), .run)
        XCTAssertEqual(IdleTime.ringFraction(target: now.addingTimeInterval(450), now: now, windowSeconds: 900), 0.5)
    }

    func testDayLabelsAndFeedRange() {
        let cal = IdleDeriveTests.utc
        let iso = ISO8601DateFormatter()
        XCTAssertEqual(IdleTime.dayLabel(iso.date(from: "2026-10-07T20:00:00Z")!, now: now, calendar: cal), "Tonight")
        XCTAssertEqual(IdleTime.dayLabel(iso.date(from: "2026-10-07T21:00:00Z")!.addingTimeInterval(-12 * 3600), now: now, calendar: cal), "Today")
        XCTAssertEqual(IdleTime.dayLabel(iso.date(from: "2026-10-08T00:30:00Z")!, now: now, calendar: cal), "Tomorrow")
        XCTAssertEqual(IdleTime.dayLabel(iso.date(from: "2026-10-09T01:00:00Z")!, now: now, calendar: cal,
                                         locale: Locale(identifier: "en_US_POSIX")), "Friday")
        let range = IdleTime.comingUpRange(now: now, calendar: cal)
        XCTAssertEqual(range.start, "2026-10-06")
        XCTAssertEqual(range.end, "2026-10-11")
    }

    // MARK: Quip

    func testQuipMatchesTheWeb() {
        XCTAssertEqual(VoiceQuip.mediaSuffix(kind: .series, title: "Loki", outcome: .grabbed),
                       "Winter came early — and it brought loot.")
        XCTAssertEqual(VoiceQuip.mediaSuffix(kind: .series, title: "queue", outcome: .grabbed),
                       "Logged, sorted, and dealt with.")
        XCTAssertEqual(VoiceQuip.mediaSuffix(kind: .series, title: "Batman & Robin", outcome: .grabbed),
                       "Consider it handled.")
        XCTAssertEqual(VoiceQuip.mediaSuffix(kind: .series, title: "Amélie", outcome: .grabbed),
                       "Logged, sorted, and dealt with.")
        XCTAssertEqual(VoiceQuip.mediaSuffix(kind: .series, title: "Dune: Part Two", outcome: .grabbed),
                       "The spice flows your way.")
    }
}
