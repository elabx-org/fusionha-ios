import XCTest
@testable import FusionhaKit

/// The verdict filters, title blocks and batch decisions (`filters.ts`, `group-rows.ts`, `selection.ts`).
final class ManualImportSelectionTests: XCTestCase {
    /// The fixture's first row, once per entry of `extras`, each merged into its JSON.
    private func rows(_ extras: [[String: Any]]) throws -> [ManualImportRow] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        var scan = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let base = try XCTUnwrap((scan["rows"] as? [[String: Any]])?.first)
        scan["rows"] = extras.enumerated().map { i, extra in
            var r = base
            r["row_id"] = i + 1
            r.merge(extra) { _, new in new }
            return r
        }
        let data = try JSONSerialization.data(withJSONObject: scan)
        return try APIClient.decoder.decode(ManualImportScan.self, from: data).rows
    }

    private let noMatch: [String: Any] = ["status": "no_match", "match": ["item_id": NSNull(), "confidence": "none"]]
    private let medium: [String: Any] = [
        "status": "ready", "name_vs_file": [],
        "match": ["item_id": 9, "title": "Dark", "year": 2017, "confidence": "medium",
                  "alternative": ["item_id": 4, "title": "Dark Matter", "year": 2015, "kind": "series", "reason": "also_matches"]],
    ]

    func testFilterCounts() throws {
        let r = try rows([[:], noMatch, medium, ["committed": true, "status": "ready", "name_vs_file": []]])
        let c = ManualImportFilter.counts(r)
        XCTAssertEqual(c[.all], 4)
        XCTAssertEqual(c[.ready], 2)
        XCTAssertEqual(c[.attention], 1)
        XCTAssertEqual(c[.nomatch], 1)
        XCTAssertEqual(c[.diff], 2, "fixture row and the no-match copy keep their name-vs-file list")
        XCTAssertEqual(c[.medium], 1)
    }

    func testBlocksGroupAndUnmatchedLast() throws {
        let blocks = ManualImportBlock.group(try rows([noMatch, [:], medium, ["target": ["kind": "series", "tier": "HD-1080p", "season": 2]]]))
        XCTAssertEqual(blocks.map(\.key), ["7", "9", "none"])
        XCTAssertEqual(blocks[0].rows.count, 2)
        XCTAssertEqual(blocks[0].meta, "2024 · Series · 2 files · HD + 4K")
        XCTAssertFalse(blocks[0].needsConfirm)
        XCTAssertTrue(blocks[1].needsConfirm)
        XCTAssertEqual(blocks[1].alternativeLine, "Also matches Dark Matter (2015) · Series")
        XCTAssertEqual(blocks[2].title, "Unmatched")
        XCTAssertEqual(blocks[2].meta, "1 file")
    }

    func testCheckStateAndToggle() throws {
        let r = try rows([[:], [:], ["committed": true]])
        XCTAssertEqual(ManualImportBatch.checkState(r, selected: []), .off)
        XCTAssertEqual(ManualImportBatch.checkState(r, selected: [1]), .mixed)
        XCTAssertEqual(ManualImportBatch.checkState(r, selected: [1, 2]), .on)
        XCTAssertEqual(ManualImportBatch.toggleBlock(r, selected: [1]), [1, 2])
        XCTAssertEqual(ManualImportBatch.toggleBlock(r, selected: [1, 2]), [])
        XCTAssertEqual(ManualImportBatch.checkState(try rows([["committed": true]]), selected: []), .none)
    }

    func testNotAnUpgradeNeedsAFolderRowWithAFileId() throws {
        let folder: [String: Any] = ["held": NSNull()]
        let r = try rows([folder, [:], folder.merging(["replace_choice": "keep_current"]) { $1 }])
        XCTAssertTrue(ManualImportBatch.replaceEligible(r[0]))
        XCTAssertFalse(ManualImportBatch.replaceEligible(r[1]), "held rows decide in the held strip")
        XCTAssertEqual(ManualImportBatch.notAnUpgrade(r, selected: [1, 2, 3]).map(\.rowId), [1])
    }

    func testShared() throws {
        let r = try rows([[:], ["quality": "WEBDL_1080P"]])
        XCTAssertEqual(ManualImportBatch.shared(Array(r.prefix(1)), { $0.target.tier }), "UHD-2160p")
        XCTAssertEqual(ManualImportBatch.shared(r, { $0.quality ?? "" }), "Mixed")
        XCTAssertNil(ManualImportBatch.shared([], { $0.target.tier }))
    }
}
