import XCTest
@testable import FusionhaKit

final class ReplacePlanTests: XCTestCase {
    func testSlowErrorsAreNotFailures() {
        XCTAssertEqual(ReplacePlan.result(of: URLError(.timedOut), kind: .regrab), .slow)
        XCTAssertEqual(ReplacePlan.result(of: URLError(.networkConnectionLost), kind: .regrab), .slow)
        XCTAssertEqual(ReplacePlan.result(of: URLError(.cannotConnectToHost), kind: .regrab), .failed)
        XCTAssertEqual(ReplacePlan.result(of: APIError.http(status: 422, body: ""), kind: .regrab), .stood)
        XCTAssertEqual(ReplacePlan.result(of: APIError.http(status: 409, body: ""), kind: .replace(force: false)), .stood)
        XCTAssertEqual(ReplacePlan.result(of: APIError.http(status: 422, body: ""), kind: .blocklist), .failed)
    }

    func testSummaryNeverCallsSlowAFailure() {
        let slow = ReplacePlan.summary([.done, .slow], searched: 2)
        XCTAssertFalse(slow.isError)
        XCTAssertTrue(slow.pointsToActivity)
        XCTAssertEqual(slow.message, "Still searching on the server. Activity shows the result.")
        XCTAssertEqual(ReplacePlan.summary([.done, .done], searched: 2).message, "Searched for 2 new copies.")
        XCTAssertEqual(ReplacePlan.summary([.done], searched: 1).message, "Searched for a new copy.")
        XCTAssertTrue(ReplacePlan.summary([.done, .failed], searched: 1).isError)
    }
}
