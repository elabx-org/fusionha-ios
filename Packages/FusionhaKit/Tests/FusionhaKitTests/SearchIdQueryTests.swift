import XCTest
@testable import FusionhaKit

final class SearchIdQueryTests: XCTestCase {
    func testImdbIds() {
        XCTAssertEqual(SearchIdQuery.parse("tt15239678"), SearchIdQuery(id: "tt15239678", kinds: [.movie, .series]))
        XCTAssertEqual(SearchIdQuery.parse(" TT0903747 ")?.id, "tt0903747")
        XCTAssertEqual(SearchIdQuery.parse("imdb:tt0903747")?.id, "tt0903747")
        XCTAssertEqual(SearchIdQuery.parse("https://www.imdb.com/title/tt0903747/?ref_=nv"),
                       SearchIdQuery(id: "tt0903747", kinds: [.movie, .series]))
    }

    func testTvdbIds() {
        XCTAssertEqual(SearchIdQuery.parse("tvdb:81189"), SearchIdQuery(id: "tvdb:81189", kinds: [.series]))
        XCTAssertEqual(SearchIdQuery.parse("tvdb-81189")?.id, "tvdb:81189")
        XCTAssertEqual(SearchIdQuery.parse("https://thetvdb.com/?tab=series&id=81189")?.id, "tvdb:81189")
        XCTAssertEqual(SearchIdQuery.parse("https://thetvdb.com/dereferrer/series/81189")?.id, "tvdb:81189")
        XCTAssertNil(SearchIdQuery.parse("https://thetvdb.com/series/breaking-bad"))
        XCTAssertNil(SearchIdQuery.parse("tvdb:abc"))
    }

    func testTmdbIds() {
        XCTAssertEqual(SearchIdQuery.parse("tmdb:693134"), SearchIdQuery(id: "tmdb:693134", kinds: [.movie, .series]))
        XCTAssertEqual(SearchIdQuery.parse("https://www.themoviedb.org/movie/693134-dune-part-two"),
                       SearchIdQuery(id: "tmdb:693134", kinds: [.movie]))
        XCTAssertEqual(SearchIdQuery.parse("themoviedb.org/tv/1399-game-of-thrones"),
                       SearchIdQuery(id: "tmdb:1399", kinds: [.series]))
    }

    func testTitlesAreNotIds() {
        XCTAssertNil(SearchIdQuery.parse("dune"))
        XCTAssertNil(SearchIdQuery.parse("1917"))
        XCTAssertNil(SearchIdQuery.parse("tt"))
        XCTAssertNil(SearchIdQuery.parse("ttl"))
        XCTAssertNil(SearchIdQuery.parse("the office"))
        XCTAssertNil(SearchIdQuery.parse(""))
    }
}
