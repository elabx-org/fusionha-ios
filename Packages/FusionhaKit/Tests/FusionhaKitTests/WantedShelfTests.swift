import XCTest
@testable import FusionhaKit

/// All titles' wanted shelves: the page's titles found in the library, in
/// the server's order, by kind, and the header's count.
final class WantedShelfTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    private var library: [MediaItem] {
        get throws {
            try decode([MediaItem].self, """
            [{"id": 1, "title": "Andor", "kind": "series", "editions": []},
             {"id": 2, "title": "Heat", "kind": "movie", "editions": []},
             {"id": 3, "title": "Frieren", "kind": "series", "is_anime": true, "editions": []}]
            """)
        }
    }

    /// A 0.4.243 page: `versions` with the deprecated `editions` copy.
    private func page(_ ids: [Int], total: Int, missingTitles: Int? = nil, cutoffTitles: Int? = nil) throws -> WantedPage {
        let items = ids.map { id in
            """
            {"id": \(id), "title": "T\(id)", "kind": "series", "is_anime": false, "poster_url": null,
             "versions": [], "editions": [{"edition_id": \(id * 10), "tier": "HD-1080p", "state": "missing",
               "missing_episode_count": 2, "missing_episodes": [], "never_searched": true}]}
            """
        }.joined(separator: ",")
        var extra = ""
        if let missingTitles { extra += #", "missing_titles": \#(missingTitles), "missing_count": \#(missingTitles)"# }
        if let cutoffTitles { extra += #", "cutoff_unmet_titles": \#(cutoffTitles)"# }
        return try decode(WantedPage.self, #"{"items": [\#(items)], "total": \#(total), "page": 1, "page_size": 200\#(extra)}"#)
    }

    func testKeepsTheServersOrderAndSkipsTitlesNotInTheLibrary() throws {
        let shelf = try XCTUnwrap(WantedShelf.make(.missing, page: page([3, 9, 1], total: 3, missingTitles: 3),
                                                   library: library, kind: nil))
        XCTAssertEqual(shelf.items.map(\.id), [3, 1])
        XCTAssertEqual(shelf.count, 3, "every kind: the server's title count")
        XCTAssertEqual(shelf.title, "Missing episodes")
    }

    func testOneKindCountsItsOwnTitles() throws {
        let shelf = try XCTUnwrap(WantedShelf.make(.missing, page: page([1, 2, 3], total: 40, missingTitles: 40),
                                                   library: library, kind: .anime))
        XCTAssertEqual(shelf.items.map(\.id), [3])
        XCTAssertEqual(shelf.count, 1)
    }

    func testTitlesNameWhatTheShelfHolds() throws {
        let movies = try XCTUnwrap(WantedShelf.make(.missing, page: page([2], total: 1), library: library, kind: nil))
        XCTAssertEqual(movies.title, "Missing movies")
        let mixed = try XCTUnwrap(WantedShelf.make(.missing, page: page([1, 2], total: 2), library: library, kind: nil))
        XCTAssertEqual(mixed.title, "Missing")
        let upgrades = try XCTUnwrap(WantedShelf.make(.upgrades, page: page([2], total: 7, cutoffTitles: 7),
                                                      library: library, kind: nil))
        XCTAssertEqual(upgrades.title, "Upgrades waiting")
        XCTAssertEqual(upgrades.count, 7)
    }

    func testHidesWhenEmptyOrNotLoaded() throws {
        XCTAssertNil(WantedShelf.make(.missing, page: nil, library: try library, kind: nil))
        XCTAssertNil(WantedShelf.make(.missing, page: try page([], total: 0), library: try library, kind: nil))
        XCTAssertNil(WantedShelf.make(.missing, page: try page([1], total: 1), library: try library, kind: .movie))
    }

    func testCapsThePosters() throws {
        let shelf = try XCTUnwrap(WantedShelf.make(.missing, page: page([1, 2, 3], total: 3), library: library,
                                                   kind: nil, limit: 2))
        XCTAssertEqual(shelf.items.count, 2)
        XCTAssertEqual(shelf.count, 3)
    }

    func testStatesOnTheWire() {
        XCTAssertEqual(WantedShelf.Source.missing.state.rawValue, "missing")
        XCTAssertEqual(WantedShelf.Source.upgrades.state.rawValue, "cutoff_unmet")
    }
}
