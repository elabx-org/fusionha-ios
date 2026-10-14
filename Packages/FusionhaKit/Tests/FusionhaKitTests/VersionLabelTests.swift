import XCTest
@testable import FusionhaKit

final class VersionLabelTests: XCTestCase {
    func testEditionFirst() {
        XCTAssertEqual(VersionLabel.text(tier: .hd, edition: "Extended"), "Extended · HD")
        XCTAssertEqual(VersionLabel.text(tier: .uhd, edition: "Black & White", multipleEditions: true), "Black & White · 4K")
    }

    func testStandardOnlyWhenSeveral() {
        XCTAssertNil(VersionLabel.text(tier: .hd, edition: nil))
        XCTAssertNil(VersionLabel.text(tier: .uhd, edition: "  "))
        XCTAssertEqual(VersionLabel.text(tier: .uhd, edition: nil, multipleEditions: true), "Standard · 4K")
    }

    func testWebSessionCookieFromHeaders() throws {
        let url = URL(string: "http://fusionha.local:8787/api/v1/auth/session")!
        let http = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
            "Set-Cookie": "fusionha_session=abc123; HttpOnly; Path=/; SameSite=lax",
        ]))
        XCTAssertEqual(APIClient.sessionCookie(in: http, url: url), "abc123")
    }
}
