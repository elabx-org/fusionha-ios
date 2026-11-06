import XCTest
@testable import FusionhaKit

final class SearchActivityTests: XCTestCase {
    func testBeginRunsOncePerTarget() {
        var book = SearchActivityBook()
        let first = book.begin(.episode(5))
        XCTAssertNotNil(first)
        XCTAssertNil(book.begin(.episode(5)), "a second tap must not start a duplicate")
        XCTAssertNotNil(book.begin(.episode(6)), "another episode is its own target")
        XCTAssertNotNil(book.begin(.episodeVersion(episode: 5, version: 1)))
        XCTAssertTrue(book.isSearching(.episode(5)))
    }

    func testOutcomeThenClear() throws {
        var book = SearchActivityBook()
        let token = try XCTUnwrap(book.begin(.title))
        book.clear(.title, token: token)
        XCTAssertEqual(book.activity(.title), .searching, "a running search is never cleared")
        book.finish(.title, token: token, .grabbed(2))
        XCTAssertEqual(book.activity(.title), .grabbed(2))
        XCTAssertNotNil(book.begin(.title), "an outcome does not block a new search")
    }

    func testStaleRunNeverTouchesANewerOne() throws {
        var book = SearchActivityBook()
        let old = try XCTUnwrap(book.begin(.version(3)))
        book.finish(.version(3), token: old, .nothingNew)
        let new = try XCTUnwrap(book.begin(.version(3)))
        book.clear(.version(3), token: old)
        XCTAssertEqual(book.activity(.version(3)), .searching)
        book.finish(.version(3), token: old, .failed)
        XCTAssertEqual(book.activity(.version(3)), .searching)
        book.finish(.version(3), token: new, .failed)
        book.clear(.version(3), token: new)
        XCTAssertNil(book.activity(.version(3)))
    }

    func testCoveringPlacesPreferARunningSearch() throws {
        var book = SearchActivityBook()
        let a = try XCTUnwrap(book.begin(.episode(5)))
        book.finish(.episode(5), token: a, .nothingNew)
        _ = book.begin(.episodeVersion(episode: 5, version: 2))
        XCTAssertEqual(book.activity(episode: 5), .searching)
        XCTAssertNil(book.activity(episode: 6))
        XCTAssertEqual(book.activity(any: [.season(1), .episode(5)]), .nothingNew)
        XCTAssertNil(book.activity(any: [.season(1)]))
    }

    func testOutcomeAndWords() {
        XCTAssertEqual(SearchActivity.outcome(grabbed: nil), .failed)
        XCTAssertEqual(SearchActivity.outcome(grabbed: 0), .nothingNew)
        XCTAssertEqual(SearchActivity.outcome(grabbed: 1), .grabbed(1))
        XCTAssertEqual(SearchActivity.searching.label, "Searching…")
        XCTAssertEqual(SearchActivity.grabbed(1).label, "Grabbed")
        XCTAssertEqual(SearchActivity.grabbed(2).label, "Grabbed 2")
        XCTAssertEqual(SearchActivity.nothingNew.label, "Nothing new")
        XCTAssertEqual(SearchActivity.failed.spoken, "Couldn't search")
        XCTAssertEqual(SearchTarget.episodeVersion(episode: 4, version: 1).episodeId, 4)
        XCTAssertNil(SearchTarget.season(1).episodeId)
    }
}
