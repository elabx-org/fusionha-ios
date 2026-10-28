import XCTest
@testable import FusionhaKit

/// Calls that wait on the server's grab (0.4.227: the download client's add
/// can take up to 120 s) get the slow timeout.
final class APIClientTimeoutTests: XCTestCase {
    func testGrabsAndReGrabsWaitForTheClientAdd() {
        XCTAssertEqual(APIClient.timeout(for: "/api/v1/library/12/releases/grab"), 180)
        XCTAssertEqual(APIClient.timeout(for: "/api/v1/history/9/regrab"), 180)
        XCTAssertEqual(APIClient.timeout(for: "/api/v1/library/files/4/remove-and-regrab"), 180)
    }

    func testOrdinaryCallsStayQuick() {
        XCTAssertEqual(APIClient.timeout(for: "/api/v1/library"), 20)
        XCTAssertEqual(APIClient.timeout(for: "/api/v1/settings"), 20)
    }
}
