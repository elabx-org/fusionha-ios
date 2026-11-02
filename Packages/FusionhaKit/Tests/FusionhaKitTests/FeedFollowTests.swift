import XCTest
@testable import FusionhaKit

/// Requests phase 10b slice 2 (fusionha 0.4.237): following an MDBList, Trakt
/// or Letterboxd list by address. The preview's new fields (golden from
/// fusionha `docs/fixtures/`), a `LIST_FEED` row on the page, the bodies sent,
/// the refusal copy and the `unavailable` state.
final class FeedFollowTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"))
        return try APIClient.decoder.decode(T.self, from: Data(contentsOf: url))
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func error(_ status: Int, _ detail: String) -> APIError {
        .http(status: status, body: #"{"detail":\#(detail)}"#)
    }

    /// A followed MDBList list as `GET /me/request-sources` sends it.
    private let feedRow = #"""
    {"id": 41, "source_id": "list-41", "unmatched_count": 2, "kind": "LIST_FEED", "label": "Top Watched Movies of the Week",
     "url": "https://mdblist.com/lists/linaspurinis/top-watched-movies-of-the-week", "provider": "MDBLIST",
     "owner": "linaspurinis", "is_self": false, "enabled": true, "status": "OK", "last_checked_at": null,
     "next_check_at": null, "retry_at": null, "last_error": null, "via_flaresolverr": false, "requested_count": 3,
     "item_count": 20, "baseline": "new", "truncated": false, "options": {"also_uhd": true},
     "sync": null, "counts": {"requested": 4, "owned": 12, "queued": 0, "waiting": 0, "skipped": 0, "unmatched": 2, "baseline": 13}}
    """#

    // MARK: Decoding

    func testGoldenPreviewCarriesSiteKindAndMix() throws {
        let preview = try decode(LbSourcePreview.self, "request_source_preview")
        XCTAssertEqual(preview.provider, "LETTERBOXD")
        XCTAssertEqual(preview.site, .letterboxd)
        XCTAssertEqual(preview.kind, "list")
        XCTAssertEqual(preview.mix, PreviewMix(movies: 25, series: 0))
        XCTAssertEqual(preview.inLibraryCount, 0)
        XCTAssertEqual(preview.items.first?.kind, "movie")
        XCTAssertNil(preview.items.first?.posterUrl)
    }

    func testFeedPreviewDecodes() throws {
        let preview = try decode(LbSourcePreview.self, json: #"""
        {"title": "Trending shows", "owner": "trakt_ex", "item_count": 40, "provider": "TRAKT", "kind": "list",
         "mix": {"movies": 10, "series": 30}, "in_library_count": 7,
         "items": [{"title": "Severance", "year": 2022, "in_library": true, "kind": "series", "tmdb_id": 95396,
                    "poster_url": "https://image.tmdb.org/t/p/w342/abc.jpg"}]}
        """#)
        XCTAssertEqual(preview.site, .trakt)
        XCTAssertEqual(preview.mix?.movieShare, 0.25)
        XCTAssertEqual(preview.items.first?.tmdbId, 95396)
        XCTAssertTrue(preview.items[0].inLibrary)
        // An older server's preview still decodes.
        let old = try decode(LbSourcePreview.self, json: #"{"title": null, "owner": "x", "item_count": null, "items": []}"#)
        XCTAssertNil(old.mix)
        XCTAssertEqual(old.site, .letterboxd)
    }

    func testRowsCarryProvider() throws {
        let rows = try decode([LbSource].self, "request_sources_me")
        XCTAssertEqual(Set(rows.compactMap(\.provider)), ["LETTERBOXD"])
        let feed = try decode(LbSource.self, json: feedRow)
        XCTAssertTrue(feed.isFeed)
        XCTAssertTrue(feed.isLinked, "the 5-list limit is shared")
        XCTAssertTrue(feed.alsoUhd)
        let summary = try decode(RequestSourcesSummary.self, "request_sources_summary")
        XCTAssertEqual(summary.sources.first?.provider, "LETTERBOXD")
    }

    // MARK: Page model

    func testFeedRowOnThePage() throws {
        let summary = try decode(AutoSummary.self, json: #"""
        {"requested_last7d": 0, "needs_review": 2, "syncing": null, "default_source_id": "list-41",
         "sources": [{"source_id": "list-41", "group": "lists", "state": "healthy", "needs_review": 2},
                     {"source_id": "list-77", "group": "lists", "state": "unavailable", "needs_review": 0}]}
        """#)
        XCTAssertEqual(summary.sources[1].state, .unavailable)
        let views = AutoSourceViews.build(summary, letterboxd: nil, sources: [try decode(LbSource.self, json: feedRow)], plex: nil)
        XCTAssertEqual(views[0].kind, .feed)
        XCTAssertEqual(views[0].site, .mdblist)
        XCTAssertEqual(views[0].name, "Top Watched Movies of the Week")
        XCTAssertEqual(views[0].subtitle, "@linaspurinis · MDBList · 4 requested · 20 titles")
        XCTAssertEqual(views[0].provider, "MDBList")
        XCTAssertTrue(AutoSourceDetail(views[0]).uhd)
        // Not read yet: a followed list, not a Letterboxd one.
        XCTAssertEqual(views[1].name, "Followed list")
        XCTAssertEqual(views[1].kind, .feed)
    }

    func testUnavailableState() {
        XCTAssertEqual(AutoSourceState(wire: "unavailable"), .unavailable)
        XCTAssertEqual(AutoSourceState.unavailable.word, "Unavailable")
        XCTAssertEqual(AutoSourceState.unavailable.tone, .miss)
        XCTAssertEqual(WatchlistsTaskLogic.kindLabel("LIST_FEED", provider: "TRAKT"), "Trakt list")
        XCTAssertEqual(WatchlistsTaskLogic.kindLabel("LIST_FEED", provider: nil), "Followed list")
        XCTAssertEqual(SourceDetailCopy.privateRestOn("Trakt"),
                       "Set it to public on Trakt to keep it in sync. Counts are from the last check.")
    }

    // MARK: Address rules and refusals

    func testAddressRules() {
        XCTAssertTrue(FeedFollowLogic.ready("mdblist.com/lists/a/b"))
        XCTAssertFalse(FeedFollowLogic.ready("not an address"))
        XCTAssertFalse(FeedFollowLogic.ready("letterboxd"))
        XCTAssertTrue(FeedFollowLogic.isPlexAddress("https://watch.plex.tv/watchlist/abc"))
        XCTAssertFalse(FeedFollowLogic.ready("app.plex.tv/desktop"))
        XCTAssertEqual(FeedFollowLogic.guessProvider("https://trakt.tv/users/x/lists/y"), .trakt)
        XCTAssertEqual(SourceProvider(feed: "MDBLIST"), .mdblist)
        XCTAssertEqual(SourceProvider(feed: nil), .letterboxd)
        XCTAssertEqual(FeedCopy.newOnlyDesc(20), "The 20 titles on it now are noted and left alone.")
        XCTAssertEqual(FeedCopy.existingDesc(nil), "A few at a time, within your weekly limit.")
    }

    func testRefusalsUseTheWebsWords() {
        func text(_ e: APIError, _ guess: SourceProvider = .mdblist) -> FeedRefusal {
            let m = FeedFollowLogic.message(for: e, guess: guess)
            return FeedRefusal(text: m.text, tip: m.tip)
        }
        XCTAssertEqual(text(error(422, #"{"code": "unsupported_site", "supported": ["mdblist.com"], "host": "www.imdb.com"}"#)),
                       FeedRefusal(text: "fusionha can’t follow lists from www.imdb.com. Paste a public list from MDBList, Trakt or Letterboxd.",
                                   tip: FeedCopy.imdbTip))
        XCTAssertEqual(text(error(409, #"{"code": "provider_unavailable"}"#)).text,
                       "Trakt isn’t set up on this server yet. Ask an admin to add a Trakt app id.")
        XCTAssertEqual(text(error(422, #"{"code": "coming_later"}"#)).text, "Plex lists from other people are coming later.")
        XCTAssertEqual(text(error(503, #"{"code": "unavailable"}"#), .trakt).text, "Trakt didn’t answer. Try again in a few minutes.")
        XCTAssertEqual(text(error(503, #"{"code": "unavailable", "provider": "MDBLIST"}"#), .trakt).text,
                       "MDBList didn’t answer. Try again in a few minutes.")
        XCTAssertEqual(text(error(403, #"{"code": "not_allowed"}"#)).text, "An admin hasn’t allowed you to follow lists.")
        XCTAssertEqual(text(error(409, #"{"code": "limit_reached"}"#)).text,
                       "You’ve reached your limit of linked lists. Remove one to add another.")
        XCTAssertEqual(FeedFollowLogic.watchlistMessage(for: error(503, #"{"code": "blocked"}"#)),
                       "Letterboxd is blocking fusionha right now. Try again later, or use an MDBList list instead.")
    }

    private struct FeedRefusal: Equatable {
        let text: String
        let tip: String?
    }

    // MARK: Bodies

    func testFollowBodies() {
        let feed = APIClient.followBody("https://mdblist.com/lists/a/b", letterboxd: false, requestExisting: true, alsoUhd: true)
        XCTAssertEqual(feed["kind"], "feed")
        XCTAssertEqual(feed["also_uhd"], .bool(true))
        XCTAssertEqual(feed["request_existing"], .bool(true))
        XCTAssertEqual(feed["enabled"], .bool(true))
        let lb = APIClient.followBody("https://letterboxd.com/a/list/b/", letterboxd: true, requestExisting: false, alsoUhd: true)
        XCTAssertEqual(lb["kind"], "list")
        XCTAssertNil(lb["also_uhd"], "a Letterboxd list uses the diary’s UHD·4K")
    }
}

/// The slice 2 routes through the canned-response stub.
final class FeedFollowAPITests: XCTestCase {
    private func client(_ json: String, status: Int = 200) -> APIClient {
        ItemActionsStubProtocol.responseBody = Data(json.utf8)
        ItemActionsStubProtocol.status = status
        ItemActionsStubProtocol.lastRequest = nil
        ItemActionsStubProtocol.lastBody = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ItemActionsStubProtocol.self]
        return APIClient(baseURL: URL(string: "http://fh.test")!, token: "k", session: URLSession(configuration: config))
    }

    private func sentJSON() throws -> [String: Any] {
        let body = try XCTUnwrap(ItemActionsStubProtocol.lastBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    func testPreviewSendsOnlyTheAddress() async throws {
        _ = try await client(#"{"title": "T", "owner": "o", "item_count": 1, "items": [], "provider": "MDBLIST"}"#)
            .previewListAddress("https://mdblist.com/lists/a/b")
        XCTAssertEqual(ItemActionsStubProtocol.lastRequest?.url?.path, "/api/v1/me/request-sources/preview")
        let body = try sentJSON()
        XCTAssertEqual(body as NSDictionary, ["url": "https://mdblist.com/lists/a/b"] as NSDictionary)
    }

    func testPatchTakesAlsoUhdAndTraktClears() async throws {
        let row = #"{"id": 41, "kind": "LIST_FEED", "provider": "TRAKT", "options": {"also_uhd": false}}"#
        _ = try await client(row).updateRequestSource(id: 41, alsoUhd: false)
        XCTAssertEqual(ItemActionsStubProtocol.lastRequest?.httpMethod, "PATCH")
        XCTAssertEqual(try sentJSON() as NSDictionary, ["also_uhd": false] as NSDictionary)
        try await client("", status: 204).clearTraktClientId()
        XCTAssertEqual(ItemActionsStubProtocol.lastRequest?.httpMethod, "DELETE")
        XCTAssertEqual(ItemActionsStubProtocol.lastRequest?.url?.path, "/api/v1/settings/trakt-client-id")
    }
}
