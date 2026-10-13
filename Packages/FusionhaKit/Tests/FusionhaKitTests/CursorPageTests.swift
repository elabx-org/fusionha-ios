import XCTest
@testable import FusionhaKit

/// Serves one canned response with headers, recording the request.
final class CursorStubProtocol: URLProtocol {
    static var body = Data("[]".utf8)
    static var status = 200
    static var headers: [String: String] = [:]
    static var lastURL: URL?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastURL = request.url
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: Self.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class CursorPageTests: XCTestCase {
    private struct Row: Decodable, Sendable, Equatable { let id: Int }

    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CursorStubProtocol.self]
        return APIClient(baseURL: URL(string: "https://fusionha.test")!, token: "t", session: URLSession(configuration: config))
    }

    func testReadsItemsAndTheNextCursorHeader() async throws {
        CursorStubProtocol.status = 200
        CursorStubProtocol.body = Data(#"[{"id":1},{"id":2}]"#.utf8)
        CursorStubProtocol.headers = ["X-Next-Cursor": "abc123"]
        let page: CursorPage<Row> = try await client().cursorPage("/api/v1/requests", limit: 500, cursor: "prev")
        XCTAssertEqual(page.items, [Row(id: 1), Row(id: 2)])
        XCTAssertEqual(page.nextCursor, "abc123")
        let query = URLComponents(url: try XCTUnwrap(CursorStubProtocol.lastURL), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "limit" }?.value, "200")   // clamped to the server's max
        XCTAssertEqual(query.first { $0.name == "cursor" }?.value, "prev")
    }

    func testLastPageHasNoCursor() async throws {
        CursorStubProtocol.status = 200
        CursorStubProtocol.body = Data("[]".utf8)
        CursorStubProtocol.headers = [:]
        let page: CursorPage<Row> = try await client().cursorPage("/api/v1/issues", limit: 50, cursor: nil)
        XCTAssertNil(page.nextCursor)
    }

    func testBadCursorIsACodedError() async {
        CursorStubProtocol.status = 422
        CursorStubProtocol.body = Data(#"{"detail":{"code":"bad_cursor","detail":"cursor does not decode"}}"#.utf8)
        CursorStubProtocol.headers = [:]
        do {
            let _: CursorPage<Row> = try await client().cursorPage("/api/v1/requests", limit: 50, cursor: "junk")
            XCTFail("expected a 422")
        } catch let error as APIError {
            XCTAssertEqual(error.code, "bad_cursor")
            XCTAssertEqual(error.localizedDescription, "The list changed. Pull to refresh.")
        } catch { XCTFail("\(error)") }
    }
}
