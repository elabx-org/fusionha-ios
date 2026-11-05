import XCTest
@testable import FusionhaKit

/// Manual Import grouped by problem (v2 S9) over a small The Office S05 pack:
/// each file sits in exactly one group by precedence, picks come only from
/// the server, and a card's choice never replaces a file's own choice.
final class MIProblemGroupingTests: XCTestCase {

    // MARK: Fixtures

    private func row(_ id: Int, _ extra: [String: Any] = [:]) -> [String: Any] {
        var r: [String: Any] = [
            "row_id": id, "source_path": "/dl/The.Office.S05E\(id).mkv", "filename": "The.Office.S05E\(id).mkv",
            "size": 5_000_000_000.0,
            "parsed": ["title": "The Office", "season": 5, "episodes": [id], "release_group": "EPSiLON", "quality": "REMUX_1080P"],
            "match": ["item_id": 3, "title": "The Office (US)", "confidence": "high"],
            "target": ["kind": "series", "tier": "HD-1080p", "season": 5, "episode": id, "episode_id": 500 + id,
                       "episode_ids": [500 + id]],
            "quality": "REMUX_1080P", "status": "needs_attention", "status_reason": "Replaces Remux-1080p",
            "selected": true, "committed": false, "held": ["download_id": 77],
            "probe": ["state": "ok", "runtime_seconds": 1320],
        ]
        r.merge(extra) { _, new in new }
        return r
    }

    private func existing(upgrade: Bool, runtime: Double = 1320) -> [String: Any] {
        ["media_file_id": 900, "quality": "REMUX_1080P", "release_group": "AsmoFuscated", "cf_score": 2800,
         "verdict": ["upgrade": upgrade, "code": upgrade ? "upgrade" : "quality_downgrade"],
         "probe": ["state": "ok", "runtime_seconds": runtime]]
    }

    private func upgrade(_ id: Int) -> [String: Any] {
        row(id, ["existing_file": existing(upgrade: true), "incoming_cf": ["score": 4700]])
    }

    private func shorter(_ id: Int) -> [String: Any] {
        row(id, ["existing_file": existing(upgrade: true, runtime: 3780), "probe": ["state": "ok", "runtime_seconds": 2520],
                 "selected": false])
    }

    private func decode(_ rows: [[String: Any]]) throws -> [ManualImportRow] {
        let scan: [String: Any] = ["scan_id": 1, "source_path": "/dl", "rows": rows, "download_id": 77]
        return try APIClient.decoder.decode(ManualImportScan.self, from: JSONSerialization.data(withJSONObject: scan)).rows
    }

    private let namesOther: [String: Any] = [
        "title_check": ["status": "names_other", "says": "Mafia",
                        "matches_episode": ["id": 7, "code": "S05E09", "title": "Mafia"]],
        "recommended": "rematch",
    ]

    /// The mock's pack in small: upgrades, two shorter cuts, a shared pair, one in the library.
    private func pack() throws -> [ManualImportRow] {
        try decode([
            upgrade(2), upgrade(3), upgrade(4),
            shorter(1), shorter(13),
            row(14, ["would_orphan": "Shares S05E14E15", "joint_rows": [15], "existing_file": NSNull()]),
            row(15, ["would_orphan": "Shares S05E14E15", "joint_rows": [14], "existing_file": NSNull()]),
            row(6, ["existing_file": existing(upgrade: false), "recommended": "keep_current"]),
        ])
    }

    // MARK: Groups

    func testEachFileSitsInExactlyOneGroup() throws {
        let rows = try pack()
        let groups = MIProblemGrouping.groups(rows)
        let ids = groups.flatMap(\.rowIds)
        XCTAssertEqual(ids.count, rows.count)
        XCTAssertEqual(Set(ids), Set(rows.map(\.rowId)))
        XCTAssertEqual(groups.map(\.problem), [.upgrade, .shorter, .sharedFile, .inLibrary])
        XCTAssertEqual(groups.map { MIProblemCopy.title($0.problem, count: $0.rows.count) },
                       ["3 upgrades", "2 are shorter than yours", "2 share one file", "1 already in your library"])
    }

