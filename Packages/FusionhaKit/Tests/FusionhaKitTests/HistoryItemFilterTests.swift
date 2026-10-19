import XCTest
@testable import FusionhaKit

final class HistoryItemFilterTests: XCTestCase {
    func testParsesIdAndLabel() {
        let url = URL(string: "fusionha://activity/history?item_id=12&q=Dark%20Matter")!
        XCTAssertEqual(HistoryItemFilter.parse(url), HistoryItemFilter(itemId: 12, label: "Dark Matter"))
    }

    func testDefaultLabel() {
        XCTAssertEqual(HistoryItemFilter.parse(URL(string: "fusionha://activity/history?item_id=3")!)?.label, "this title")
    }

    func testRejectsBadIds() {
        XCTAssertNil(HistoryItemFilter.parse(URL(string: "fusionha://activity/history?item_id=0")!))
        XCTAssertNil(HistoryItemFilter.parse(URL(string: "fusionha://activity/history?item_id=x")!))
        XCTAssertNil(HistoryItemFilter.parse(URL(string: "fusionha://activity/history?q=x")!))
    }
}
