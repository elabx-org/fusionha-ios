import XCTest
@testable import FusionhaKit

/// The Watchlists & lists routes and bodies (fusionha 0.4.226), through the
/// canned-response stub: methods, paths, bodies, and a resolve's 202.
final class AutomaticRequestsAPITests: XCTestCase {
    private func client(_ json: String, status: Int = 200) -> APIClient {
        ItemActionsStubProtocol.responseBody = Data(json.utf8)
        ItemActionsStubProtocol.status = status
        ItemActionsStubProtocol.lastRequest = nil
        ItemActionsStubProtocol.lastBody = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ItemActionsStubProtocol.self]
        return APIClient(baseURL: URL(string: "http://fh.test")!, token: "k", session: URLSession(configuration: config))
    }

    private var sent: URLRequest? { ItemActionsStubProtocol.lastRequest }

    private func sentJSON() throws -> [String: Any] {
        let body = try XCTUnwrap(ItemActionsStubProtocol.lastBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    func testSummaryAndSyncAll() async throws {
        let summary = try await client(#"{"requested_last7d": 2, "needs_review": 0, "syncing": null, "sources": [], "default_source_id": null}"#)
            .automaticRequestsSummary()
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/automatic-requests/summary")
        XCTAssertEqual(summary.requestedLast7d, 2)
        let sync = try await client(#"{"queued": ["plex-watchlist"], "sync_available_at": null}"#, status: 202).syncAutomaticRequests()
        XCTAssertEqual(sent?.httpMethod, "POST")
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/automatic-requests/sync")
        XCTAssertEqual(sync.queued, ["plex-watchlist"])
    }

    func testPauseAndBaseline() async throws {
        try await client("", status: 204).pauseRequestSource("list-38", paused: true)
        XCTAssertEqual(sent?.httpMethod, "PUT")
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/request-sources/list-38/pause")
        XCTAssertEqual(try sentJSON()["paused"] as? Bool, true)
        try await client("", status: 204).setRequestSourceBaseline("letterboxd-diary", baseline: "existing")
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/request-sources/letterboxd-diary/baseline")
        XCTAssertEqual(try sentJSON()["baseline"] as? String, "existing")
    }

    func testPauseRefusedByAnAdmin() async {
        do {
            try await client(#"{"detail": {"code": "not_allowed", "detail": "An admin paused it"}}"#, status: 403)
                .pauseRequestSource("plex-watchlist", paused: false)
            XCTFail("expected a 403")
        } catch {
            XCTAssertEqual(SourceDetailCopy.pauseError(error, resuming: true),
                           "An admin paused this source, so only an admin can resume it.")
        }
    }

    func testUnmatchedResolveAndIgnore() async throws {
        let items = try await client(#"[{"item_id": 38, "title": "Primal", "year": 2019, "source_url": null, "reason": "no_tmdb_link", "query": "Primal 2019"}]"#)
            .unmatchedItems("letterboxd-watchlist")
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/request-sources/letterboxd-watchlist/unmatched")
        XCTAssertEqual(items.map(\.itemId), [38])

        let done = try await client(#"{"outcome": "JOINED", "request_id": 7}"#)
            .resolveUnmatched("letterboxd-watchlist", itemId: 38, tmdbId: 500916, kind: .movie)
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/request-sources/letterboxd-watchlist/items/38/resolve")
        let body = try sentJSON()
        XCTAssertEqual(body["tmdb_id"] as? Int, 500916)
        XCTAssertEqual(body["kind"] as? String, "movie")
        XCTAssertEqual(body.count, 2)
        XCTAssertFalse(done.queued)
        XCTAssertEqual(done.requestId, 7)

        let queued = try await client(#"{"outcome": "QUEUED", "request_id": null}"#, status: 202)
            .resolveUnmatched("plex-watchlist", itemId: 4, tmdbId: 1, kind: .series)
        XCTAssertTrue(queued.queued)
        XCTAssertNil(queued.requestId)

        try await client("", status: 204).ignoreUnmatched("list-3", itemId: 9)
        XCTAssertEqual(sent?.httpMethod, "POST")
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/request-sources/list-3/items/9/ignore")
    }

    func testResolveRefusals() async {
        let cases: [(Int, String, PickCopy.Refusal)] = [
            (409, #"{"code": "source_paused", "reason": "paused"}"#, .paused),
            (409, #"{"code": "needs_sign_in"}"#, .signIn),
            (409, #"{"code": "not_unmatched"}"#, .handled),
            (403, #"{"code": "not_allowed"}"#, .notAllowed),
        ]
        for (status, detail, want) in cases {
            do {
                _ = try await client(#"{"detail": \#(detail)}"#, status: status)
                    .resolveUnmatched("list-3", itemId: 1, tmdbId: 2, kind: .movie)
                XCTFail("expected \(status)")
            } catch {
                XCTAssertEqual(PickCopy.Refusal(error), want)
            }
        }
    }

    func testRememberedMatches() async throws {
        let rows = try await client(#"[{"provider": "PLEX", "external_key": "plex://movie/1", "entry_url": null, "tmdb_id": 3, "kind": "movie", "title": "X", "year": 2001, "resolved_by": "admin", "resolved_at": "2026-10-17T12:00:00"}]"#)
            .listMatches()
        XCTAssertEqual(sent?.url?.path, "/api/v1/list-matches")
        XCTAssertEqual(rows.first?.isPlex, true)
        try await client("", status: 204).forgetListMatch(provider: "PLEX", externalKey: "plex://movie/1")
        XCTAssertEqual(sent?.url?.path, "/api/v1/list-matches/forget")
        let body = try sentJSON()
        XCTAssertEqual(body["provider"] as? String, "PLEX")
        XCTAssertEqual(body["external_key"] as? String, "plex://movie/1")
    }

    func testOwnWatchlistAlsoUhdSendsOnlyThatField() async throws {
        _ = try await client("{}").followLetterboxdWatchlist(alsoUhd: true)
        XCTAssertEqual(sent?.url?.path, "/api/v1/me/letterboxd/watchlist")
        let body = try sentJSON()
        XCTAssertEqual(body["also_uhd"] as? Bool, true)
        XCTAssertNil(body["enabled"])
    }
}
