import XCTest
@testable import FusionhaKit

/// The Manual search helpers, against the web's search-format.test.ts cases.
final class SearchFormatTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(type, from: Data(json.utf8))
    }

    private func release(_ guid: String, title: String = "A", quality: String = "WEBDL_1080P", score: Int = 0,
                         size: Double? = nil, age: Double? = nil, seeders: Int? = nil, indexer: String? = "NZBgeek") throws -> ReleasePreview {
        var fields: [String] = [
            #""guid": "\#(guid)""#, #""title": "\#(title)""#, #""quality": "\#(quality)""#, #""protocol": "USENET""#,
            #""indexer_id": 3"#, #""cf_score": \#(score)"#, #""action": "grab""#, #""reason": """#, #""flags": []"#,
        ]
        if let size { fields.append(#""size": \#(Int64(size))"#) }
        if let age { fields.append(#""age_seconds": \#(Int(age))"#) }
        if let seeders { fields.append(#""seeders": \#(seeders)"#) }
        if let indexer { fields.append(#""indexer_name": "\#(indexer)""#) }
        return try decode(ReleasePreview.self, "{\(fields.joined(separator: ","))}")
    }

    func testScoreIsAlwaysSigned() {
        XCTAssertEqual(ReleaseSearch.score(485), "+485")
        XCTAssertEqual(ReleaseSearch.score(0), "+0")
        XCTAssertEqual(ReleaseSearch.score(-40), "\u{2212}40")
    }

    func testCompactAge() {
        XCTAssertEqual(ReleaseSearch.age(nil), "—")
        XCTAssertEqual(ReleaseSearch.age(-1), "—")
        XCTAssertEqual(ReleaseSearch.age(30), "now")
        XCTAssertEqual(ReleaseSearch.age(5 * 3600), "5h")
        XCTAssertEqual(ReleaseSearch.age(3 * 86_400), "3d")
        XCTAssertEqual(ReleaseSearch.age(14 * 86_400), "2w")
        XCTAssertEqual(ReleaseSearch.age(65 * 86_400), "2mo")
        XCTAssertEqual(ReleaseSearch.age(400 * 86_400), "1y")
    }

    func testResolutionAndTier() {
        XCTAssertEqual(ReleaseSearch.resolution("REMUX_2160P"), "2160p")
        XCTAssertEqual(ReleaseSearch.resolution("WEBDL_720P"), "720p")
        XCTAssertEqual(ReleaseSearch.resolution("SDTV"), "SD")
        XCTAssertEqual(ReleaseSearch.tier("WEBRIP_2160P"), .uhd)
        XCTAssertEqual(ReleaseSearch.tier("HDTV_720P"), .hd)
        XCTAssertNil(ReleaseSearch.tier("UNKNOWN"))
        XCTAssertEqual(ReleaseSearch.tone("RAWHD"), .hd)
        XCTAssertNil(ReleaseSearch.tone("WEBDL_720P"))
    }

    func testAutoTarget() {
        let editions: [(id: Int, label: String, tier: QualityTier)] = [(1, "HD·1080p", .hd), (2, "UHD·4K", .uhd)]
        XCTAssertNil(ReleaseSearch.autoTarget("WEBDL_1080P", activeTier: .hd, editions: editions))
        XCTAssertEqual(ReleaseSearch.autoTarget("WEBDL_2160P", activeTier: .hd, editions: editions)?.targetLabel, "UHD·4K")
        let blocked = ReleaseSearch.autoTarget("WEBDL_2160P", activeTier: .hd, editions: [(1, "HD·1080p", .hd)])
        XCTAssertEqual(blocked?.tier, .uhd)
        XCTAssertNil(blocked?.targetLabel)
    }

    func testSortByScoreTieBreaksOnSize() throws {
        let rows = [
            try release("a", score: 10, size: 1),
            try release("b", score: 20, size: 1),
            try release("c", score: 10, size: 9),
        ]
        XCTAssertEqual(ReleaseSearch.sorted(rows, by: .score, ascending: false).map(\.guid), ["b", "c", "a"])
        XCTAssertEqual(ReleaseSearch.sorted(rows, by: .score, ascending: true).map(\.guid), ["a", "c", "b"])
    }

    func testSortMissingValuesSink() throws {
        let rows = [try release("a", age: nil, seeders: nil), try release("b", age: 60, seeders: 4)]
        XCTAssertEqual(ReleaseSearch.sorted(rows, by: .age, ascending: true).map(\.guid), ["b", "a"])
        XCTAssertEqual(ReleaseSearch.sorted(rows, by: .seed, ascending: false).map(\.guid), ["b", "a"])
        XCTAssertEqual(ReleaseSearch.indexer(try release("x", indexer: nil)), "#3")
    }

    func testScopeStatusLines() throws {
        let status = try decode(ReleaseScopeStatus.self, """
        {"backoff_active": true, "backoff_next_eligible_at": "2026-10-04T14:32:00", "backoff_consecutive_empty": 3,
         "failed_download_count": 1, "failed_grab_cooldown_active": true, "failed_grab_cooldown_until": null,
         "last_run_at": "2026-10-04T12:00:00", "last_run_releases": 5, "last_run_grabbed": 1, "last_run_rejected": 3,
         "now": "2026-10-04T13:00:00"}
        """)
        let lines = ReleaseSearch.scopeStatusLines(status) { _ in "14:32" }
        XCTAssertEqual(lines, [
            "Auto-search paused — 3 consecutive empty searches · resumes 14:32 · a manual search runs now and ignores the backoff",
            "Cooling down after 1 failed download · a manual search runs now and ignores the cooldown",
        ])
        XCTAssertEqual(ReleaseSearch.lastRunSummary(status), "Last auto-search: 5 seen, 1 grabbed, 3 rejected")
    }

    func testRetryHint() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(ReleaseSearch.retryHint(nil, now: now), "retrying")
        XCTAssertEqual(ReleaseSearch.retryHint(now.addingTimeInterval(-60), now: now), "retrying")
        XCTAssertEqual(ReleaseSearch.retryHint(now.addingTimeInterval(12 * 60), now: now), "retry in 12m")
        XCTAssertEqual(ReleaseSearch.retryHint(now.addingTimeInterval(150 * 60), now: now), "retry in 3h")
    }
}
