import XCTest
@testable import FusionhaKit

/// Manual Import safety (fusionha 0.4.233): `held_target`, "Replace your
/// copy?", the 422 replace refusal, 409 `leave_stands` and the H3 receipt.
final class ManualImportReplaceTests: XCTestCase {
    private func scan() throws -> ManualImportScan {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        return try APIClient.decoder.decode(ManualImportScan.self, from: Data(contentsOf: url))
    }

    func testHeldTargetDecodes() throws {
        let t = try APIClient.decoder.decode(ManualImportHeldTarget.self, from: Data(#"[12, "UHD-2160p", null, [301, 300]]"#.utf8))
        XCTAssertEqual(t, ManualImportHeldTarget(itemId: 12, tier: "UHD-2160p", edition: nil, episodeIds: [301, 300]))
        let movie = try APIClient.decoder.decode(ManualImportHeldTarget.self, from: Data(#"[7, "HD-1080p", "Director's Cut", []]"#.utf8))
        XCTAssertEqual(movie.edition, "Director's Cut")
        XCTAssertEqual(movie.episodeIds, [])
        // Older scans have no stamp: never on the held slot.
        let row = try scan().rows[0]
        XCTAssertNil(row.heldTarget)
        XCTAssertFalse(ManualImportDecide.onHeldSlot(row))
    }

    func testReplaceConfirmLine() throws {
        let rows = try scan().rows
        XCTAssertEqual(ManualImportDecide.replaceConfirm(rows[0]),
                       "Replaces your WEBDL-2160p FUZEER copy, which is better than this file · CF 1200 → 900")
        // An empty slot never asks.
        XCTAssertNil(ManualImportDecide.replaceConfirm(rows[1]))
        // No scores: no CF part.
        XCTAssertEqual(ManualImportDecide.replaceConfirm(rows[2]), "Replaces your WEBDL-2160p FUZEER copy, which is better than this file")
        // Import this file carries the ask; Re-match only re-targets.
        XCTAssertEqual(ManualImportDecide.importAction(rows[0])?.confirm, ManualImportDecide.replaceConfirm(rows[0]))
        XCTAssertEqual(ManualImportDecide.importAction(rows[0])?.commits, true)
        XCTAssertNil(ManualImportDecide.importAction(rows[1])?.confirm)
    }

    func testCommitReplaceRefusalDecodes() {
        let err = APIError.http(status: 422, body: #"""
        {"detail": {"invalid_rows": [
          {"row_id": 4, "reason": "Not an upgrade over the current WEBDL-1080p file — choose Keep current file or Import anyway"},
          {"row_id": 5, "reason": "quality is not set"}]}}
        """#)
        XCTAssertEqual(err.replaceRefusals, [ManualImportReplaceRefusal(
            rowId: 4, reason: "Not an upgrade over the current WEBDL-1080p file — choose Keep current file or Import anyway")])
        XCTAssertEqual(err.invalidRowCount, 2)
        XCTAssertEqual(APIError.http(status: 409, body: #"{"detail": "x"}"#).replaceRefusals, [])
    }

    func testLeaveStandsDecodes() {
        let err = APIError.http(status: 409, body: #"""
        {"detail": {"code": "leave_stands", "download_id": 77, "row_id": 3,
          "detail": "A leave was chosen for this download on another file; change it there."}}
        """#)
        XCTAssertEqual(err.leaveStands, ManualImportLeaveStands(
            downloadId: 77, rowId: 3, detail: "A leave was chosen for this download on another file; change it there."))
        XCTAssertEqual(ManualImportCopy.finishError(err), "A leave was chosen for this download on another file; change it there.")
        XCTAssertNil(APIError.http(status: 409, body: #"{"detail": {"code": "rows_open"}}"#).leaveStands)
        XCTAssertEqual(ManualImportDecide.finishCodeMessage("leave_stands"), ManualImportCopy.leaveStands)
    }

    func testFinishedModeBlocklistReceipt() throws {
        let linked = try APIClient.decoder.decode(FinishRescueResult.self, from: Data(
            #"{"mode": "finished", "blocklisted": true, "library_linked": true}"#.utf8))
        XCTAssertEqual(ManualImportDecide.finishDetail(linked), "release blocklisted · download kept because your library still links into it")
        XCTAssertEqual(ManualImportDecide.finishDetail(FinishRescueResult(mode: "finished", blocklisted: true, libraryLinked: false)),
                       "release blocklisted · download finished, nothing deleted")
        XCTAssertEqual(ManualImportDecide.finishDetail(FinishRescueResult(mode: "removed", blocklisted: true, libraryLinked: false)),
                       "download removed · release blocklisted")
        XCTAssertEqual(ManualImportDecide.finishDetail(FinishRescueResult(mode: "finished", blocklisted: false, libraryLinked: true)),
                       "download finished · nothing deleted, your library links into it")
    }

    func testKeepTailWordsTheRealDisposition() {
        XCTAssertEqual(ManualImportDecide.keepTail(.remove, linked: false, finishesNow: true), "the download is removed when you finish")
        XCTAssertEqual(ManualImportDecide.keepTail(.leave, linked: false, finishesNow: true), "the download is left in the client")
        XCTAssertEqual(ManualImportDecide.keepTail(.removeBlocklist, linked: false, finishesNow: false),
                       "the download is removed and blocklisted when every row is decided")
        XCTAssertEqual(ManualImportDecide.keepTail(.remove, linked: true, finishesNow: true),
                       "the download is cleared from the queue when you finish; nothing is deleted")
    }
}
