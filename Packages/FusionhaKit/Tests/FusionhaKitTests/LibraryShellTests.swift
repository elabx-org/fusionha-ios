import XCTest
@testable import FusionhaKit

final class LibraryShellTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.outputFormatting = .sortedKeys
        return e
    }

    private func item(_ json: String) throws -> MediaItem {
        try decoder.decode(MediaItem.self, from: Data(json.utf8))
    }

    func testUpcomingItemAndCardStatus() throws {
        let upcoming = try item(#"""
            {"id": 1, "title": "Future Film", "kind": "movie", "year": 2027, "is_anime": false,
             "is_animation": false, "is_available": false, "next_release": "2027-05-01", "monitored": true,
             "editions": [{"id": 1, "tier": "HD-1080p", "monitored": true, "status": "wanted", "have": 0, "total": 1,
                           "available_from": null, "available_stage": null, "available_estimated": false}]}
            """#)
        XCTAssertTrue(upcoming.isUpcoming)
        XCTAssertEqual(upcoming.cardStatus, .upcoming)
        XCTAssertEqual(upcoming.rails.first?.state, .upcoming)
        XCTAssertEqual(upcoming.rails.first?.upcomingDate, "2027-05-01")

        let cued = try item(#"""
            {"id": 2, "title": "Cue", "kind": "series", "is_available": true, "editions": [
              {"id": 3, "tier": "UHD-2160p", "monitored": true, "status": "wanted", "have": 0, "total": 8,
               "available_from": "2026-12-01", "available_stage": "digital", "available_estimated": true}]}
            """#)
        let rail = try XCTUnwrap(cued.rails.first)
        XCTAssertEqual(rail.state, .upcoming)
        XCTAssertEqual(rail.upcomingStage, "digital")
        XCTAssertTrue(rail.upcomingEstimated)
        XCTAssertEqual(cued.cardStatus, .missing)
    }

    func testKindBucketsAreExclusive() throws {
        let animation = try item(#"{"id": 3, "title": "Toy", "kind": "movie", "is_anime": false, "is_animation": true, "editions": []}"#)
        XCTAssertEqual(animation.libraryKind, .animation)
        let anime = try item(#"{"id": 4, "title": "AoT", "kind": "series", "is_anime": true, "is_animation": true, "editions": []}"#)
        XCTAssertEqual(anime.libraryKind, .anime)
    }

    func testBulkBodiesUseSnakeCase() throws {
        let monitor = String(decoding: try encoder.encode(BulkMonitorRequest(itemIds: [1], monitored: false)), as: UTF8.self)
        XCTAssertEqual(monitor, #"{"edition_ids":[],"item_ids":[1],"monitored":false}"#)
        let root = String(decoding: try encoder.encode(
            BulkRootFolderRequest(itemIds: [2], tier: "all", rootFolderId: 5, disposition: .move)), as: UTF8.self)
        XCTAssertEqual(root, #"{"disposition":"move","item_ids":[2],"root_folder_id":5,"tier":"all"}"#)
        let avail = String(decoding: try encoder.encode(
            BulkMinimumAvailabilityRequest(itemIds: [1], minimumAvailability: .inCinemas)), as: UTF8.self)
        XCTAssertEqual(avail, #"{"item_ids":[1],"minimum_availability":"inCinemas"}"#)
    }

    func testAddBodyOmitsNilFields() throws {
        let body = LibraryAddBody(
            title: "Dune", kind: .movie, year: 2021, tmdbId: 438631, tvdbId: nil, isAnime: false,
            editions: [EditionAddBody(tier: .hd, rootFolderId: 1, qualityProfileId: 2, monitor: nil, folderName: nil)],
            searchNow: true, monitor: "all", minimumAvailability: "released", seriesType: nil, metadataProvider: nil)
        let json = String(decoding: try encoder.encode(body), as: UTF8.self)
        XCTAssertFalse(json.contains("tvdb_id"))
        XCTAssertFalse(json.contains("folder_name"))
        XCTAssertTrue(json.contains(#""minimum_availability":"released""#))
        XCTAssertTrue(json.contains(#""search_now":true"#))
    }

    func testShellDecodes() throws {
        let attention = try decoder.decode(AttentionItems.self, from: Data(#"{"titles": 2, "items": [{"a": 1}, {"b": [2]}]}"#.utf8))
        XCTAssertEqual(attention.count, 2)
        let tvdb = try decoder.decode([TvdbSearchResult].self, from: Data(#"""
            [{"tvdb_id": 81189, "title": "Breaking Bad", "year": 2008, "overview": "x", "image_url": null,
              "tmdb_id": 1396, "imdb_id": null, "in_library": true, "library_item_id": 8}]
            """#.utf8))
        XCTAssertEqual(tvdb.first?.id, 81189)
        let check = try decoder.decode(FourKAvailability.self, from: Data(#"""
            {"dispatched": true, "queried_indexers": 3, "found_uhd": true, "seasons_seen": [1, 2],
             "best_release_name": "X.2160p", "format_tags": [{"label": "DV", "kind": "hdr"}], "message": "ok"}
            """#.utf8))
        XCTAssertEqual(check.queriedIndexers, 3)
        let status = try decoder.decode(SetupStatus.self, from: Data(#"{"needs_setup": false, "demo_mode": true, "demo_require_credentials": false}"#.utf8))
        XCTAssertEqual(status.demoMode, true)
        XCTAssertEqual(status.demoRequireCredentials, false)
    }
}
