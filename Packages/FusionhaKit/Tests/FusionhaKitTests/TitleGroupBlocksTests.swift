import XCTest
@testable import FusionhaKit

final class TitleGroupBlocksTests: XCTestCase {
    private func blocks(_ json: String) throws -> [ReleaseGroupBlock] {
        try APIClient.decoder.decode([ReleaseGroupBlock].self, from: Data(json.utf8))
    }

    private lazy var sample: [ReleaseGroupBlock] = try! blocks("""
    [{"id":1,"group":"YIFY","scope":"item","media_item_id":8,"reason":"manual"},
     {"id":2,"group":"MAXSPEED","scope":"global","media_item_id":null,"reason":"manual"},
     {"id":3,"group":"EVO","scope":"item","media_item_id":99,"reason":"manual"},
     {"id":4,"group":"FAKEHD","scope":"item","media_item_id":8,"reason":"mislabeled_resolution"}]
    """)

    func testScopeMapping() {
        XCTAssertEqual(TitleGroupBlocks.scope(mediaItemId: nil), "global")
        XCTAssertEqual(TitleGroupBlocks.scope(mediaItemId: 8), "item")
        XCTAssertNil(TitleGroupBlocks.mediaItemId(everywhere: true, itemId: 8))
        XCTAssertEqual(TitleGroupBlocks.mediaItemId(everywhere: false, itemId: 8), 8)
    }

    func testKeyMatchesTheServer() {
        XCTAssertEqual(TitleGroupBlocks.key("  [NTb] "), "ntb")
        XCTAssertEqual(TitleGroupBlocks.key("ＴＳＲＧ"), "tsrg")
        XCTAssertEqual(TitleGroupBlocks.key("Ta\u{200B}rget"), "target")
        XCTAssertEqual(TitleGroupBlocks.key("Straße"), "strasse")
        XCTAssertNil(TitleGroupBlocks.key("--"))
        XCTAssertNil(TitleGroupBlocks.key(nil))
        XCTAssertEqual(TitleGroupBlocks.display("  -FLUX. "), "FLUX")
        XCTAssertNil(TitleGroupBlocks.display(" . "))
    }

    func testApplyingKeepsThisTitleThenEverywhere() {
        let ids = TitleGroupBlocks.applying(sample, itemId: 8).map(\.id)
        XCTAssertEqual(ids, [1, 4, 2])
        XCTAssertEqual(TitleGroupBlocks.scopeLabel(sample[0]), "This title")
        XCTAssertEqual(TitleGroupBlocks.scopeLabel(sample[1]), "Everywhere")
    }

    func testBlockForGroupIgnoresOtherTitles() {
        XCTAssertEqual(TitleGroupBlocks.block(for: "yify", in: sample, itemId: 8)?.id, 1)
        XCTAssertEqual(TitleGroupBlocks.block(for: "MaxSpeed", in: sample, itemId: 8)?.id, 2)
        XCTAssertNil(TitleGroupBlocks.block(for: "EVO", in: sample, itemId: 8))
        XCTAssertEqual(TitleGroupBlocks.block(for: "EVO", in: sample, itemId: 99)?.id, 3)
        XCTAssertNil(TitleGroupBlocks.block(for: nil, in: sample, itemId: 8))
    }

    func testSuggestionsDedupeRankAndSkipBlocked() {
        let seen: [String?] = ["NTb", "FLUX", "ntb", nil, "YIFY", "[FLUX]", "NTB", "", "EVO", "SiGMA"]
        let out = TitleGroupBlocks.suggestions(seen: seen, blocks: sample, itemId: 8)
        // YIFY is blocked here; EVO only on another title, so it stays.
        XCTAssertEqual(out, ["NTb", "FLUX", "EVO", "SiGMA"])
        XCTAssertEqual(TitleGroupBlocks.suggestions(seen: seen, blocks: sample, itemId: 8, typed: "fl"), ["FLUX"])
        XCTAssertEqual(TitleGroupBlocks.suggestions(seen: seen, blocks: [], itemId: 8, limit: 2), ["NTb", "FLUX"])
    }

    func testGroupBlockReasonAndMerge() throws {
        XCTAssertTrue(TitleGroupBlocks.isGroupBlockReason("Release group YIFY is blocked for this title"))
        XCTAssertTrue(TitleGroupBlocks.isGroupBlockReason("Release group EVO is blocked everywhere"))
        XCTAssertFalse(TitleGroupBlocks.isGroupBlockReason("DVD is not wanted in the quality profile"))
        let again = try blocks(#"[{"id":2,"group":"MAXSPEED","scope":"global","note":"bad audio"}]"#)[0]
        let merged = TitleGroupBlocks.merged(sample, adding: again)
        XCTAssertEqual(merged.map(\.id), [2, 1, 3, 4])
        XCTAssertEqual(merged.first?.note, "bad audio")
    }
}
