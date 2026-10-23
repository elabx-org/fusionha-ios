import XCTest
@testable import FusionhaKit

final class RecentSearchesTests: XCTestCase {
    func testKeepsTheLastFiveMostRecentFirst() {
        var recent = RecentSearches()
        for term in ["a", "b", "c", "d", "e", "f"] { recent.record(term) }
        XCTAssertEqual(recent.terms, ["f", "e", "d", "c", "b"])
    }

    func testARepeatMovesToTheFrontWithoutDuplicating() {
        var recent = RecentSearches(terms: ["dune", "ghibli", "breaking bad"])
        recent.record("  Ghibli ")
        XCTAssertEqual(recent.terms, ["Ghibli", "dune", "breaking bad"])
        recent.record("   ")
        XCTAssertEqual(recent.terms.count, 3)
        recent.remove("dune")
        XCTAssertEqual(recent.terms, ["Ghibli", "breaking bad"])
    }

    func testRoundTripsThroughUserDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "RecentSearchesTests"))
        defaults.removePersistentDomain(forName: "RecentSearchesTests")
        XCTAssertEqual(RecentSearches.load(from: defaults).terms, [])
        var recent = RecentSearches()
        recent.record("tt0903747")
        recent.record("dune")
        recent.save(to: defaults)
        XCTAssertEqual(RecentSearches.load(from: defaults).terms, ["dune", "tt0903747"])
        defaults.set(["1", "2", "3", "4", "5", "6", "7"], forKey: RecentSearches.defaultsKey)
        XCTAssertEqual(RecentSearches.load(from: defaults).terms.count, 5)
        defaults.removePersistentDomain(forName: "RecentSearchesTests")
    }
}
