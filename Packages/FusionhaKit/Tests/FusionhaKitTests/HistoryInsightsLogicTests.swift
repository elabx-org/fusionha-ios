import XCTest
@testable import FusionhaKit

final class HistoryInsightsLogicTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func versions() throws -> [DetailEdition] {
        try decoder.decode([DetailEdition].self, from: Data(#"""
            [{"id": 1, "tier": "HD-1080p", "monitored": true}, {"id": 2, "tier": "UHD-2160p", "monitored": true}]
            """#.utf8))
    }

    private func events() throws -> [HistoryEntry] {
        try decoder.decode([HistoryEntry].self, from: Data(#"""
            [{"id": 1, "event_type": "GRABBED", "created_at": "2026-10-01T10:00:00Z", "edition_id": 1, "indexer": "Nyaa (Prowlarr)"},
             {"id": 2, "event_type": "IMPORTED", "created_at": "2026-10-01T11:00:00Z", "edition_id": 1, "cf_score": 100,
              "source_title": "A.1080p"},
             {"id": 3, "event_type": "GRABBED", "created_at": "2026-10-03T10:00:00Z", "edition_id": 1, "indexer": "Alpha"},
             {"id": 4, "event_type": "IMPORTED", "created_at": "2026-10-03T11:00:00Z", "edition_id": 1, "cf_score": 250,
              "source_title": "B.1080p"},
             {"id": 5, "event_type": "IMPORTED", "created_at": "2026-10-02T11:00:00Z", "edition_id": 2, "cf_score": 50}]
            """#.utf8))
    }

    func testStats() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let s = HistoryInsightsLogic.stats(try versions(), try events(), calendar: cal)
        XCTAssertEqual(s.eventsCount, 5)
        XCTAssertEqual(s.daySpanLabel, "over 3 days")
        XCTAssertEqual(s.upgradesCount, 1)
        XCTAssertEqual(s.upgradesByTier, [.init(label: "HD", count: 1)])
        XCTAssertEqual(s.trendLabel, "HD upgraded")
        XCTAssertEqual(s.netScore, 150)
        XCTAssertTrue(s.hasAnyImport)
        XCTAssertEqual(s.indexerNames, ["Alpha", "Nyaa (Prowlarr)"])
    }

    func testProgressionAndSparkline() throws {
        let series = HistoryInsightsLogic.progression(try versions(), try events())
        XCTAssertEqual(series.map { $0.points.map(\.score) }, [[100, 250], [50]])
        XCTAssertEqual(HistoryInsightsLogic.sparkline(try events()), [100, 50, 250])
    }

    func testSwimlane() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let (lanes, start) = HistoryInsightsLogic.swimlane(try versions(), try events(), now: now)
        XCTAssertEqual(lanes[0].segments.map(\.title), ["A.1080p", "B.1080p"])
        XCTAssertEqual(lanes[0].segments.last?.end, now)
        XCTAssertEqual(lanes[0].segments.map(\.isCurrent), [false, true])
        XCTAssertEqual(start, DetailText.instant("2026-10-01T10:00:00Z"))
    }

    func testScoreFormat() {
        XCTAssertEqual(DetailText.score(120), "+120")
        XCTAssertEqual(DetailText.score(0), "0")
        XCTAssertEqual(DetailText.score(-40), "-40")
    }

    func testIndexerChip() {
        XCTAssertEqual(HistoryInsightsLogic.indexerChip("Nyaa (Prowlarr)"), "Nyaa")
        XCTAssertEqual(HistoryInsightsLogic.indexerChip("Alpha"), "Alpha")
    }
}
