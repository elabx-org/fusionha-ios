import XCTest
@testable import FusionhaKit

/// The held strip (web `held-strip.ts` + `HeldStrip.tsx` `lines` / `packLines`), ported
/// with the cases of `held-strip.test.tsx` on the iOS rescue fixture.
final class ManualImportHeldStripTests: XCTestCase {
    private struct NotAPack: Error {}

    /// The rescue fixture with `scanExtra` merged into the scan and each row's patch merged into its row.
    private func scan(_ scanExtra: [String: Any] = [:], rows patches: [[String: Any]]? = nil) throws -> ManualImportScan {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        json.merge(scanExtra) { _, new in new }
        if let patches {
            let base = try XCTUnwrap(json["rows"] as? [[String: Any]])
            json["rows"] = patches.enumerated().map { i, patch in
                var r = base[i % base.count]
                r["row_id"] = i + 1
                r.merge(patch) { _, new in new }
                return r
            }
        }
        return try APIClient.decoder.decode(ManualImportScan.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func pack(_ strip: ManualImportHeldStrip?) throws -> ManualImportHeldStrip.Pack {
        guard case .pack(let p)? = strip?.model else {
            XCTFail("not a pack")
            throw NotAPack()
        }
        return p
    }

    private let held900: [String: Any] = ["download_id": 900, "reason": "Not an upgrade",
                                          "detail": ["kind": "mislabeled", "mislabeled": true, "claimed_resolution": 2160,
                                                     "probed_quality": "WEBDL-1080p", "probed_resolution": ["w": 2560, "h": 1440]]]

    func testPackCountsLiveRows() throws {
        let p = try pack(ManualImportHeldStrip(scan: try scan()))
        XCTAssertEqual(p, .init(downs: 2, shared: 0, ups: 0, fresh: 1, open: 3, done: false, total: 3, oneDownload: false,
                                reason: "2 files measure 2560×1440, not the 2160p their names claim.",
                                why: ["Not an upgrade"], eligible: 2))
    }

    func testMislabelHoldsHaveNoOwnReason() throws {
        // One download, every hold a mislabel: the counts and the measured line already say it.
        let s = try scan(rows: [["held": held900], ["held": held900], ["held": held900]])
        XCTAssertEqual(try pack(ManualImportHeldStrip(scan: s)).why, [])
    }

    func testOwnReasonLeadsWithoutTheManualImportPointer() throws {
        let held: [String: Any] = ["download_id": 900, "reason": "This download holds 6 episode files but none is S02E09; review in Manual Import"]
        let s = try scan(["held_detail": NSNull()], rows: [["held": held], ["held": held]])
        let strip = try XCTUnwrap(ManualImportHeldStrip(scan: s))
        XCTAssertEqual(try pack(strip).why, ["This download holds 6 episode files but none is S02E09"])
        XCTAssertEqual(strip.line1.first, "This download holds 6 episode files but none is S02E09")
    }

    func testMergedScanNamesEachDownload() throws {
        let rows: [[String: Any]] = (0..<4).map { i in
            ["match": ["item_id": i < 2 ? 7 : 8, "title": i < 2 ? "Reservation Dogs" : "Kingdom", "confidence": "high"],
             "held": ["download_id": i < 2 ? 1 : 2, "reason": i < 2 ? "Two files claim S02E05" : "1 file could not be put in place"]]
        }
        let strip = try XCTUnwrap(ManualImportHeldStrip(scan: try scan(["held_detail": NSNull()], rows: rows)))
        let p = try pack(strip)
        XCTAssertEqual(p.why, ["Reservation Dogs: Two files claim S02E05", "Kingdom: 1 file could not be put in place"])
        // Several reasons head the second line instead.
        XCTAssertTrue(strip.line2?.hasPrefix("Reservation Dogs: Two files claim S02E05. Kingdom: 1 file could not be put in place. ") == true)
    }

    func testDecidedRowsLeaveTheOpenCountAndMixedReasonDrops() throws {
        let other: [String: Any] = ["download_id": 900, "reason": "Not an upgrade",
                                    "detail": ["kind": "mislabeled", "mislabeled": true, "claimed_resolution": 2160,
                                               "probed_resolution": ["w": 1920, "h": 800]]]
        let s = try scan(rows: [["replace_choice": "keep_current"], [:], ["held": other], ["held": held900]])
        let p = try pack(ManualImportHeldStrip(scan: s))
        // Row 1 kept: not live. Rows 3 (1920×800) and 4 (2560×1440) disagree, so no uniform reason.
        XCTAssertEqual(p.open, 3)
        XCTAssertEqual(p.downs, 2)
        XCTAssertNil(p.reason)
    }

    func testZeroPartsAreDropped() throws {
        // Every downgrade kept: only the new part remains.
        let s = try scan(rows: [["replace_choice": "keep_current"], [:], ["replace_choice": "keep_current"]])
        let strip = try XCTUnwrap(ManualImportHeldStrip(scan: s))
        XCTAssertEqual(strip.line1, ["Not an upgrade", "1 new"])
        XCTAssertFalse(strip.line1.contains { $0.hasPrefix("0 ") })
    }

    func testSharedRowsAreTheirOwnPart() throws {
        let s = try scan(rows: [["would_orphan": "E15"], [:], ["would_orphan": "E14"]])
        let p = try pack(ManualImportHeldStrip(scan: s))
        XCTAssertEqual([p.downs, p.shared, p.ups, p.fresh], [0, 2, 0, 1])
        XCTAssertEqual(ManualImportHeldStrip.packLines(p).line1.dropFirst(),
                       ["2 files share a library file with another episode", "1 new"])
    }

    func testANonImportableUpgradeStillCounts() throws {
        let up: [String: Any] = ["status": "no_match",
                                 "existing_file": ["media_file_id": 57, "quality": "WEBDL_1080P", "verdict": ["upgrade": true]]]
        let p = try pack(ManualImportHeldStrip(scan: try scan(rows: [[:], [:], up])))
        XCTAssertEqual(p.ups, 1)
        XCTAssertEqual(p.downs + p.shared + p.ups + p.fresh, 3)
    }

    func testEveryRowDecidedReadsDone() throws {
        let s = try scan(rows: [["committed": true], ["committed": true], ["committed": true]])
        let strip = try XCTUnwrap(ManualImportHeldStrip(scan: s))
        XCTAssertTrue(strip.done)
        XCTAssertEqual(strip.bulkEligible, 0)
        XCTAssertEqual(strip.line1, ["All 3 decided"])
        XCTAssertEqual(strip.line2, "Every download is finished.")
        let one = try scan(rows: [["committed": true, "held": held900], ["committed": true, "held": held900]])
        XCTAssertEqual(try XCTUnwrap(ManualImportHeldStrip(scan: one)).line2, "The download is finished.")
    }

    func testRowsOfAFinishedDownloadAreNotLive() throws {
        let s = try scan(rows: [["held": held900], ["held": held900]])
        let tallies = [900: ManualImportDecide.Tally(id: 900, total: 2, decided: 0, finished: true, linked: false)]
        XCTAssertTrue(try XCTUnwrap(ManualImportHeldStrip(scan: s, tallies: tallies)).done)
    }

    func testOneHeldFile() throws {
        let s = try scan(["held_detail": ["kind": "mislabeled", "mislabeled": true, "claimed_resolution": 2160,
                                          "probed_quality": "WEBDL-1080p", "probed_resolution": ["w": 2560, "h": 1440],
                                          "current_group": "FUZEER", "candidate_cf": 1150, "current_cf": 1280]],
                         rows: [[:]])
        let strip = try XCTUnwrap(ManualImportHeldStrip(scan: s))
        XCTAssertEqual(strip.model, .single(.init(
            reason: "smaller than its name says", measured: "measures 2560×1440, not 2160p",
            detail: "Name says 2160p, the file measures 2560×1440 (graded WEBDL-1080p).",
            guardLine: "would replace your 4K FUZEER copy", cf: "CF 1150 vs your 1280")))
        XCTAssertEqual(strip.line1, ["smaller than its name says", "would replace your 4K FUZEER copy", "CF 1150 vs your 1280"])
        // Phone: the measured size, then the guard sentence and the CF.
        XCTAssertEqual(strip.lines(compact: true),
                       .init(line1: ["measures 2560×1440, not 2160p"], line2: "Would replace your 4K FUZEER copy. · CF 1150 vs your 1280"))
    }

    func testOneHeldRowAmongUnheldRows() throws {
        let s = try scan(rows: [["held": NSNull(), "existing_file": NSNull()], [:]])
        guard case .single(let m) = try XCTUnwrap(ManualImportHeldStrip(scan: s)).model else { return XCTFail("single") }
        XCTAssertEqual(m.guardLine, "would replace your 4K FUZEER copy")
    }

    func testNoStripOutsideARescue() throws {
        XCTAssertNil(ManualImportHeldStrip(scan: try scan(["download_id": NSNull(), "held_reason": NSNull()])))
    }

    func testCfLineWritesNegativesWithAMinus() {
        XCTAssertEqual(ManualImportHeldStrip.cfCompareLine(-150, 0), "CF −150 vs your 0")
        XCTAssertNil(ManualImportHeldStrip.cfCompareLine(nil, 10))
    }
}
