import XCTest
@testable import FusionhaKit

/// The 0.4.193 episode-title and runtime checks (`title-check.ts`).
final class ManualImportTitleTests: XCTestCase {
    /// The fixture's first row with `extra` merged into its JSON.
    private func row(_ extra: [String: Any]) throws -> ManualImportRow {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        var scan = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var rows = try XCTUnwrap(scan["rows"] as? [[String: Any]])
        rows[0].merge(extra) { _, new in new }
        scan["rows"] = [rows[0]]
        let data = try JSONSerialization.data(withJSONObject: scan)
        return try XCTUnwrap(APIClient.decoder.decode(ManualImportScan.self, from: data).rows.first)
    }

    private let namesOther: [String: Any] = [
        "title_check": ["status": "names_other", "says": "Mafia",
                        "matches_episode": ["id": 7, "code": "S02E04-E05", "title": "Mafia"],
                        "same_release_exists": true],
        "recommended": "rematch",
    ]

    func testNamesOtherBlocksUntilResolved() throws {
        let blocked = try row(namesOther)
        XCTAssertTrue(ManualImportRules.titleBlocked(blocked))
        XCTAssertEqual(ManualImportRules.status(blocked), .titleEpisode)
        XCTAssertEqual(ManualImportRules.statusShort(blocked), "Title ≠ episode")
        XCTAssertEqual(ManualImportRules.statusLong(blocked), "Title ≠ episode · the file says 'Mafia', that is S02E04-E05")
        XCTAssertFalse(ManualImportRules.isBulkSelectable(blocked))
        XCTAssertFalse(ManualImportHeldStrip.bulkEligible(blocked))

        var dismissed = namesOther
        dismissed["episode_title_dismissed"] = true
        XCTAssertFalse(ManualImportRules.titleBlocked(try row(dismissed)))
        var kept = namesOther
        kept["replace_choice"] = "keep_current"
        XCTAssertFalse(ManualImportRules.titleBlocked(try row(kept)))
    }

    func testRematchSpansTheTwoParter() throws {
        let fields = try XCTUnwrap(ManualImportRules.rematchFields(try row(namesOther)))
        XCTAssertEqual(fields["episodes"], .array([.int(4), .int(5)]))
        XCTAssertNil(fields["season"], "same season as the target")
    }

    func testRuntimeAndAssign() throws {
        let r = try row([
            "runtime_check": ["seconds": 2640, "median_episode_seconds": 1320, "episodes_estimate": 2],
            "recommended": "assign_episodes", "recommended_episodes": [1, 2],
        ])
        XCTAssertEqual(ManualImportRules.runtimeLine(r), "44 min, about 2 episodes (each runs 22 min)")
        let plan = try XCTUnwrap(ManualImportRules.assignPlan(r))
        XCTAssertEqual(plan.episodes, [1, 2])
        XCTAssertTrue(plan.recommended)
        XCTAssertEqual(ManualImportRules.episodesLabel(plan.episodes), "E01 + E02")
    }

    func testOrphanTextDropsTheAddSuggestion() throws {
        let r = try row(namesOther.merging([
            "would_orphan": "Replacing would delete E05's only file. Add E05 to this file's episodes or keep the current file.",
        ]) { _, new in new })
        XCTAssertEqual(ManualImportRules.orphanText(r), "Replacing would delete E05's only file. Keep the current file.")
    }
}
