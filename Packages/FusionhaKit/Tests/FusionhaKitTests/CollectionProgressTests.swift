import XCTest
@testable import FusionhaKit

final class CollectionProgressTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private func detail() throws -> CollectionDetail {
        try decoder.decode(CollectionDetail.self, from: Data(#"""
            {"collection_tmdb_id": 10, "name": "Alien Collection", "poster_url": "/p.jpg", "backdrop_url": null,
             "owned_count": 2, "present_count": 1, "total_count": 4,
             "parts": [
              {"tmdb_id": 1, "title": "Alien", "year": 1979, "poster_url": null, "owned": true, "has_file": true,
               "library_item_id": 7, "tiers": ["HD-1080p", "UHD-2160p"], "ignored": false},
              {"tmdb_id": 2, "title": "Aliens", "year": 1986, "owned": true, "has_file": false, "library_item_id": 8, "tiers": []},
              {"tmdb_id": 3, "title": "Alien 3", "year": 1992, "owned": false, "tiers": []},
              {"tmdb_id": 4, "title": "Resurrection", "year": null, "owned": false}
             ]}
            """#.utf8))
    }

    func testDecodesThreeStateParts() throws {
        let d = try detail()
        XCTAssertEqual(d.parts.map(CollectionPartState.init), [.present, .tracked, .missing, .missing])
        XCTAssertEqual(d.parts[0].tiers, [.hd, .uhd])
        XCTAssertEqual(d.parts[0].inLibrary, true)
        XCTAssertEqual(d.posterUrl, "/p.jpg")
    }

    func testCountsAndLink() throws {
        let p = CollectionProgress(try detail())
        XCTAssertEqual(p.present, 1)
        XCTAssertEqual(p.tracked, 1)
        XCTAssertEqual(p.missing, 2)
        XCTAssertEqual(p.railLink, "1 of 4 ›")
    }

    func testRailLabel() throws {
        XCTAssertEqual(CollectionProgress.railLabel(try detail().parts),
                       "1 of 4 present, 1 tracked with no file yet, 2 missing")
    }

    func testAddIds() throws {
        let d = try detail()
        XCTAssertEqual(CollectionProgress.addIds(for: d.parts[2], in: d), [3])
        XCTAssertEqual(CollectionProgress.addIds(for: d.parts[0], in: d), [3, 4])
        XCTAssertEqual(CollectionProgress.ownedLibraryIds(d), [7, 8])
    }

    func testPresentFallsBackToParts() {
        let d = CollectionDetail(collectionTmdbId: 1, name: "X", ownedCount: 1, totalCount: 2,
                                 parts: [CollectionPart(tmdbId: 1, owned: true, hasFile: true), CollectionPart(tmdbId: 2)])
        XCTAssertEqual(CollectionProgress(d).present, 1)
        XCTAssertEqual(CollectionProgress(d).tracked, 0)
    }
}
