import XCTest
@testable import FusionhaKit

final class LibraryPhoneLogicTests: XCTestCase {
    private func item(_ json: String) throws -> MediaItem {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(MediaItem.self, from: Data(json.utf8))
    }

    private func titled(_ id: Int, _ title: String, size: Double) throws -> MediaItem {
        try item(#"{"id": \#(id), "title": "\#(title)", "kind": "movie", "editions": [{"id": \#(id), "tier": "HD-1080p", "monitored": true, "status": "done", "size": \#(size)}]}"#)
    }

    func testPosterBadges() throws {
        let busy = try item(#"""
            {"id": 1, "title": "A", "kind": "movie", "has_attention": true, "editions": [
              {"id": 1, "tier": "HD-1080p", "monitored": false, "status": "upgrading", "attention": true,
               "dead_link_count": 2, "unresolved_file_count": 2},
              {"id": 2, "tier": "UHD-2160p", "monitored": true, "status": "grabbing"}]}
            """#)
        let b = PosterBadges(busy)
        XCTAssertTrue(b.has4k)
        XCTAssertTrue(b.monitored)
        XCTAssertEqual(b.attention, .deadLink)
        XCTAssertEqual(b.live, .downloading)

        let calm = try item(#"""
            {"id": 2, "title": "B", "kind": "movie", "has_attention": true, "editions": [
              {"id": 3, "tier": "HD-1080p", "monitored": false, "status": "upgrading", "attention": true,
               "dead_link_count": 1, "unresolved_file_count": 3}]}
            """#)
        let c = PosterBadges(calm)
        XCTAssertFalse(c.has4k)
        XCTAssertFalse(c.monitored)
        XCTAssertEqual(c.attention, .notFound)
        XCTAssertEqual(c.live, .upgrading)
    }

    func testCompactSort() throws {
        let items = [try titled(1, "Beta", size: 10), try titled(2, "alpha", size: 30), try titled(3, "Gamma", size: 10)]
        var sort = CompactSort()
        XCTAssertEqual(sort.sorted(items).map(\.id), [2, 1, 3])
        sort = sort.tapped(.title)
        XCTAssertEqual(sort.sorted(items).map(\.id), [3, 1, 2])
        sort = sort.tapped(.size)
        XCTAssertFalse(sort.ascending)
        XCTAssertEqual(sort.sorted(items).map(\.id), [2, 1, 3])
        sort = sort.tapped(.size)
        // Ascending size keeps the title tie-break ascending.
        XCTAssertEqual(sort.sorted(items).map(\.id), [1, 3, 2])
    }

    func testCopy() {
        XCTAssertEqual(LibraryPhoneCopy.kindSubtitle(allKinds: true, kindsPresent: 1, versions: 9), "1 kind")
        XCTAssertEqual(LibraryPhoneCopy.kindSubtitle(allKinds: false, kindsPresent: 3, versions: 2), "2 versions")
        XCTAssertTrue(LibraryPhoneCopy.noMatches(filtersActive: true).hasPrefix("No titles match these filters."))
        XCTAssertTrue(LibraryPhoneCopy.noMatches(filtersActive: false).hasPrefix("No titles match your search."))
    }

    func testConnectionLine() {
        XCTAssertEqual(ConnectionLine(loading: true, failed: false, status: nil), .connecting)
        XCTAssertEqual(ConnectionLine(loading: false, failed: true, status: "ok"), .offline)
        XCTAssertEqual(ConnectionLine(loading: false, failed: false, status: "ok").label, "All systems connected")
        XCTAssertEqual(ConnectionLine(loading: false, failed: false, status: "degraded"), .unknown)
    }
}
