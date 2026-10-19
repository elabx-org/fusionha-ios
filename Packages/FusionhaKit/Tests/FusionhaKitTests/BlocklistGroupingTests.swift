import XCTest
@testable import FusionhaKit

final class BlocklistGroupingTests: XCTestCase {
    private func entry(_ id: Int, item: Int = 1, title: String = "Dune", release: String, reason: String?) throws -> BlocklistEntry {
        var json = #"{"id": \#(id), "title": "x", "created_at": "2026-07-01T00:00:00Z", "media_item_id": \#(item), "#
        json += #""item_title": "\#(title)", "source_title": "\#(release)""#
        if let reason { json += #", "reason": "\#(reason)""# }
        json += "}"
        return try APIClient.decoder.decode(BlocklistEntry.self, from: Data(json.utf8))
    }

    func testCollapsesTitleReleaseReason() throws {
        let groups = BlocklistGrouping.releases([
            try entry(1, release: "Dune.BAD", reason: "download failed"),
            try entry(2, release: "Dune.BAD", reason: "download failed"),
            try entry(3, release: "Dune.OTHER", reason: "download failed"),
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].ids, [1, 2])
        XCTAssertEqual(groups[1].count, 1)
    }

    func testDifferentReasonsStaySeparate() throws {
        let groups = BlocklistGrouping.releases([
            try entry(1, release: "Dune.BAD", reason: "dead articles"),
            try entry(2, release: "Dune.BAD", reason: "manual"),
        ])
        XCTAssertEqual(groups.count, 2)
    }

    func testTitlesKeepOrder() throws {
        let titles = BlocklistGrouping.titles([
            try entry(1, item: 5, title: "B", release: "b1", reason: nil),
            try entry(2, item: 4, title: "A", release: "a1", reason: nil),
            try entry(3, item: 5, title: "B", release: "b2", reason: nil),
        ])
        XCTAssertEqual(titles.map { $0.entries.map(\.id) }, [[1, 3], [2]])
        XCTAssertEqual(titles[0].releases.count, 2)
    }

    func testPrunesHiddenSelection() throws {
        let visible = [try entry(1, release: "a", reason: nil)]
        XCTAssertEqual(BlocklistGrouping.pruned([1, 2], visible: visible), [1])
    }
}
