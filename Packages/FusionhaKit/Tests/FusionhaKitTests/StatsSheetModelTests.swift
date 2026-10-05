import XCTest
@testable import FusionhaKit

/// The Library stats sheet's attention sources decode both API vocabularies.
final class StatsSheetModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    func testLibraryAttentionOldAndNewKeys() throws {
        let json = #"{"items": [{"item_id": 9, "title": "Dune", "tier": "UHD-2160p", "movie_edition": "IMAX", "kind": "dead_link", "count": 1, "root_path": "/m", "message": "gone"}, {"item_id": 3, "title": "Up", "tier": null, "edition": "Extended", "kind": "numbering_mismatch", "count": 1, "root_path": "/m", "message": "check"}]}"#
        let page = try decode(ItemsEnvelope<LibraryAttentionEntry>.self, json)
        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.items[0].edition, "IMAX")
        XCTAssertEqual(page.items[0].tier, .uhd)
        XCTAssertEqual(page.items[1].edition, "Extended")
        XCTAssertNil(page.items[1].tier)
    }

    func testMissingItemsIsEmpty() throws {
        XCTAssertTrue(try decode(ItemsEnvelope<RunAttentionEntry>.self, "{}").items.isEmpty)
    }

    func testIndexerRetryHint() throws {
        let ix = try decode(UnavailableIndexer.self,
                            #"{"indexer_id": 3, "name": "NZBgeek", "failure_count": 5, "disabled_till": "2026-10-04T10:18:00Z", "reason": null}"#)
        let now = try XCTUnwrap(DetailText.instant("2026-10-04T10:00:00Z"))
        XCTAssertEqual(ix.retryHint(now: now), "retry in 18m")
        XCTAssertEqual(ix.retryHint(now: now.addingTimeInterval(-7200)), "retry in 2h")
        XCTAssertEqual(ix.retryHint(now: now.addingTimeInterval(3600)), "retrying")
    }
}
