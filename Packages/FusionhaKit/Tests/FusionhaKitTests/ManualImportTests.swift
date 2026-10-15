import XCTest
@testable import FusionhaKit

/// Manual Import's held-download rescue (`api/schemas_manual_import*.py` and
/// the web's `routes/manual-import/*` rules).
final class ManualImportTests: XCTestCase {
    private func scan() throws -> ManualImportScan {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ManualImportScan.self, from: Data(contentsOf: url))
    }

    func testScanDecodes() throws {
        let scan = try scan()
        XCTAssertTrue(scan.isRescue)
        XCTAssertEqual(scan.probePending, 1)
        XCTAssertEqual(scan.rows.count, 3)
        let row = scan.rows[0]
        XCTAssertEqual(row.target.coveredEpisodeIds, [301])
        XCTAssertEqual(scan.rows[2].target.coveredEpisodeIds, [303])
        XCTAssertEqual(row.existingFile?.mediaFileId, 55)
        XCTAssertEqual(row.existingFile?.verdict?.provenCf, 900)
        XCTAssertEqual(row.nameVsFile?.count, 2)
        XCTAssertEqual(ManualImportRules.episodeCode(row), "S02E01")
    }

    func testStatusOfHeldRows() throws {
        let rows = try scan().rows
        XCTAssertEqual(ManualImportRules.status(rows[0]), .notUpgrade)
        XCTAssertEqual(ManualImportRules.statusLong(rows[0]), "Held · not an upgrade · replaces your 4K FUZEER copy")
        // A held empty slot imports as new.
        XCTAssertEqual(ManualImportRules.status(rows[1]), .ready)
        XCTAssertEqual(ManualImportRules.statusLong(rows[1]), "Ready · new")
    }

    func testProvenMislabelHoldStartsUnticked() throws {
        let scan = try scan()
        XCTAssertTrue(ManualImportRules.provenMislabelHold(scan.rows[0]))
        XCTAssertEqual(ManualImportRules.initialSelection(scan), [2, 3])
    }

    func testFinishPlan() throws {
        let rows = try scan().rows
        // Row 1 is unticked and undecided; 2 and 3 import.
        var plan = ManualImportFinishPlan(rows: rows, selected: [2, 3])
        XCTAssertEqual(plan.kind, .importOnly)
        XCTAssertEqual(plan.label, "Force import 2")
        XCTAssertEqual(plan.need, 1)
        // Nothing ready: the button waits for a choice.
        plan = ManualImportFinishPlan(rows: rows, selected: [])
        XCTAssertEqual(plan.kind, .need)
        XCTAssertEqual(plan.label, "3 files need a decision")
        XCTAssertTrue(plan.disabled)
    }

    func testHeldStripForAPack() throws {
        let strip = try XCTUnwrap(ManualImportHeldStrip(scan: try scan()))
        XCTAssertEqual(strip.line1, ["2 files would replace better copies", "0 upgrades", "1 new"])
        XCTAssertEqual(strip.line2, "2 files measure 2560×1440, not the 2160p their names claim. 2 still to decide; open a row to compare.")
        XCTAssertEqual(strip.bulkEligible, 2)
        // "To decide" follows the footer's count when it is passed.
        let plan = ManualImportFinishPlan(rows: try scan().rows, selected: [])
        let synced = try XCTUnwrap(ManualImportHeldStrip(scan: try scan(), decide: plan.need))
        XCTAssertEqual(synced.line2, "2 files measure 2560×1440, not the 2160p their names claim. 3 still to decide; open a row to compare.")
    }

    func testCompareAndSummary() throws {
        let row = try scan().rows[0]
        let which = try XCTUnwrap(ManualImportCompare.whichFileRows(row))
        XCTAssertEqual(which.first?.tone, .down)
        XCTAssertEqual(which.first(where: { $0.label == "Dynamic range" })?.current, "HDR10")
        XCTAssertEqual(which.last?.incoming, "900")
        XCTAssertEqual(ManualImportCompare.summaryLine(row), "1440p · SDR · HEVC · DDP 5.1 · FAKE")
        XCTAssertTrue(ManualImportCompare.nameFileRows(row)[0].bad)
    }

    func testCopy() {
        XCTAssertEqual(ManualImportCopy.commitNotice(ok: 3, warned: 1, failed: 1),
                       "Imported 2 files in place · 1 still being put in place · 1 failed")
        XCTAssertEqual(ManualImportCopy.finishReceipt(mode: "removed", imported: 0, kept: 1, group: "FUZEER", count: 1),
                       "Kept your FUZEER copy · download removed")
        let refused = APIError.http(status: 422, body: #"{"detail":{"invalid_rows":[{"row_id":1,"reason":"x"}]}}"#)
        XCTAssertEqual(refused.invalidRowCount, 1)
        XCTAssertEqual(ManualImportCopy.commitError(refused), "1 row can't be imported. Fix or untick it.")
    }
}
