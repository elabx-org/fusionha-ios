import XCTest
@testable import FusionhaKit

/// The bulk decide's summary and copy (fusionha 0.4.225, the web's
/// `bulk-summary.ts` / `bulk-caps.ts`), over the mock's The Office S06 pack:
/// E03 already kept with a leave, E04 + E05 share one library file.
final class ManualImportBulkTests: XCTestCase {
    private func fixture() throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-decide", withExtension: "json", subdirectory: "Fixtures"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    /// The fixture's scan, each `edit` applied to its JSON first.
    private func scan(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> ManualImportScan {
        var scan = try XCTUnwrap(fixture()["scan"] as? [String: Any])
        edit(&scan)
        return try APIClient.decoder.decode(ManualImportScan.self, from: JSONSerialization.data(withJSONObject: scan))
    }

    private func summary(_ scan: ManualImportScan, _ selected: Set<Int>, canRemove: Bool = true) -> ManualImportBulkSummary {
        ManualImportBulkSummary(context(scan, selected), canRemove: canRemove)
    }

    private func context(_ scan: ManualImportScan, _ selected: Set<Int>) -> ManualImportBulk.Context {
        .init(rows: scan.rows, selected: selected, scan: scan, tallies: ManualImportDecide.tallies(scan))
    }

    /// No leave stands on the download.
    private func noLeave(_ s: inout [String: Any]) {
        s["downloads"] = [["id": 77, "rows_total": 8, "rows_decided": 1, "finished": false, "library_linked": false]]
        var rows = s["rows"] as! [[String: Any]]
        rows[2]["finish_disposition"] = NSNull()
        s["rows"] = rows
    }

    /// A folder scan of two shows and a file with no match.
    private func folder(_ s: inout [String: Any]) {
        s["download_id"] = NSNull()
        s["held_reason"] = NSNull()
        s["held_detail"] = NSNull()
        s["downloads"] = []
        var rows = (s["rows"] as! [[String: Any]]).map { r -> [String: Any] in
            var r = r
            r["held"] = NSNull()
            return r
        }
        rows[5]["match"] = ["item_id": 40, "title": "The Bear", "year": 2022, "confidence": "high"]
        rows[5]["target"] = ["kind": "series", "tier": "HD-1080p", "season": 3, "episode": 1, "episode_ids": [901]]
        rows[5]["parsed"] = ["title": "The Bear", "season": 3, "episodes": [1]]
        var none = rows[7]
        none["row_id"] = 9
        none["filename"] = "home.video.2019.mp4"
        none["status"] = "no_match"
        none["match"] = ["item_id": NSNull(), "confidence": "none"]
        none["target"] = ["kind": "movie", "tier": "HD-1080p"]
        none["existing_file"] = NSNull()
        rows.append(none)
        s["rows"] = rows
    }

    // MARK: Decoding

    func testScanDecodesTheNewFields() throws {
        let scan = try scan()
        XCTAssertEqual(scan.rows[2].finishDisposition, "leave")
        XCTAssertEqual(scan.rows[3].jointRows, [5])
        XCTAssertEqual(scan.rows[3].orphanEpisodeIds, [605])
        XCTAssertNil(scan.rows[0].jointRows)
        let dl = try XCTUnwrap(scan.downloads?.first)
        XCTAssertEqual(dl.finishDisposition, .leave)
        XCTAssertEqual(dl.leaveRowId, 3)
        let tally = try XCTUnwrap(ManualImportDecide.tallies(scan)[77])
        XCTAssertEqual(tally.disposition, .leave)
        XCTAssertEqual(tally.leaveRowId, 3)
        XCTAssertEqual(tally.decided, 1)
    }

    func testDecideAnswerDecodes() throws {
        let data = try JSONSerialization.data(withJSONObject: try XCTUnwrap(fixture()["decide"]))
        let res = try APIClient.decoder.decode(ManualImportDecideResult.self, from: data)
        XCTAssertEqual(res.scan.scanId, 52)
        XCTAssertEqual(res.results?.first?.rowId, 6)
        XCTAssertEqual(res.finishes?.first?.deletedFiles, false, "deleted_files is a boolean on the wire")
        XCTAssertEqual(res.finishes?.first?.result?.mode, "left")
        XCTAssertEqual(res.downloads?.first?.finished, true)
        XCTAssertEqual(res.asCommit.results.count, 1)
    }

    // MARK: Held pack (the mock: E02, E04, E06, E07 ticked)

    func testHeldSelectionSummary() throws {
        let s = summary(try scan(), [2, 4, 6, 7])
        XCTAssertEqual(s.imp.map(\.rowId), [6])
        XCTAssertEqual(s.keep.map(\.rowId), [2, 4, 7])
        XCTAssertEqual(s.skip.map(\.rowId), [6])
        XCTAssertEqual(s.of(3), "3 of 4")
        XCTAssertEqual(s.importSubtitle, "1 of 4 can import")
        XCTAssertEqual(s.impOutcome, "Import 1 · E06 imports in place")
        XCTAssertEqual(s.skipOutcome, "Skip 1 · nothing is imported for E06")
        XCTAssertEqual(s.skipLabel, "Skip E06")
        XCTAssertEqual(s.reasons.imp, "E04 shares one file in your library; importing one alone would leave the other without a file. "
                       + "E02 and E07 would replace better copies: import them from the row.")
        XCTAssertEqual(s.reasons.keep, "E06 has no copy in your library to keep: use Skip.")
        XCTAssertEqual(s.reasons.skip, "E02, E04 and E07 have a copy in your library: use Keep current for them.")
        XCTAssertNil(s.reasons.leave)
        XCTAssertEqual(s.lines.map(\.text), ["keep current (not an upgrade)", "keep current (shared file)",
                                             "import · skip (new episode)", "keep current (not an upgrade)"])
    }

    func testAStandingLeaveRulesOutRemove() throws {
        let s = summary(try scan(), [2, 4, 6, 7])
        XCTAssertEqual(s.leaveRowCode, "E03")
        XCTAssertEqual(s.preferred, .leave)
        XCTAssertEqual(s.dispositions.map(\.value), [.remove, .removeBlocklist, .leave])
        XCTAssertEqual(s.dispositions.map(\.recommended), [false, false, true])
        XCTAssertEqual(s.dispositions[0].off, "E03 chose leave for this download. Change it on E03.")
        XCTAssertNil(s.dispositions[2].off)
        XCTAssertEqual(s.keepOutcome(.leave),
                       "Keep current for 3 · the download is left in the client, as E03 chose, once every row is decided · 4 still to decide")
        XCTAssertEqual(s.outcome(.leave), [s.impOutcome!, s.keepOutcome(.leave)!])
    }

    func testKeepSendsThePickExceptOverAStandingLeave() throws {
        let s = summary(try scan(), [2, 4, 6, 7])
        let leave = try XCTUnwrap(s.request(.keepCurrent, pick: .leave, mode: .auto))
        XCTAssertEqual(leave.rows.map(\.rowId), [2, 4, 7])
        XCTAssertEqual(leave.dispositions, [77: .leave])
        XCTAssertNil(leave.importMode)
        XCTAssertEqual(s.request(.keepCurrent, pick: .remove, mode: .auto)?.dispositions, [:])
        let imp = try XCTUnwrap(s.request(.importFile, mode: .hardlink))
        XCTAssertEqual(imp.rows, [.init(rowId: 6, action: .importFile)])
        XCTAssertEqual(imp.importMode, .hardlink)
        XCTAssertEqual(s.request(.skip, mode: .auto)?.rows, [.init(rowId: 6, action: .skip)])
    }

    func testRequestBody() throws {
        let req = ManualImportDecideRequest(rows: [.init(rowId: 2, action: .keepCurrent), .init(rowId: 6, action: .skip)],
                                            dispositions: [77: .removeBlocklist], importMode: .auto)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(req.json)) as? [String: Any])
        let rows = try XCTUnwrap(body["rows"] as? [[String: Any]])
        XCTAssertEqual(rows.map { $0["row_id"] as? Int }, [2, 6])
        XCTAssertEqual(rows.map { $0["action"] as? String }, ["keep_current", "skip"])
        XCTAssertEqual(body["dispositions"] as? [String: String], ["77": "remove_blocklist"])
        XCTAssertEqual(body["import_mode"] as? String, "AUTO")
        let bare = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(
            ManualImportDecideRequest(rows: [.init(rowId: 1, action: .importFile)]).json)) as? [String: Any])
        XCTAssertNil(bare["dispositions"])
        XCTAssertNil(bare["import_mode"])
    }

    func testJointSpanImportsTogether() throws {
        let scan = try scan()
        let both = summary(scan, [4, 5])
        XCTAssertEqual(both.imp.map(\.rowId), [4, 5])
        XCTAssertEqual(both.impOutcome, "Import 2 · E04 and E05 import in place")
        XCTAssertNil(both.reasons.imp)
        XCTAssertEqual(both.importSubtitle, "imports in place")
        XCTAssertEqual(ManualImportBulk.jointNote(scan.rows[3], context(scan, [])), "Shared file with E05 · imports together")
        XCTAssertNil(ManualImportBulk.jointNote(scan.rows[0], context(scan, [])))
    }

    func testDecidedRowsAndSelectAllUndecided() throws {
        let scan = try scan()
        let s = summary(scan, [3, 6])
        XCTAssertEqual(s.decided.map(\.rowId), [3])
        XCTAssertEqual(s.decidedNote, "E03 is already decided, so nothing changes for it.")
        XCTAssertEqual(s.of(1), "1 of 2")
        XCTAssertEqual(s.lines.first?.text, "already decided")
        XCTAssertEqual(ManualImportBulk.undecided(context(scan, [])).map(\.rowId), [1, 2, 4, 5, 6, 7, 8])
    }

    func testDispositionsWithoutALeave() throws {
        let s = summary(try scan(noLeave), [2, 7])
        XCTAssertNil(s.leaveRowCode)
        XCTAssertEqual(s.preferred, .remove)
        XCTAssertEqual(s.dispositions.map(\.recommended), [false, false, false], "Recommended never marks a plain remove")
        XCTAssertTrue(s.dispositions.allSatisfy { $0.off == nil })
        XCTAssertEqual(s.dispositions[0].detail, ManualImportBulkCopy.removePlain)
        XCTAssertEqual(s.request(.keepCurrent, pick: .remove, mode: .auto)?.dispositions, [77: .remove])
        XCTAssertEqual(s.keepOutcome(.remove),
                       "Keep current for 2 · the download is removed once every row is decided · 5 still to decide")
    }

    func testProofRecommendsBlocklist() throws {
        let s = summary(try scan { s in
            noLeave(&s)
            s["held_detail"] = ["kind": "mislabeled", "mislabeled": true, "recommend_blocklist": true,
                                "release_blocklisted": false, "claimed_resolution": 1080,
                                "probed_resolution": ["w": 1280, "h": 720]]
        }, [2, 7])
        XCTAssertEqual(s.preferred, .removeBlocklist)
        XCTAssertEqual(s.dispositions.map(\.recommended), [false, true, false])
        XCTAssertEqual(s.dispositions[1].detail,
                       "E02 and E07 measures 1280×720 but is named 1080p, so this release is blocklisted and not grabbed again.")
        XCTAssertEqual(s.lines.first?.text, "keep current (measures 1280×720)")
    }

    func testRemoveNeedsAdmin() throws {
        let s = summary(try scan(noLeave), [2, 7], canRemove: false)
        XCTAssertEqual(s.dispositions.map(\.value), [.leave])
        XCTAssertEqual(s.dispositions.map(\.recommended), [false])
        XCTAssertEqual(s.preferred, .leave)
        XCTAssertEqual(s.request(.keepCurrent, pick: s.preferred, mode: .auto)?.dispositions, [77: .leave])
    }

    func testKeepOutcomeNowOrOnceEveryRowIsDecided() throws {
        let open = summary(try scan(), [1, 2, 4, 5, 6, 7, 8])
        XCTAssertEqual(open.keepOutcome(.leave),
                       "Keep current for 6 · the download is left in the client, as E03 chose, once every row is decided · 1 still to decide")
        // Without E06 (no copy) every other row is kept by this call: the download ends now.
        let all = summary(try scan { s in s["rows"] = (s["rows"] as! [[String: Any]]).filter { $0["row_id"] as? Int != 6 } },
                          [1, 2, 4, 5, 7, 8])
        XCTAssertEqual(all.keepOutcome(.leave),
                       "Keep current for 6 · the download is left in the client, as E03 chose now: nothing else in it to decide")
    }

    // MARK: Folder scan (no held download, two shows)

    func testFolderScanHasNoDispositionsAndTitlesTheCodes() throws {
        let s = summary(try scan(folder), [1, 2, 6, 9])
        XCTAssertFalse(s.held)
        XCTAssertTrue(s.dispositions.isEmpty)
        XCTAssertEqual(s.impOutcome, "Import 2 · The Office E01 and The Bear E01 import in place")
        XCTAssertEqual(s.keepOutcome(.remove), "Keep current for 2 · nothing imported, your library file stays")
        XCTAssertEqual(s.skipOutcome, "Skip 2 · nothing is imported for The Bear E01 and home.video.2019.mp4")
        XCTAssertEqual(s.reasons.imp, "The Office E02 would replace a better copy: import it from the row. "
                       + "home.video.2019.mp4 has no library match: match it from the row.")
        XCTAssertEqual(s.reasons.keep, "The Bear E01 and home.video.2019.mp4 have no copy in your library to keep: use Skip.")
        XCTAssertEqual(s.outcome(.remove), [s.impOutcome!])
        XCTAssertEqual(s.request(.keepCurrent, pick: .remove, mode: .auto)?.dispositions, [:])
        XCTAssertEqual(s.lines.last?.code, "home.video.2019.mp4")
        XCTAssertEqual(s.lines.last?.text, "skip (no library match)")
        XCTAssertEqual(s.lines.map(\.code), ["The Office E01", "The Office E02", "The Bear E01", "home.video.2019.mp4"])
    }

    func testFolderKeepOnly() throws {
        let s = summary(try scan(folder), [2])
        XCTAssertEqual(s.outcome(.remove), ["Keep current for 1 · nothing imported, your library file stays"])
        XCTAssertEqual(s.reasons.skip, "Only for files with no copy in your library. This one has one: use Keep current.")
        XCTAssertEqual(ManualImportBulk.shortCode(try scan(folder).rows[1]), "E02", "rows keep the bare code")
    }

    // MARK: The gate (only held downloads are approved)

    func testBarOnlyOnHeldDownloadsByDefault() throws {
        XCTAssertFalse(ManualImportFeatures.barEverywhere, "bar in every scenario ships off")
        XCTAssertTrue(ManualImportFeatures.bulkBar(try scan()), "a held download gets the bar")
        XCTAssertFalse(ManualImportFeatures.bulkBar(try scan(folder)), "a folder scan keeps the selection sheet")
        XCTAssertFalse(ManualImportFeatures.bulkBar(nil))
        XCTAssertTrue(ManualImportFeatures.bulkBar(try scan(folder), everywhere: true), "one switch turns it on")
    }

    func testApplyingLine() {
        XCTAssertEqual(ManualImportBulkSummary.applyingLine("Skip 1 · nothing is imported for E06", held: true),
                       "Skip 1 · nothing is imported for E06. Rows lock while this runs; nothing is removed until every row of a download is decided.")
        XCTAssertEqual(ManualImportBulkSummary.applyingLine("Import 2 · E01 and E02 import in place", held: false),
                       "Import 2 · E01 and E02 import in place")
    }

    func testPerRowKeepPreselectsTheSavedDisposition() throws {
        let scan = try scan()
        XCTAssertEqual(ManualImportDecide.keepChoice(scan.rows[1], scan, linked: false).preferred, .remove)
        XCTAssertEqual(ManualImportDecide.keepChoice(scan.rows[1], scan, linked: false, saved: .leave).preferred, .leave)
        let guarded = try self.scan { s in s["held_detail"] = ["kind": "quality", "release_blocklisted": true] }
        XCTAssertEqual(ManualImportDecide.keepChoice(guarded.rows[1], guarded, linked: false, saved: .removeBlocklist).preferred,
                       .remove, "a saved pick that is no longer offered falls back")
    }

    func testCodeList() {
        XCTAssertEqual(ManualImportBulk.codeList([]), "")
        XCTAssertEqual(ManualImportBulk.codeList(["E01"]), "E01")
        XCTAssertEqual(ManualImportBulk.codeList(["E01", "E02"]), "E01 and E02")
        XCTAssertEqual(ManualImportBulk.codeList(["E01", "E02", "E03"]), "E01, E02 and E03")
    }
}
