import XCTest
@testable import FusionhaKit

final class PushLinkTests: XCTestCase {
    private func link(_ path: String) -> String? { PushLink.deepLink(webPath: path)?.absoluteString }

    func testPaths() {
        XCTAssertEqual(link("/library/42"), "fusionha://item/42")
        XCTAssertEqual(link("/discover?tab=requests"), "fusionha://discover/requests")
        XCTAssertEqual(link("/discover?tab=issues"), "fusionha://discover/issues")
        XCTAssertEqual(link("/activity?tab=audit"), "fusionha://activity/audit")
        XCTAssertEqual(link("/activity?tab=queue&focus=812"), "fusionha://activity/queue?focus=812")
        XCTAssertEqual(link("/activity?tab=queue&focus=812&block=1"), "fusionha://activity/queue?focus=812&block=1")
        XCTAssertEqual(link("/calendar"), "fusionha://calendar")
    }

    func testRejectsJunk() {
        XCTAssertNil(link("/library/abc"))
        XCTAssertNil(link("/activity?tab=nope"))
        XCTAssertNil(link("/settings/general"))
        XCTAssertNil(PushLink.deepLink(webPath: nil))
        XCTAssertEqual(link("/account/lists"), "fusionha://account/lists")
        XCTAssertEqual(link("/account/lists/list-38"), "fusionha://account/lists/list-38")
        XCTAssertNil(link("/account"))
        XCTAssertEqual(link("/activity?tab=queue&focus=x&block=1"), "fusionha://activity/queue")   // no id, no block
    }

    func testQueueFocus() throws {
        let url = try XCTUnwrap(PushLink.deepLink(webPath: "/activity?tab=queue&focus=812&block=1"))
        let focus = try XCTUnwrap(PushLink.queueFocus(in: url))
        XCTAssertEqual(focus.downloadId, 812)
        XCTAssertTrue(focus.block)
        XCTAssertNil(PushLink.queueFocus(in: URL(string: "fusionha://activity/queue")!))
    }
}
