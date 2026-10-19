import XCTest
@testable import FusionhaKit

final class MetadataSwitchTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func testPreviewDecodes() throws {
        let p = try decoder.decode(MetadataSwitchPreview.self, from: Data(#"""
            {"item_id": 1, "target_provider": "tvdb", "current_provider": "tmdb", "needs_search": false,
             "matched": {"id": 81189, "title": "Breaking Bad", "year": 2008, "poster": null},
             "diff_hash": "d", "plan_hash": "p", "agrees": false, "active_queue_blocked": false,
             "rows": [], "files": [{"media_file_id": 9, "raw_name": "a.mkv", "parsed_key": "S01E01", "quality": null,
               "matched_season": 1, "matched_number": 1, "matched_title": "Pilot", "new_name": "b.mkv",
               "confidence": "title-only-warn", "included": true}], "rename_count": 1}
            """#.utf8))
        XCTAssertEqual(p.matched?.id, 81189)
        XCTAssertEqual(p.files?.first?.confidence, "title-only-warn")
        XCTAssertEqual(p.renameCount, 1)
    }

    func testPlanCountsAndCopy() throws {
        let plan = try decoder.decode(NumberingPlan.self, from: Data(#"""
            {"item_id": 1, "target": "tvdb", "owner": "tvdb", "plan_hash": "h",
             "counts": {"renumbered": 3, "added": 1, "keep_for_review": 2, "unchanged": 12},
             "rows": [], "held": [], "blocked_by_queue": false, "blocked_episode_ids": [], "write_titles": true}
            """#.utf8))
        XCTAssertEqual(MetadataSwitchLogic.changeCount(plan), 6)
        XCTAssertEqual(MetadataSwitchLogic.summary(plan), "3 renumbered · 1 new · 2 held · 12 unchanged")
        XCTAssertEqual(MetadataSwitchLogic.why(plan, blocked: false), "6 changes · nothing downloaded or deleted")
        XCTAssertEqual(MetadataSwitchLogic.why(plan, blocked: true), "Blocked: downloads in flight")
    }

    func testProviderChoiceAndLabels() {
        XCTAssertEqual(MetadataSwitchLogic.current(nil), "tmdb")
        XCTAssertEqual(MetadataSwitchLogic.current("hybrid"), "hybrid")
        XCTAssertEqual(MetadataSwitchLogic.current("tvmaze"), "tmdb")
        XCTAssertEqual(MetadataSwitchLogic.label("tvdb"), "TheTVDB")
    }

    func testNumberingPin() {
        XCTAssertEqual(MetadataSwitchLogic.numberingSource(pin: nil, resolvedProvider: "hybrid"), "tvdb")
        XCTAssertEqual(MetadataSwitchLogic.numberingSource(pin: "tvmaze", resolvedProvider: "tmdb"), "tvmaze")
        XCTAssertEqual(MetadataSwitchLogic.numberingSource(pin: nil, resolvedProvider: "tmdb"), "tmdb")
        XCTAssertEqual(MetadataSwitchLogic.numberingOptions("tvdb").map(\.0), ["tvdb", "tvmaze"])
        XCTAssertEqual(MetadataSwitchLogic.numberingOptions("tmdb").map(\.0), ["tmdb", "tvmaze", "tvdb"])
    }
}
