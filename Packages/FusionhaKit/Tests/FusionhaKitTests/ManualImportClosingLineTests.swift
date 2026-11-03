import XCTest
@testable import FusionhaKit

/// The auto-close toast's line (owner-approved item 5), over the mock's The
/// Office S06 pack and a one-file movie made from its first row.
final class ManualImportClosingLineTests: XCTestCase {
    private func rows(_ edit: (inout [[String: Any]]) -> Void = { _ in }) throws -> [ManualImportRow] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-decide", withExtension: "json", subdirectory: "Fixtures"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var scan = try XCTUnwrap(root["scan"] as? [String: Any])
        var rows = try XCTUnwrap(scan["rows"] as? [[String: Any]])
        edit(&rows)
        scan["rows"] = rows
        return try APIClient.decoder.decode(ManualImportScan.self, from: JSONSerialization.data(withJSONObject: scan)).rows
    }

    /// The first row as a held Interstellar over a FraMeSToR copy.
    private func movie(committed: Bool = false) throws -> [ManualImportRow] {
        try rows { rows in
            var r = rows[0]
            r["target"] = ["kind": "movie", "tier": "HD-1080p", "edition": NSNull(), "version_exists": true]
            r["match"] = ["item_id": 103, "title": "Interstellar", "year": 2014, "confidence": "high"]
            var existing = r["existing_file"] as! [String: Any]
            existing["release_group"] = "FraMeSToR"
            r["existing_file"] = existing
            r["committed"] = committed
            rows = [r]
        }
    }

    private let removed = FinishRescueResult(mode: "removed", blocklisted: false, libraryLinked: false)

    func testPackCountsImportedKeptAndSkipped() throws {
        let pack = try rows()
        XCTAssertEqual(ManualImportDecide.closingLine(pack, finish: removed), "The Office S06 · kept 7 · skipped 1")
        let imported = try rows { rows in
            rows[0]["committed"] = true
            rows[1]["committed"] = true
        }
        XCTAssertEqual(ManualImportDecide.closingLine(imported, finish: nil), "The Office S06 · imported 2 · kept 5 · skipped 1")
    }

    func testOneFileReadsAsItsReceipt() throws {
        XCTAssertEqual(ManualImportDecide.closingLine(try movie(), finish: removed),
                       "Interstellar · kept your FraMeSToR copy · download removed")
        XCTAssertEqual(ManualImportDecide.closingLine(try movie(committed: true), finish: removed),
                       "Interstellar · imported · download removed")
        let left = FinishRescueResult(mode: "left", blocklisted: nil, libraryLinked: nil)
        XCTAssertEqual(ManualImportDecide.closingLine(try movie(), finish: left),
                       "Interstellar · kept your FraMeSToR copy · download left as it is")
    }

    func testOneEpisodeSkippedAndKeptWithTheHeldGroup() throws {
        let skipped = try rows { $0 = [$0[5]] }
        XCTAssertEqual(ManualImportDecide.closingLine(skipped, finish: nil), "The Office S06 · skipped this file")
        let noGroup = try rows { rows in
            var r = rows[0]
            var existing = r["existing_file"] as! [String: Any]
            existing["release_group"] = NSNull()
            r["existing_file"] = existing
            rows = [r]
        }
        XCTAssertEqual(ManualImportDecide.closingLine(noGroup, finish: nil, currentGroup: "OLD"), "The Office S06 · kept your OLD copy")
    }

    func testNameSpansSeasons() throws {
        let mixed = try rows { rows in
            var t = rows[1]["target"] as! [String: Any]
            t["season"] = 7
            rows[1]["target"] = t
        }
        XCTAssertEqual(ManualImportDecide.downloadName(mixed), "The Office")
    }
}