    func testPrecedenceDecidesFilesWithSeveralFindings() throws {
        let rows = try decode([
            // A title naming another episode outranks a shared file.
            row(1, namesOther.merging(["would_orphan": "Shares", "joint_rows": [2]]) { _, n in n }),
            // The library already holding it outranks the title check.
            row(3, namesOther.merging(["existing_file": existing(upgrade: false), "recommended": "keep_current"]) { _, n in n }),
            // Shorter outranks a mislabel and not-an-upgrade.
            row(4, ["existing_file": existing(upgrade: false, runtime: 3780), "probe": ["state": "ok", "runtime_seconds": 2520],
                    "measured": ["mislabeled": true]]),
            // A mislabel outranks not-an-upgrade.
            row(5, ["existing_file": existing(upgrade: false), "measured": ["mislabeled": true]]),
            // Imported outranks everything.
            row(6, namesOther.merging(["committed": true]) { _, n in n }),
            row(7, ["match": ["item_id": NSNull(), "confidence": "none"], "status": "no_match"]),
            row(8, ["existing_file": existing(upgrade: false)]),
            row(9, ["status": "ready", "held": NSNull()]),
        ])
        XCTAssertEqual(rows.map(MIProblemGrouping.problem),
                       [.otherEpisode, .inLibrary, .shorter, .mislabeled, .imported, .noMatch, .notUpgrade, .new])
    }

    func testShorterNeedsBothRuntimesAndAClearGap() throws {
        let rows = try decode([
            row(1, ["existing_file": existing(upgrade: true, runtime: 1400)]),  // 22 vs 23 min: an upgrade
            row(2, ["existing_file": existing(upgrade: true, runtime: 3780), "probe": NSNull()]),
        ])
        XCTAssertEqual(rows.map(MIProblemGrouping.problem), [.upgrade, .upgrade])
        let t = try XCTUnwrap(MIProblemGrouping.runtimes(try pack()[3]))
        XCTAssertEqual(t.yours, 63)
        XCTAssertEqual(t.this, 42)
        XCTAssertTrue(t.shorter)
    }

    // MARK: Picks and starting choices

    func testPickOnlyWhereTheServerStatesOne() throws {
        let rows = try pack()
        let groups = MIProblemGrouping.groups(rows)
        XCTAssertNil(MIProblemGrouping.groupPick(groups[0], rows: rows), "no pick on upgrades")
        XCTAssertNil(MIProblemGrouping.groupPick(groups[1], rows: rows), "no pick on runtime")
        XCTAssertEqual(MIProblemGrouping.groupPick(groups[3], rows: rows), .skip)
        let two = try decode([row(14, ["recommended": "assign_episodes", "recommended_episodes": [14, 15],
                                       "existing_file": existing(upgrade: true)])])
        XCTAssertEqual(MIProblemGrouping.problem(two[0]), .twoEpisodes)
        XCTAssertEqual(MIProblemGrouping.pick(two[0], rows: two), .assign)
    }

    func testStartingChoicesNeverImportOverYourCopy() throws {
        let rows = try pack()
        let draft = MIDraft()
        XCTAssertEqual(draft.choice(rows[0], rows: rows), .importFile)
        XCTAssertNil(draft.choice(rows[3], rows: rows), "a shorter cut starts undecided")
        XCTAssertEqual(draft.choice(rows[7], rows: rows), .skip)
        XCTAssertEqual(MIProblemGrouping.options(rows[3], rows: rows), [.keep, .importFile])
        XCTAssertEqual(MIProblemGrouping.options(rows[5], rows: rows), [.importFile, .skip])
    }

    // MARK: Group vs file

    func testACardChoiceReadsMixedInsteadOfReplacingAFileChoice() throws {
        let rows = try pack()
        let shorterGroup = try XCTUnwrap(MIProblemGrouping.groups(rows).first { $0.problem == .shorter })
        var draft = MIDraft()
        draft.setFile(rows[4], .importFile, rows: rows)  // E13: Import anyway
        draft.setGroup(.shorter, .keep)
        XCTAssertEqual(draft.choice(rows[3], rows: rows), .keep)
        XCTAssertEqual(draft.choice(rows[4], rows: rows), .importFile, "the file's own choice stands")
        XCTAssertEqual(draft.state(shorterGroup, rows: rows), .mixed(overridden: [13]))
        draft.setEveryFile(shorterGroup, .keep)
        XCTAssertEqual(draft.state(shorterGroup, rows: rows), .uniform(.keep))
    }

