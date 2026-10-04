import XCTest
@testable import FusionhaKit

final class DiscoverModelTests: XCTestCase {
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

    func testMeSplitsPermissionsAndCapabilities() throws {
        let me = try decoder.decode(Me.self, from: Data(#"""
            {"id": 5, "username": "sam", "is_admin": false, "role_name": "Manager",
             "permissions": ["requests.approve"], "capabilities": ["add", "request"],
             "request_scoped": false, "thumb": null, "plex_username": null}
            """#.utf8))
        XCTAssertTrue(me.hasPermission("requests.approve"))
        XCTAssertFalse(me.hasPermission("issues.manage"))
        XCTAssertTrue(me.hasCapability("add"))
        XCTAssertFalse(me.hasCapability("requests.approve"))
        // `can` keeps working for capabilities and now sees permissions too.
        XCTAssertTrue(me.can("add"))
        XCTAssertTrue(me.can("requests.approve"))
        XCTAssertFalse(me.can("issues.manage"))
    }

    func testPreviewDecodes() throws {
        let preview = try decoder.decode(MediaPreviewDetail.self, from: Data(#"""
            {"tmdb_id": 1399, "title": "Game of Thrones", "year": 2011, "kind": "series", "is_anime": false,
             "in_library": false, "library_item_id": null, "tvdb_id": 121361, "imdb_id": "tt0944947",
             "poster_url": null, "backdrop_url": null, "overview": "Seven noble families…", "runtime": 60,
             "status": "Ended", "tagline": "Winter is coming", "vote_average": 8.4, "vote_count": 21000,
             "certification": "TV-MA", "genres": ["Drama"],
             "cast": [{"name": "Emilia Clarke", "character": "Daenerys", "profile_url": null, "order": 0}],
             "studios": [{"name": "HBO", "logo_url": null}], "trailer_key": "abc",
             "similar": [{"tmdb_id": 1, "title": "X", "year": 2000, "poster_url": null, "kind": "series", "in_library": true}],
             "seasons": [{"season_number": 1, "episode_count": 10}]}
            """#.utf8))
        XCTAssertEqual(preview.seasons?.first?.episodeCount, 10)
        XCTAssertEqual(preview.cast?.first?.character, "Daenerys")
        XCTAssertEqual(preview.asSearchResult.previewKind, .series)
    }

    func testRequestDecodesNewFieldsAndPriority() throws {
        let requests = try decoder.decode([MediaRequest].self, from: Data(#"""
            [{"id": 1, "user_id": 3, "tmdb_id": 603, "kind": "movie", "media_item_id": null, "tier": "HD-1080p",
              "editions": ["HD-1080p", "UHD-2160p"], "seasons": [], "episodes": [{"season": 1, "episode": 2}],
              "status": "pending", "reason": null, "note": "pls", "requested_at": "2026-10-01T10:00:00"}]
            """#.utf8))
        XCTAssertEqual(requests.first?.tiers, [.hd, .uhd])
        XCTAssertEqual(requests.first?.userId, 3)
        XCTAssertGreaterThan(MediaRequest.priority("pending"), MediaRequest.priority("approved"))
    }

    func testRequestBodiesEncodeLikeTheWeb() throws {
        let reject = String(decoding: try encoder.encode(RejectBody(reason: .notAvailableYet, defer: true, note: nil)), as: UTF8.self)
        XCTAssertEqual(reject, #"{"defer":true,"reason":"not_available_yet"}"#)
        let create = String(decoding: try encoder.encode(RequestCreateBody(
            tmdbId: 1, kind: .series, editions: [.hd], seasons: [1], episodes: [EpisodeRef(season: 2, episode: 3)])), as: UTF8.self)
        XCTAssertEqual(create, #"{"editions":["HD-1080p"],"episodes":[{"episode":3,"season":2}],"kind":"series","seasons":[1],"tmdb_id":1}"#)
    }

    func testTrailerYearFallsBackToDate() throws {
        let trailer = try decoder.decode(TrailerResult.self, from: Data(#"""
            {"tmdb_id": 9, "title": "T", "year": null, "kind": "movie", "is_anime": false, "overview": null,
             "in_library": false, "date": "2027-05-01", "trailer_key": "k"}
            """#.utf8))
        XCTAssertEqual(trailer.displayYear, 2027)
    }
}
