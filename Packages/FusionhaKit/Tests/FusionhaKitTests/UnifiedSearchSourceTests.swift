import XCTest
@testable import FusionhaKit

/// Answers each search path with its own canned status and body.
final class UnifiedSearchStubProtocol: URLProtocol {
    static var routes: [String: (Int, String)] = [:]
    static var seen: [URL] = []
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url!
        Self.lock.lock()
        Self.seen.append(url)
        let route = Self.routes[url.path] ?? (404, #"{"detail":"not found"}"#)
        Self.lock.unlock()
        let response = HTTPURLResponse(url: url, statusCode: route.0, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(route.1.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class UnifiedSearchSourceTests: XCTestCase {
    private let dune = #"{"tmdb_id": 693134, "title": "Dune: Part Two", "year": 2024, "kind": "movie", "is_anime": false, "in_library": false}"#

    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [UnifiedSearchStubProtocol.self]
        return APIClient(baseURL: URL(string: "https://fusionha.test")!, token: "t", session: URLSession(configuration: config))
    }

    override func setUp() {
        UnifiedSearchStubProtocol.seen = []
    }

    func testSearchByIdSendsTheIdAndKind() async throws {
        UnifiedSearchStubProtocol.routes = ["/api/v1/search/by-id": (200, dune)]
        let hit = try await client().searchById("tt15239678", kind: .movie)
        XCTAssertEqual(hit.tmdbId, 693134)
        let url = try XCTUnwrap(UnifiedSearchStubProtocol.seen.last)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "id" }?.value, "tt15239678")
        XCTAssertEqual(query.first { $0.name == "kind" }?.value, "movie")
    }

    func testFanOutSkipsAnUnconfiguredTvdbAndPinsTheIdHit() async {
        UnifiedSearchStubProtocol.routes = [
            "/api/v1/search": (200, "[\(dune)]"),
            "/api/v1/search/tvdb": (409, #"{"detail":{"code":"tvdb_not_configured"}}"#),
            "/api/v1/search/by-id": (200, dune),
        ]
        var last = UnifiedSearchLanes()
        var updates = 0
        for await lanes in ClientUnifiedSearchSource(client: client()).lanes(for: "tt15239678") {
            last = lanes
            updates += 1
        }
        XCTAssertGreaterThanOrEqual(updates, 2)
        XCTAssertTrue(last.isSettled)
        XCTAssertEqual(last.unconfigured, [.tvdb])
        XCTAssertTrue(last.failed.isEmpty)
        XCTAssertEqual(last.exact.map(\.tmdbId), [693134])
        XCTAssertTrue(last.add.isEmpty)
    }

    func testATitleSkipsTheIdLookup() async {
        UnifiedSearchStubProtocol.routes = [
            "/api/v1/search": (200, "[\(dune)]"),
            "/api/v1/search/tvdb": (200, "[]"),
        ]
        var last = UnifiedSearchLanes()
        for await lanes in ClientUnifiedSearchSource(client: client()).lanes(for: "dune") { last = lanes }
        XCTAssertEqual(last.add.map(\.title), ["Dune: Part Two"])
        XCTAssertFalse(UnifiedSearchStubProtocol.seen.contains { $0.path.hasSuffix("by-id") })
    }
}
