import XCTest
@testable import FusionhaKit

final class TriageKeysTests: XCTestCase {
    func testKeysMapToActions() {
        XCTAssertEqual(TriageKeys.action(characters: "a", isReturn: false), .approve)
        XCTAssertEqual(TriageKeys.action(characters: "A", isReturn: false), .approve)
        XCTAssertEqual(TriageKeys.action(characters: "d", isReturn: false), .decline)
        XCTAssertEqual(TriageKeys.action(characters: "j", isReturn: false), .next)
        XCTAssertEqual(TriageKeys.action(characters: "k", isReturn: false), .prev)
        XCTAssertEqual(TriageKeys.action(characters: "x", isReturn: false), .toggle)
        XCTAssertEqual(TriageKeys.action(characters: "", isReturn: true), .open)
        XCTAssertNil(TriageKeys.action(characters: "q", isReturn: false))
    }

    func testModifiersAndRepeatAreIgnored() {
        XCTAssertNil(TriageKeys.action(characters: "a", isReturn: false, command: true))
        XCTAssertNil(TriageKeys.action(characters: "a", isReturn: false, control: true))
        XCTAssertNil(TriageKeys.action(characters: "a", isReturn: false, option: true))
        XCTAssertNil(TriageKeys.action(characters: "a", isReturn: false, isRepeat: true))
        XCTAssertNil(TriageKeys.action(characters: "", isReturn: true, command: true))
    }

    func testGuards() {
        XCTAssertTrue(TriageKeys.allowed(enabled: true, typing: false, overlayOpen: false))
        XCTAssertFalse(TriageKeys.allowed(enabled: true, typing: true, overlayOpen: false))
        XCTAssertFalse(TriageKeys.allowed(enabled: true, typing: false, overlayOpen: true))
        XCTAssertFalse(TriageKeys.allowed(enabled: false, typing: false, overlayOpen: false))
    }

    func testSurfaces() {
        XCTAssertTrue(TriageKeys.accepts(.toggle, on: .panes))
        XCTAssertTrue(TriageKeys.accepts(.toggle, on: .list))
        XCTAssertFalse(TriageKeys.accepts(.next, on: .deck))
        XCTAssertFalse(TriageKeys.accepts(.toggle, on: .deck))
        XCTAssertTrue(TriageKeys.accepts(.open, on: .deck))
        XCTAssertFalse(TriageKeys.accepts(.toggle, on: .card))
        XCTAssertTrue(TriageKeys.accepts(.next, on: .card))
        XCTAssertTrue(TriageKeys.decideOpensCard(on: .list))
        XCTAssertFalse(TriageKeys.decideOpensCard(on: .panes))
    }

    func testFocusMovesAndClamps() {
        var f = TriageQueueFocus()
        let order = [10, 20, 30]
        XCTAssertEqual(f.effective(order), 10)
        f.move(1, in: order)
        XCTAssertEqual(f.effective(order), 20)
        f.move(5, in: order)
        XCTAssertEqual(f.effective(order), 30)
        f.move(-9, in: order)
        XCTAssertEqual(f.effective(order), 10)
        f.move(1, in: [])
        XCTAssertEqual(f.focusId, 10)
    }

    func testDecidedRowHandsFocusToItsSuccessor() {
        var f = TriageQueueFocus()
        f.focus(20, in: [10, 20, 30])
        XCTAssertEqual(f.effective([10, 30]), 30)
        XCTAssertEqual(f.effective([10]), 10)
        XCTAssertNil(f.effective([]))
    }
}
