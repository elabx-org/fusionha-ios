import XCTest
@testable import FusionhaKit

final class ErrorCopyTests: XCTestCase {
    private func coded(_ code: String, status: Int = 409, prose: String = "SQL said no at /srv/data") -> APIError {
        .http(status: status, body: #"{"detail":{"code":"\#(code)","detail":"\#(prose)"}}"#)
    }

    func testReadsTheCode() {
        XCTAssertEqual(coded("quota").code, "quota")
        XCTAssertNil(APIError.http(status: 409, body: #"{"detail":"plain text"}"#).code)
        XCTAssertNil(APIError.http(status: 500, body: "<html>").code)
        XCTAssertNil(APIError.notSignedIn.code)
    }

    func testKnownCodeShowsOurCopyNeverTheServerProse() {
        let error = coded("quota")
        XCTAssertEqual(error.localizedDescription, "You’ve used all your requests for this week.")
        XCTAssertFalse(ErrorCopy.message(for: error).contains("SQL"))
    }

    func testUnknownCodeFallsBackToGeneric() {
        let error = coded("brand_new_code")
        XCTAssertEqual(ErrorCopy.message(for: error), ErrorCopy.generic)
        XCTAssertEqual(ErrorCopy.message(for: error, fallback: "Could not withdraw request"), "Could not withdraw request")
    }

    func testSurfaceOverrides() {
        XCTAssertEqual(ErrorCopy.message(for: coded("rate_limited", status: 429), surfaces: [.message]),
                       "You’ve sent a lot of messages. Try again in a bit.")
        XCTAssertEqual(ErrorCopy.message(code: "not_allowed", surfaces: ErrorCopy.surface(forIssueAction: "plex_rescan")),
                       "You don’t have permission for this fix.")
        XCTAssertEqual(ErrorCopy.message(code: "rate_limited", surfaces: ErrorCopy.surface(forIssueAction: "plex_rescan")),
                       "Give it a few minutes before trying again.")
    }

    func testSignInLimiter() {
        XCTAssertEqual(coded("login_rate_limited", status: 429).localizedDescription,
                       "Too many sign-in attempts. Wait a few minutes, then try again.")
        // An uncoded 429 still says something useful.
        XCTAssertEqual(APIError.http(status: 429, body: "").localizedDescription,
                       "Too many attempts. Wait a few minutes, then try again.")
    }

    func testUncodedErrorsKeepTheirOldWording() {
        XCTAssertEqual(APIError.http(status: 401, body: "").localizedDescription, "The server rejected the sign-in.")
        XCTAssertEqual(APIError.http(status: 502, body: "").localizedDescription, "The server answered with HTTP 502.")
    }

    /// A long coded body must survive the client's cut, or the code is lost.
    func testLongBodiesKeepTheirCode() {
        let error = coded("not_rejectable", prose: String(repeating: "x", count: 3000))
        XCTAssertEqual(error.code, "not_rejectable")
    }
}
