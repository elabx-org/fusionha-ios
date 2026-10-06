import XCTest
@testable import FusionhaKit

final class RowWindowLayoutTests: XCTestCase {
    private func layout(_ heights: [Double]) -> RowWindowLayout {
        RowWindowLayout(heights.enumerated().map { (id: "row-\($0.offset)", height: $0.element) })
    }

    func testStacksRowsWithCumulativeOffsets() {
        let l = layout([100, 120, 100])
        XCTAssertEqual(l.rows.map(\.y), [0, 100, 220])
        XCTAssertEqual(l.totalHeight, 320)
        XCTAssertEqual(l.index(of: "row-2"), 2)
        XCTAssertNil(l.index(of: "row-9"))
    }

    func testRangeCoversOnlyTheViewportPlusOverscan() {
        let l = layout(Array(repeating: 100, count: 100))
        XCTAssertEqual(l.range(top: 1000, bottom: 1300, overscan: 0), 10..<13)
        XCTAssertEqual(l.range(top: 1050, bottom: 1300, overscan: 200), 8..<15)
        XCTAssertEqual(l.range(top: -500, bottom: 200, overscan: 0), 0..<2)
        XCTAssertEqual(l.range(top: 20_000, bottom: 21_000, overscan: 0), 100..<100)
        XCTAssertEqual(RowWindowLayout().range(top: 0, bottom: 100, overscan: 10), 0..<0)
    }

    func testLandingRangeStartsAtTheTargetRow() {
        let l = layout(Array(repeating: 200, count: 50))
        XCTAssertEqual(l.range(landingAt: 30, viewport: 800, overscan: 0), 30..<34)
        XCTAssertEqual(l.range(landingAt: 99, viewport: 800, overscan: 0), 0..<0)
    }

    func testHeightsEstimateUntilMeasured() {
        var h = GridRowHeights(cardWidth: 100)
        XCTAssertEqual(h.height(slots: 1), 100 * 1.5 + 66 + 18)
        XCTAssertEqual(h.height(slots: 2), h.height(slots: 1) + GridRowHeights.defaultRailPitch)
        XCTAssertTrue(h.observe(slots: 1, height: 240))
        XCTAssertEqual(h.height(slots: 1), 240)
        XCTAssertEqual(h.height(slots: 3), 240 + 2 * GridRowHeights.defaultRailPitch)
        XCTAssertTrue(h.observe(slots: 2, height: 262))
        XCTAssertEqual(h.railPitch, 22)
        XCTAssertEqual(h.height(slots: 3), 284)
    }

    func testHeightsKeepTheTallestAndResetOnANewWidth() {
        var h = GridRowHeights(cardWidth: 100)
        h.observe(slots: 1, height: 240)
        XCTAssertFalse(h.observe(slots: 1, height: 239))
        XCTAssertFalse(h.observe(slots: 1, height: 240.3))
        XCTAssertTrue(h.observe(slots: 1, height: 242))
        h.reset(cardWidth: 100.2)
        XCTAssertEqual(h.measured[1], 242)
        h.reset(cardWidth: 120)
        XCTAssertTrue(h.measured.isEmpty)
    }
}
