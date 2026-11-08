import XCTest
@testable import FusionhaKit

final class UnauthorizedSignOutTests: XCTestCase {
    private let base = URL(string: "https://fusionha.example.com")!

    private func signsOut(_ path: String, status: Int = 401, method: String = "GET",
                          auth: AuthMethod? = .apiToken, base: URL? = nil) -> Bool {
        let base = base ?? self.base
        let url = URL(string: base.absoluteString + path)!
        return UnauthorizedSignOut.signsOut(status: status, method: method, url: url, base: base, auth: auth)
    }

    func testA401OnASignedInCallSignsOut() {
        XCTAssertTrue(signsOut("/api/v1/queue"))
        XCTAssertTrue(signsOut("/library/12/search", method: "POST"))
        XCTAssertTrue(signsOut("/api/v1/tokens"))
        XCTAssertTrue(signsOut("/api/v1/queue", auth: .session))
    }

    func testOnlyA401SignsOut() {
        XCTAssertFalse(signsOut("/api/v1/queue", status: 403))
        XCTAssertFalse(signsOut("/api/v1/queue", status: 500))
        XCTAssertFalse(signsOut("/api/v1/queue", status: 0))
    }

    func testSignInEndpointsProbesAndDemoNeverSignOut() {
        XCTAssertFalse(signsOut("/api/v1/auth/login", method: "POST"))
        XCTAssertFalse(signsOut("/api/v1/auth/me"))
        XCTAssertFalse(signsOut("/api/v1/auth/plex/pin/4/check", method: "POST"))
        XCTAssertFalse(signsOut("/api/v1/tokens", method: "POST"))
        XCTAssertFalse(signsOut("/api/v1/demo/login", method: "POST"))
        XCTAssertFalse(signsOut("/health"))
        XCTAssertFalse(signsOut("/api/v1/setup-status"))
    }

    func testRequestsWithoutCredentialsOrAsTheDemoNeverSignOut() {
        XCTAssertFalse(signsOut("/api/v1/queue", auth: nil))
        XCTAssertFalse(signsOut("/api/v1/queue", auth: .demoCookie))
    }

    func testAReverseProxyPrefixIsIgnored() {
        let proxied = URL(string: "https://home.example/fusionha")!
        XCTAssertFalse(signsOut("/api/v1/auth/login", method: "POST", base: proxied))
        XCTAssertTrue(signsOut("/api/v1/queue", base: proxied))
        XCTAssertEqual(UnauthorizedSignOut.relativePath(URL(string: "https://home.example/fusionha/health/")!, base: proxied),
                       "/health")
    }

    func testMessageNamesTheReasonWhenGiven() {
        XCTAssertEqual(UnauthorizedSignOut.message(for: .http(status: 401, body: "")), UnauthorizedSignOut.neutralMessage)
        XCTAssertEqual(UnauthorizedSignOut.message(for: .http(status: 401, body: #"{"detail":"Not authenticated"}"#)),
                       UnauthorizedSignOut.neutralMessage)
        XCTAssertEqual(UnauthorizedSignOut.message(for: .http(status: 401, body: #"{"code":"token_revoked"}"#)),
                       "This device's sign-in was revoked. Sign in again.")
        XCTAssertEqual(UnauthorizedSignOut.message(for: .http(status: 401, body: #"{"detail":{"code":"password_changed"}}"#)),
                       "Your password was changed. Sign in again.")
        XCTAssertEqual(UnauthorizedSignOut.message(for: .http(status: 401, body: #"{"code":"expired"}"#)),
                       "Your sign-in expired. Sign in again.")
        XCTAssertEqual(UnauthorizedSignOut.message(for: .http(status: 401, body: #"{"code":"session_revoked"}"#)),
                       "Your session was ended. Sign in again.")
    }

    func testABurstSignsOutOnce() {
        var gate = UnauthorizedSignOut.Gate()
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(gate.admit(at: start))
        XCTAssertFalse(gate.admit(at: start.addingTimeInterval(0.1)))
        XCTAssertFalse(gate.admit(at: start.addingTimeInterval(UnauthorizedSignOut.quiet - 0.1)))
        XCTAssertTrue(gate.admit(at: start.addingTimeInterval(UnauthorizedSignOut.quiet + 0.1)))
    }

    func testAnEligible401PostsTheNotification() async {
        let posted = expectation(forNotification: UnauthorizedSignOut.notification, object: nil) { note in
            (note.userInfo?["message"] as? String) == UnauthorizedSignOut.neutralMessage
                && (note.userInfo?["server"] as? URL) == self.base
        }
        let client = APIClient(baseURL: base, token: "t")
        var req = URLRequest(url: base.appendingPathComponent("/api/v1/queue"))
        req.httpMethod = "GET"
        client.reportUnauthorized(req, error: .http(status: 401, body: ""))
        await fulfillment(of: [posted], timeout: 1)
    }
}
