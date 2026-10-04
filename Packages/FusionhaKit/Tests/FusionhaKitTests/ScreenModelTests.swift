import XCTest
@testable import FusionhaKit

/// Decodes real responses captured from a fusionha demo server.
final class ScreenModelTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testDemoLibraryRails() throws {
        let items: [MediaItem] = try decoder.decode([MediaItem].self, from: fixture("library_demo"))
        XCTAssertEqual(items.count, 14)
        let byTitle = Dictionary(uniqueKeysWithValues: items.map { ($0.title, $0) })

        let bladeRunner = try XCTUnwrap(byTitle["Blade Runner"])
        XCTAssertEqual(bladeRunner.editions.map { $0.rail(isSeries: false).state }, [.owned, .owned])

        let breakingBad = try XCTUnwrap(byTitle["Breaking Bad"])
        let rail = breakingBad.editions[0].rail(isSeries: true)
        XCTAssertEqual(rail.state, .downloading)
        XCTAssertEqual(rail.fraction, "4/6")

        let aot = try XCTUnwrap(byTitle["Attack on Titan"])
        XCTAssertEqual(aot.kindBucket, .anime)
        XCTAssertEqual(aot.editions[0].rail(isSeries: true).state, .partial)
    }

    func testItemDetailDecodes() throws {
        let item = try decoder.decode(ItemDetail.self, from: fixture("item_detail"))
        XCTAssertEqual(item.title, "Breaking Bad")
        XCTAssertEqual(item.genres, ["Drama", "Crime"])
        XCTAssertEqual(item.seasons?.count, 2)
        XCTAssertEqual(item.editions.first?.tier, .hd)
        XCTAssertFalse(item.history?.isEmpty ?? true)
    }

    func testWantedHistoryMeCalendarDecode() throws {
        let wanted = try decoder.decode(WantedPage.self, from: fixture("wanted"))
        XCTAssertEqual(wanted.missingTitles, 6)
        XCTAssertEqual(wanted.items.first?.editions.first?.missingEpisodes?.first?.code, "S02E02")

        let history = try decoder.decode(HistoryPage.self, from: fixture("history"))
        XCTAssertEqual(history.items.count, 4)
        XCTAssertEqual(history.items.first?.eventLabel, "Download Failed")

        let me = try decoder.decode(Me.self, from: fixture("me"))
        XCTAssertEqual(me.initials, "AD")
        XCTAssertEqual(me.roleLabel, "Administrator")
        XCTAssertEqual(me.requestScoped, false)

        let calendar = try decoder.decode([CalendarEntry].self, from: fixture("calendar"))
        XCTAssertFalse(calendar.isEmpty)
    }

    func testSearchResultDecodes() throws {
        let results = try decoder.decode([MediaSearchResult].self, from: Data(#"""
            [{"tmdb_id": 603, "title": "The Matrix", "year": 1999, "kind": "movie", "is_anime": false,
              "overview": null, "in_library": true, "library_item_id": 1,
              "poster_url": "https://image.tmdb.org/t/p/w500/x.jpg", "backdrop_url": null,
              "date": "1999-03-30", "vote_average": 8.2}]
            """#.utf8))
        XCTAssertEqual(results.first?.id, "movie-603")
        XCTAssertEqual(results.first?.inLibrary, true)
    }
}
