import XCTest
@testable import FusionhaKit

/// fusionha's golden fixtures for automatic request sources (0.4.209 Plex
/// watchlist & lists, 0.4.213 Letterboxd), copied from `docs/fixtures/` into
/// `Fixtures/golden/`: requests with a source, the counts' `by_source[]`, the
/// admin status reads and summaries, the stats and the FlareSolverr test.
final class GoldenSourceFixtureTests: XCTestCase {
    private func load(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"))
        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: load(name))
    }

    func testPlexListRequestReadsItsSource() throws {
        let r = try decode(MediaRequest.self, "request_from_plex_list")
        let source = try XCTUnwrap(r.source)
        XCTAssertEqual(source.kind, "PLEX_LIST")
        XCTAssertEqual(source.label, "Kids movies")
        XCTAssertEqual(source.sourceId, 2)
        XCTAssertEqual(source.requestedAgain, false)
        XCTAssertEqual(RequestSourceWords.phrase(source, mine: true), "From your Plex list · Kids movies")
        XCTAssertEqual(RequestSourceWords.phrase(source, mine: false), "Plex list · Kids movies")
    }

    func testLetterboxdListRequestReadsItsOwner() throws {
        let r = try decode(MediaRequest.self, "request_from_letterboxd_list")
        let source = try XCTUnwrap(r.source)
        XCTAssertEqual(source.kind, "LETTERBOXD_LIST")
        XCTAssertEqual(source.owner, "example_critic")
        XCTAssertEqual(source.sourceId, 3)
        XCTAssertEqual(RequestSourceWords.phrase(source, mine: true), "From Letterboxd list · Best of 2026")
        XCTAssertEqual(RequestLifecycle.sourceText(source), "Letterboxd list · Best of 2026")
    }

    func testCountsBySource() throws {
        let plex = try decode(RequestCounts.self, "request_counts_by_source")
        XCTAssertEqual(plex.inbox, 16)
        let buckets = try XCTUnwrap(plex.bySource)
        XCTAssertEqual(RequestSourceFilter.total(buckets), 18)
        let subs = RequestSourceFilter.subs(buckets, provider: .plex)
        XCTAssertEqual(subs.map(RequestSourceFilter.subLabel), ["Watchlist", "List · Kids movies", "List · Sci-fi to try"])
        XCTAssertTrue(RequestSourceFilter.subs(buckets, provider: .letterboxd).isEmpty)

        let lb = try XCTUnwrap(try decode(RequestCounts.self, "request_counts_by_source_letterboxd").bySource)
        XCTAssertEqual(lb.first?.owner, "example_critic")
        let lbSubs = RequestSourceFilter.subs(lb, provider: .letterboxd)
        XCTAssertEqual(lbSubs.map(RequestSourceFilter.subLabel), ["Diary", "List · Best of 2026"])
        let list = RequestSourceFilter(provider: .letterboxd, sub: RequestSourceFilter.Sub(lbSubs[1]))
        XCTAssertEqual(list.query.map(\.name), ["source", "source_id"])
        XCTAssertEqual(list.query.map(\.value), ["LETTERBOXD_LIST", "3"])
        let diary = RequestSourceFilter(provider: .letterboxd, sub: RequestSourceFilter.Sub(lbSubs[0]))
        XCTAssertEqual(diary.query.map(\.value), ["LETTERBOXD_RSS"])
    }

    func testPlexWatchlistAdmin() throws {
        let read = try decode(PlexWatchlistAdmin.self, "plex_watchlist_admin")
        XCTAssertEqual(read.plexTokenSet, true)
        XCTAssertEqual(read.paused, false)
        XCTAssertEqual(read.requestedTotal, 16)
        let outcomes = try XCTUnwrap(read.outcomes)
        XCTAssertEqual(outcomes["SKIPPED_POLICY"], 1)
        XCTAssertEqual(outcomes["BASELINE"], 23)
        XCTAssertEqual(outcomes["WITHDRAWN"], 0)
        XCTAssertEqual(outcomes.total, 45)
        XCTAssertEqual(SourceAdminCopy.outcomeRows(outcomes).map(\.key),
                       ["REQUESTED", "JOINED", "WAITING", "OWNED", "BASELINE", "SKIPPED_POLICY", "UNMATCHED"])
        XCTAssertEqual(read.recent?.count, 10)
        XCTAssertEqual(read.sources?.count, 4)
        XCTAssertEqual(read.sources?.last?.truncated, true)
        XCTAssertNil(SourceAdminCopy.plexErrorTitle(read))
        XCTAssertEqual(SourceAdminCopy.visibility(read.sources?[1].visibility), "Friends only")
    }

    func testPlexWatchlistSummary() throws {
        let rows = try decode([PlexWatchlistSummaryRow].self, "plex_watchlist_summary")
        XCTAssertEqual(rows.map(\.state), ["plex_only", "healthy", "allowed_off", "needs_sign_in"])
        XCTAssertEqual(SourceAdminCopy.plexChipLabel(rows[1]), "Healthy · 3 sources")
        XCTAssertFalse(SourceAdminCopy.plexChip(rows[0].state).opens)
    }

    func testLetterboxdAdmin() throws {
        let read = try decode(LetterboxdAdmin.self, "letterboxd_admin")
        XCTAssertEqual(read.me.username, "example_member")
        XCTAssertEqual(read.me.linkedCount, 4)
        XCTAssertEqual(read.me.maxLinkedLists, 5)
        XCTAssertEqual(read.sources.count, 6)
        XCTAssertEqual(read.sources.map(SourceAdminCopy.letterboxdSourceName),
                       ["Diary", "My watchlist", "@example_critic · Best of 2026", "@example_friend · Slow cinema",
                        "@example_friend · watchlist", "@letterboxd · watchlist"])
        XCTAssertEqual(SourceAdminCopy.letterboxdStatus(read.sources[3].status).label, "Blocked by Letterboxd")
        XCTAssertEqual(read.outcomes?["REQUESTED"], 11)
        XCTAssertEqual(read.flaresolverrConfigured, false)
    }

    func testLetterboxdSummaryAndStats() throws {
        let rows = try decode([LetterboxdSummaryRow].self, "letterboxd_summary")
        XCTAssertEqual(rows.count, 5)
        XCTAssertEqual(SourceAdminCopy.letterboxdChipLabel(rows[1]), "Needs attention · 1 blocked")
        XCTAssertEqual(SourceAdminCopy.letterboxdOverall(rows[1]), "1 blocked · 1 partly working")
        XCTAssertEqual(SourceAdminCopy.letterboxdChipLabel(rows[4]), "Can’t read profile")
        XCTAssertFalse(SourceAdminCopy.letterboxdOpens(rows[0].state))
        let stats = try decode(LetterboxdStats.self, "letterboxd_stats")
        XCTAssertEqual(stats.connectedUsers, 2)
        XCTAssertEqual(stats.linkedSources, 4)
    }

    func testFlareSolverrTest() throws {
        let r = try decode(FlareSolverrTest.self, "flaresolverr_test_ok")
        XCTAssertTrue(r.ok)
        XCTAssertEqual(r.elapsedMs, 3800)
        XCTAssertNil(r.reason)
    }
}
