import XCTest
@testable import FusionhaKit

/// The open title survives fold / unfold / rotation (Duo blocker DC3).
final class DetailContinuityTests: XCTestCase {
    final class Box {}

    func testSameTitleReusesTheValue() {
        var slot = RetainedSlot<Box>()
        let first = slot.value(for: 7) { Box() }
        let again = slot.value(for: 7) { Box() }
        XCTAssertTrue(first === again)
    }

    func testAnotherTitleReplacesIt() {
        var slot = RetainedSlot<Box>()
        let first = slot.value(for: 7) { Box() }
        let other = slot.value(for: 8) { Box() }
        XCTAssertFalse(first === other)
        XCTAssertEqual(slot.id, 8)
    }

    func testClosingDropsIt() {
        var slot = RetainedSlot<Box>()
        let first = slot.value(for: 7) { Box() }
        slot.keep(only: nil)
        XCTAssertNil(slot.value)
        let reopened = slot.value(for: 7) { Box() }
        XCTAssertFalse(first === reopened, "reopening a title starts fresh, as on the web")
    }

    func testKeepingTheOpenTitleKeepsIt() {
        var slot = RetainedSlot<Box>()
        let first = slot.value(for: 7) { Box() }
        slot.keep(only: 7)
        XCTAssertTrue(slot.value === first)
    }

    func testGateFollowsTheSplit() {
        var gate = DetailHostGate()
        XCTAssertTrue(gate.accepts(.sheet))
        XCTAssertFalse(gate.accepts(.column))
        gate.update(splitsWithTitle: true)
        XCTAssertTrue(gate.accepts(.column))
        XCTAssertFalse(gate.accepts(.sheet), "the leaving sheet's teardown must not close the store's sheets")
        gate.update(splitsWithTitle: false)
        XCTAssertTrue(gate.accepts(.sheet))
    }

    func testDraftsRoundTripPerSheet() {
        var bag = DraftBag()
        bag.save("4K remux", for: "add.customEdition")
        bag.save(true, for: "edit.monitored")
        XCTAssertEqual(bag.value("add.customEdition", as: String.self), "4K remux")
        XCTAssertEqual(bag.value("edit.monitored", as: Bool.self), true)
        XCTAssertNil(bag.value("edit.monitored", as: String.self))
        bag.clear(sheet: "add")
        XCTAssertNil(bag.value("add.customEdition", as: String.self))
        XCTAssertEqual(bag.value("edit.monitored", as: Bool.self), true)
    }

    func testClearingASheetDoesNotTouchASimilarPrefix() {
        var bag = DraftBag()
        bag.save(1, for: "edit.x")
        bag.save(2, for: "editor.x")
        bag.clear(sheet: "edit")
        XCTAssertEqual(bag.value("editor.x", as: Int.self), 2)
    }

    func testSheetOfKey() {
        XCTAssertEqual(DraftBag.sheet(of: "search.filters"), "search")
        XCTAssertEqual(DraftBag.sheet(of: "plain"), "plain")
    }

    func testFreshOpen() {
        XCTAssertTrue(DraftBag.isFreshOpen(from: nil as Int?, to: 1))
        XCTAssertTrue(DraftBag.isFreshOpen(from: 1, to: 2))
        XCTAssertFalse(DraftBag.isFreshOpen(from: 1, to: 1))
        XCTAssertFalse(DraftBag.isFreshOpen(from: 1, to: nil as Int?))
    }
}
