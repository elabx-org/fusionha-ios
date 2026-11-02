import XCTest
@testable import FusionhaKit

/// `GET /api/v1/search/unified` (fusionha 0.4.236): decoding, the lanes each
/// `sources.tmdb` state gives, and the server source's requests.
final class ServerUnifiedSearchTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "search-unified", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func response(library: String = "ok", tmdb: String, items: String = "[]", total: Int = 0) throws -> UnifiedSearchResponse {
        let json = """
        {"query": {"term": "dune", "title": "dune", "year": null},
         "sources": {"library": "\(library)", "tmdb": "\(tmdb)"},
         "library": {"total": \(total), "items": []},
         "tmdb": {"provider": "tmdb", "items": \(items)}}
        """
        return try APIClient.decoder.decode(UnifiedSearchResponse.self, from: Data(json.utf8))
    }

    private let dune = #"[{"tmdb_id": 438631, "title": "Dune", "year": 2021, "kind": "movie", "is_anime": false, "overview": null, "in_library": false}]"#

    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UnifiedSearchStubProtocol.self]
        return APIClient(baseURL: URL(string: "https://fusionha.test")!, token: "t", session: URLSession(configuration: config))
    }

    override func setUp() {
        UnifiedSearchStubProtocol.seen = []
    }

    // MARK: Decoding

    func testDecodesTheFixture() throws {
        let r = try APIClient.decoder.decode(UnifiedSearchResponse.self, from: fixture())
        XCTAssertEqual(r.query.term, "dune 2024")
        XCTAssertEqual(r.query.title, "dune")
        XCTAssertEqual(r.query.year, 2024)
        XCTAssertEqual(r.sources.library, .ok)
        XCTAssertEqual(r.sources.tmdb, .timeout)
        XCTAssertEqual(r.library.total, 9)
        XCTAssertEqual(r.library.items.map(\.id), [7])
        XCTAssertEqual(r.library.items.first?.editions.first?.tier, .hd)
        XCTAssertEqual(r.tmdb.provider, "tmdb")
        XCTAssertEqual(r.tmdb.items.map(\.tmdbId), [438631, 693134])
        XCTAssertEqual(r.tmdb.items.last?.libraryItemId, 7)
    }

    func testDecodesEverySourceState() throws {
        XCTAssertEqual(try response(tmdb: "ok").sources.tmdb, .ok)
        XCTAssertEqual(try response(tmdb: "skipped").sources.tmdb, .skipped)
        XCTAssertEqual(try response(tmdb: "unavailable").sources.tmdb, .unavailable)
        XCTAssertEqual(try response(tmdb: "not_configured").sources.tmdb, .notConfigured)
        XCTAssertEqual(try response(library: "forbidden", tmdb: "ok").sources.library, .forbidden)
        // A state from a newer server reads as unavailable, never a decode failure.
        XCTAssertEqual(try response(tmdb: "rate_limited").sources.tmdb, .unavailable)
    }

    // MARK: Lanes per state

    private func lanes(_ r: UnifiedSearchResponse, tvdb: [TvdbSearchResult]? = nil) -> UnifiedSearchLanes {
        var acc = UnifiedSearchAccumulator(pending: [.tmdb, .tvdb])
        acc.receive(unified: r)
        if let tvdb { acc.receive(tvdb: tvdb) }
        return acc.lanes
    }

    func testOkFillsTheAddLane() throws {
        let l = lanes(try response(tmdb: "ok", items: dune))
        XCTAssertEqual(l.tmdbSource, .ok)
        XCTAssertEqual(l.add.map(\.title), ["Dune"])
        XCTAssertEqual(l.pending, [.tvdb])
        XCTAssertFalse(l.addSkipped)
    }

    func testSkippedHidesTheAddLaneAndStopsWaiting() throws {
        let tvdbRow = try APIClient.decoder.decode(TvdbSearchResult.self,
                                                   from: Data(#"{"tvdb_id": 1, "title": "Dune: Prophecy", "year": 2024}"#.utf8))
        let l = lanes(try response(tmdb: "skipped", total: 3))
        XCTAssertTrue(l.addSkipped)
        XCTAssertTrue(l.add.isEmpty)
        XCTAssertTrue(l.isSettled, "TheTVDB isn't waited on once TMDB was skipped")
        XCTAssertEqual(l.library?.total, 3)
        XCTAssertTrue(lanes(try response(tmdb: "skipped"), tvdb: [tvdbRow]).add.isEmpty)
    }

    func testNotConfiguredIsSkippedSilently() throws {
        let l = lanes(try response(tmdb: "not_configured"))
        XCTAssertEqual(l.unconfigured, [.tmdb])
        XCTAssertTrue(l.failed.isEmpty)
    }

    func testTimeoutKeepsWhatAnsweredElseFails() throws {
        let partial = lanes(try response(tmdb: "timeout", items: dune))
        XCTAssertEqual(partial.add.map(\.title), ["Dune"])
        XCTAssertTrue(partial.failed.isEmpty)
        XCTAssertEqual(partial.tmdbSource, .timeout)
        let empty = lanes(try response(tmdb: "timeout"))
        XCTAssertEqual(empty.failed, [.tmdb])
        XCTAssertEqual(lanes(try response(tmdb: "unavailable")).failed, [.tmdb])
    }

    func testForbiddenLibrary() throws {
        let l = lanes(try response(library: "forbidden", tmdb: "ok", items: dune))
        XCTAssertTrue(l.libraryForbidden)
        XCTAssertEqual(l.library?.items.count, 0)
        XCTAssertEqual(l.add.count, 1)
    }

    // MARK: The source

    private func query(_ path: String) throws -> [URLQueryItem] {
        let url = try XCTUnwrap(UnifiedSearchStubProtocol.seen.first { $0.path == path })
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    func testSendsTheTermLimitModeAndKind() async throws {
        let body = String(data: try fixture(), encoding: .utf8)!
        UnifiedSearchStubProtocol.routes = ["/api/v1/search/unified": (200, body), "/api/v1/search/tvdb": (200, "[]")]
        var last = UnifiedSearchLanes()
        for await l in ServerUnifiedSearchSource(client: client(), tmdb: .always).lanes(for: "dune 2024", kind: .anime) { last = l }
        let q = try query("/api/v1/search/unified")
        XCTAssertEqual(q.first { $0.name == "q" }?.value, "dune 2024")
        XCTAssertEqual(q.first { $0.name == "limit" }?.value, "8")
        XCTAssertEqual(q.first { $0.name == "tmdb" }?.value, "always")
        XCTAssertEqual(q.filter { $0.name == "kinds" }.map(\.value), ["anime"])
        XCTAssertFalse(UnifiedSearchStubProtocol.seen.contains { $0.path == "/api/v1/search" })
        XCTAssertTrue(last.isSettled)
        XCTAssertEqual(last.add.map(\.title), ["Dune"])
        XCTAssertEqual(last.ownedTmdb.map(\.tmdbId), [693134])
        XCTAssertEqual(last.library?.total, 9)
    }

    func testAllSendsNoKindsAndAlwaysByDefault() async throws {
        UnifiedSearchStubProtocol.routes = ["/api/v1/search/unified": (200, String(data: try fixture(), encoding: .utf8)!),
                                            "/api/v1/search/tvdb": (200, "[]")]
        for await _ in ServerUnifiedSearchSource(client: client()).lanes(for: "dune", kind: .all) {}
        let q = try query("/api/v1/search/unified")
        XCTAssertEqual(q.first { $0.name == "tmdb" }?.value, "always")
        XCTAssertTrue(q.filter { $0.name == "kinds" }.isEmpty)
    }

    func testAnOlderServerFallsBackToSearch() async {
        UnifiedSearchStubProtocol.routes = ["/api/v1/search": (200, dune), "/api/v1/search/tvdb": (200, "[]")]
        var last = UnifiedSearchLanes()
        for await l in ServerUnifiedSearchSource(client: client()).lanes(for: "dune", kind: .movie) { last = l }
        XCTAssertTrue(UnifiedSearchStubProtocol.seen.contains { $0.path == "/api/v1/search/unified" })
        XCTAssertEqual(last.add.map(\.title), ["Dune"])
        XCTAssertNil(last.tmdbSource)
        XCTAssertTrue(last.isSettled)
    }
}
