import XCTest
@testable import FusionhaKit

/// `studios` on the item detail (StudioRead) and the v2 network mark pick.
final class StudioMarkTests: XCTestCase {
    private func decode(_ json: String) throws -> ItemDetail {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(json.utf8))
    }

    func testDecodesStudiosAndPicksTheFirstWithALogo() throws {
        let detail = try decode("""
        {"id": 7, "title": "Andor", "kind": "series", "studios": [
          {"name": "Lucasfilm", "logo_url": null},
          {"name": "Disney+", "logo_url": "https://image.tmdb.org/t/p/original/disney.png"},
          {"name": "Other", "logo_url": "https://image.tmdb.org/t/p/original/other.png"}
        ]}
        """)
        XCTAssertEqual(detail.studios?.count, 3)
        XCTAssertNil(detail.studios?.first?.logoUrl)
        XCTAssertEqual(detail.networkMark?.name, "Disney+")
        XCTAssertEqual(detail.networkMark?.logoUrl, "https://image.tmdb.org/t/p/original/disney.png")
    }

    func testOlderServerWithoutStudiosStillDecodes() throws {
        let detail = try decode(#"{"id": 1, "title": "Heat", "kind": "movie"}"#)
        XCTAssertNil(detail.studios)
        XCTAssertNil(detail.networkMark)
    }

    func testNoMarkWithoutALogo() {
        XCTAssertNil(Studio.mark(in: []))
        XCTAssertNil(Studio.mark(in: [Studio(name: "A", logoUrl: nil), Studio(name: "B", logoUrl: " ")]))
    }

    // MARK: 0.4.238: the Library row's network, the episode's still

    private func row(_ json: String) throws -> MediaItem {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(MediaItem.self, from: Data(json.utf8))
    }

    func testLibraryRowCarriesItsNetworkMark() throws {
        let item = try row("""
        {"id": 3, "title": "Andor", "kind": "series", "editions": [],
         "network_name": "Disney+", "network_logo_url": "https://image.tmdb.org/t/p/original/disney.png"}
        """)
        XCTAssertEqual(item.networkMark?.name, "Disney+")
        XCTAssertEqual(item.networkMark?.logoUrl, "https://image.tmdb.org/t/p/original/disney.png")
        let bare = try row(#"{"id": 4, "title": "Heat", "kind": "movie", "editions": []}"#)
        XCTAssertNil(bare.networkName)
        XCTAssertNil(bare.networkMark)
    }

    func testEpisodeStillDecodes() throws {
        let detail = try decode("""
        {"id": 7, "title": "Andor", "kind": "series", "seasons": [{"season_number": 1, "episodes": [
          {"id": 11, "episode_number": 1, "still_url": "https://image.tmdb.org/t/p/w300/e1.jpg"},
          {"id": 12, "episode_number": 2, "still_url": null}
        ]}]}
        """)
        let episodes = detail.seasons?.first?.episodes
        XCTAssertEqual(episodes?.first?.stillUrl, "https://image.tmdb.org/t/p/w300/e1.jpg")
        XCTAssertNil(episodes?.last?.stillUrl)
    }

    func testEpisodeFromAnOlderServerWithoutStillsDecodes() throws {
        let detail = try decode("""
        {"id": 7, "title": "Andor", "kind": "series", "seasons": [{"season_number": 1, "episodes": [
          {"id": 11, "episode_number": 1, "title": "Kassa", "air_date": "2022-09-21", "monitored": true, "files": []}
        ]}]}
        """)
        let episode = try XCTUnwrap(detail.seasons?.first?.episodes.first)
        XCTAssertEqual(episode.title, "Kassa")
        XCTAssertNil(episode.stillUrl)
    }
}
