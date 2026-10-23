import XCTest
@testable import FusionhaKit

final class UnifiedSearchLanesTests: XCTestCase {
    private func tmdb(_ id: Int, _ title: String, _ year: Int?, kind: String = "movie",
                      owned: Bool = false, libraryId: Int? = nil) throws -> MediaSearchResult {
        let json = """
        {"tmdb_id": \(id), "title": "\(title)", "year": \(year.map(String.init) ?? "null"), "kind": "\(kind)",
         "is_anime": false, "overview": null, "in_library": \(owned), "library_item_id": \(libraryId.map(String.init) ?? "null"),
         "poster_url": null, "backdrop_url": null, "date": null, "vote_average": 7.1}
        """
        return try APIClient.decoder.decode(MediaSearchResult.self, from: Data(json.utf8))
    }

    private func tvdb(_ id: Int, _ title: String, _ year: Int?, tmdbId: Int? = nil,
                      owned: Bool = false, libraryId: Int? = nil) throws -> TvdbSearchResult {
        let json = """
        {"tvdb_id": \(id), "title": "\(title)", "year": \(year.map(String.init) ?? "null"), "overview": null,
         "image_url": null, "tmdb_id": \(tmdbId.map(String.init) ?? "null"), "imdb_id": null,
         "in_library": \(owned), "library_item_id": \(libraryId.map(String.init) ?? "null")}
        """
        return try APIClient.decoder.decode(TvdbSearchResult.self, from: Data(json.utf8))
    }

    func testMergesTvdbIntoTmdbByIdThenByTitleAndYear() throws {
        let rows = UnifiedSearchAccumulator.merge(
            tmdb: [try tmdb(693134, "Dune: Part Two", 2024),
                   try tmdb(90228, "Dune: Prophecy", 2024, kind: "series"),
                   try tmdb(1000, "Frank Herbert's Dune", 2000, kind: "series")],
            tvdb: [try tvdb(1, "Dune: Prophecy", 2024, tmdbId: 90228),
                   try tvdb(2, "Frank Herbert’s Dune", 2000),
                   try tvdb(3, "Children of Dune", 2003)])
        XCTAssertEqual(rows.map(\.title), ["Dune: Part Two", "Dune: Prophecy", "Frank Herbert's Dune", "Children of Dune"])
        XCTAssertEqual(rows.map(\.sources), [[.tmdb], [.tmdb, .tvdb], [.tmdb, .tvdb], [.tvdb]])
        XCTAssertEqual(rows.map(\.isTvdbOnly), [false, false, false, true])
        XCTAssertEqual(rows[3].kind, .series)
    }

    func testTitleMatchNeedsTheSameYearAndNeverJoinsAMovie() throws {
        let rows = UnifiedSearchAccumulator.merge(
            tmdb: [try tmdb(1, "Dune", 2021), try tmdb(2, "Dune", 1984, kind: "series")],
            tvdb: [try tvdb(9, "Dune", 2021), try tvdb(10, "Dune", 1984)])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1].tvdb?.tvdbId, 10)
        XCTAssertEqual(rows[2].tvdb?.tvdbId, 9)
        XCTAssertTrue(rows[2].isTvdbOnly)
    }

    func testOwnedHitsLeaveTheAddLane() throws {
        var acc = UnifiedSearchAccumulator()
        acc.receive(tmdb: [try tmdb(438631, "Dune", 2021, owned: true, libraryId: 7),
                           try tmdb(5, "Breaking Bad", 2008, kind: "series", owned: true)])
        acc.receive(tvdb: [try tvdb(81189, "Breaking Bad", 2008, tmdbId: 5),
                           try tvdb(70, "Owned Show", 2010, owned: true, libraryId: 42)])
        let lanes = acc.lanes
        XCTAssertTrue(lanes.add.isEmpty)
        XCTAssertEqual(lanes.ownedTmdb.map(\.tmdbId), [438631, 5])
        XCTAssertEqual(lanes.ownedLibraryIds, [42])
        XCTAssertTrue(lanes.isSettled)
    }

    func testExactMatchIsPinnedAndLeavesTheAddLane() throws {
        var acc = UnifiedSearchAccumulator()
        acc.receive(exact: [try tmdb(693134, "Dune: Part Two", 2024)])
        acc.receive(exact: [try tmdb(693134, "Dune: Part Two", 2024)])
        XCTAssertEqual(acc.lanes.pending, [.tmdb, .tvdb])
        acc.receive(tmdb: [try tmdb(693134, "Dune: Part Two", 2024), try tmdb(3, "Dune: Part Three", 2026)])
        let lanes = acc.lanes
        XCTAssertEqual(lanes.exact.map(\.tmdbId), [693134])
        XCTAssertEqual(lanes.add.map(\.title), ["Dune: Part Three"])
        XCTAssertEqual(lanes.pending, [.tvdb])
    }

    func testUnconfiguredProviderIsSkipped() {
        var acc = UnifiedSearchAccumulator()
        acc.unavailable(.tvdb)
        acc.fail(.tmdb)
        XCTAssertTrue(acc.lanes.isSettled)
        XCTAssertEqual(acc.lanes.unconfigured, [.tvdb])
        XCTAssertEqual(acc.lanes.failed, [.tmdb])
        XCTAssertTrue(acc.lanes.answered.isEmpty)
    }

    func testSourceFilter() {
        XCTAssertTrue(UnifiedSearchSourceFilter.all.includes([.tvdb]))
        XCTAssertTrue(UnifiedSearchSourceFilter.tmdb.includes([.tmdb, .tvdb]))
        XCTAssertFalse(UnifiedSearchSourceFilter.tmdb.includes([.tvdb]))
        XCTAssertFalse(UnifiedSearchSourceFilter.tvdb.includes([.tmdb]))
    }

    func testNormalizedTitle() {
        XCTAssertEqual(UnifiedSearchAccumulator.normalizedTitle("The Office (US)"), "office us")
        XCTAssertEqual(UnifiedSearchAccumulator.normalizedTitle("Pokémon"), "pokemon")
    }
}