    func testASharedFileTakesItsJointSpanWithIt() throws {
        let rows = try pack()
        var draft = MIDraft()
        draft.setFile(rows[5], .skip, rows: rows)
        XCTAssertEqual(draft.choice(rows[6], rows: rows), .skip)
    }

    // MARK: Footer and commit

    func testFooterWords() throws {
        let rows = try pack()
        var draft = MIDraft()
        draft.setGroup(.shorter, .keep)
        draft.setGroup(.sharedFile, .importFile)
        XCTAssertEqual(draft.counts(rows).footer, "Import 5 · keep 2 · skip 1")
        XCTAssertEqual(MIDraft().counts(rows).footer, "Import 3 · skip 1 · 4 to decide", "shared files start undecided")
    }

    func testCommitPlanBindsImportAnywayAndKeepsOnlyNewDecisions() throws {
        let rows = try pack()
        var draft = MIDraft()
        draft.setGroup(.shorter, .keep)
        draft.setGroup(.sharedFile, .importFile)
        draft.setFile(rows[4], .importFile, rows: rows)
        let plan = MICommitPlan(draft: draft, rows: rows)
        XCTAssertEqual(plan.replaces, [13])
        XCTAssertEqual(plan.kept, [1, 6])
        XCTAssertTrue(plan.patches.isEmpty, "an upgrade verdict needs no Import anyway override")
        let actions = Dictionary(uniqueKeysWithValues: plan.rows.map { ($0.rowId, $0.action) })
        XCTAssertEqual(actions[13], .importFile)
        XCTAssertEqual(actions[1], .keepCurrent)
        XCTAssertEqual(actions[14], .importFile)
        let request = try XCTUnwrap(plan.request(dispositions: [77: .remove], mode: .auto))
        XCTAssertEqual(request.dispositions, [77: .remove])
        XCTAssertEqual(request.importMode, .auto)
    }

    func testImportAnywayOverABetterCopyPatchesFirst() throws {
        let rows = try decode([row(8, ["existing_file": existing(upgrade: false)]),
                               row(9, namesOther.merging(["existing_file": NSNull()]) { _, n in n })])
        var draft = MIDraft()
        draft.setFile(rows[0], .importFile, rows: rows)
        draft.setFile(rows[1], .rematch, rows: rows)
        let plan = MICommitPlan(draft: draft, rows: rows)
        XCTAssertEqual(plan.patches.map(\.rowId), [8, 9])
        XCTAssertEqual(plan.patches[0].fields, ["replace_choice": .string("import")])
        XCTAssertEqual(plan.rematched, [9])
        XCTAssertNil(plan.request(dispositions: [77: .remove], mode: .auto)?.dispositions[77])
    }

    // MARK: Words

    func testCardWords() throws {
        let rows = try pack()
        let groups = MIProblemGrouping.groups(rows)
        XCTAssertEqual(MIProblemCopy.files(groups[0].rows), "E2 to E4")
        XCTAssertEqual(MIProblemCopy.files(groups[2].rows), "E14 · E15")
        XCTAssertEqual(MIProblemCopy.why(groups[0])?.lead, "EPSiLON Remux (+4,700)")
        XCTAssertEqual(MIProblemCopy.why(groups[1])?.rest, "These files run 42 min; yours run 63 min.")
        XCTAssertEqual(MIProblemCopy.label(.importFile, .sharedFile, count: 2), "Import both")
        XCTAssertEqual(MIProblemCopy.label(.importFile, .shorter, count: 2), "Import anyway")
        XCTAssertTrue(MIProblemCopy.consequence(.importFile, groups[1]).loss)
        XCTAssertEqual(MIProblemCopy.consequence(.keep, groups[1]).text, "Your 63-min copies stay")
    }

    func testDoneToastHasNoUndo() throws {
        var raw = (0..<3).map { upgrade($0 + 2) }
        raw = raw.map { var r = $0; r["committed"] = true; return r } + [shorter(1)]
        let rows = try decode(raw)
        let toast = MIProblemCopy.doneToast(rows, finish: FinishRescueResult(mode: "removed", blocklisted: false, libraryLinked: false))
        XCTAssertEqual(toast.title, "The Office (US) S05: imported 3, kept 1 of yours")
        XCTAssertEqual(toast.detail, "Download removed · Manual Import closed")
    }
}
