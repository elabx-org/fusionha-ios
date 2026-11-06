import XCTest
@testable import FusionhaKit

final class FoldContinuityTests: XCTestCase {
    // MARK: FoldPick

    func testUnfoldingMovesTheSheetOntoTheRightPage() {
        let open = FoldPick<Int>(picked: nil, sheet: 103).reconciled(splits: true)
        XCTAssertEqual(open, FoldPick(picked: 103, sheet: nil))
    }

    func testFoldingMovesThePickIntoTheSheet() {
        let folded = FoldPick<Int>(picked: 103, sheet: nil).reconciled(splits: false)
        XCTAssertEqual(folded, FoldPick(picked: nil, sheet: 103))
    }

    func testFoldUnfoldFoldKeepsTheSameItem() {
        var pick = FoldPick<String>(picked: "held-7", sheet: nil)
        pick = pick.reconciled(splits: false)
        pick = pick.reconciled(splits: true)
        pick = pick.reconciled(splits: false)
        XCTAssertEqual(pick, FoldPick(picked: nil, sheet: "held-7"))
    }

    func testNothingPickedStaysNothing() {
        XCTAssertEqual(FoldPick<Int>(picked: nil, sheet: nil).reconciled(splits: true), FoldPick(picked: nil, sheet: nil))
        XCTAssertEqual(FoldPick<Int>(picked: nil, sheet: nil).reconciled(splits: false), FoldPick(picked: nil, sheet: nil))
    }

    func testAClosedSheetDoesNotComeBackOnUnfold() {
        // Folded with the pick in its sheet, the sheet closed: nothing to show open.
        var pick = FoldPick<Int>(picked: 5, sheet: nil).reconciled(splits: false)
        pick.sheet = nil
        XCTAssertEqual(pick.reconciled(splits: true), FoldPick(picked: nil, sheet: nil))
    }

    // MARK: FoldRoute

    private enum Page: Hashable { case group(String), file(Int), extra }

    func testFoldingPushesThePickedPage() {
        XCTAssertEqual(FoldRoute.stack(picked: Page.group("missing"), stack: []), [.group("missing")])
        XCTAssertEqual(FoldRoute.stack(picked: Page?.none, stack: []), [])
        // A stack already pushed is kept.
        XCTAssertEqual(FoldRoute.stack(picked: Page.group("a"), stack: [.file(3)]), [.file(3)])
    }

    func testUnfoldingPicksTheDeepestPageTheSplitShows() {
        let shows: (Page) -> Bool = { if case .extra = $0 { return false } else { return true } }
        XCTAssertEqual(FoldRoute.picked(from: [.group("a"), .file(2), .extra], current: nil, shows: shows), .file(2))
        XCTAssertEqual(FoldRoute.picked(from: [], current: .group("b"), shows: shows), .group("b"))
        XCTAssertNil(FoldRoute.picked(from: [Page.extra], current: nil, shows: shows))
    }

    func testRoundTripKeepsThePage() {
        let page = Page.file(9)
        let stack = FoldRoute.stack(picked: page, stack: [])
        XCTAssertEqual(FoldRoute.picked(from: stack, current: nil, shows: { _ in true }), page)
    }

    // MARK: FoldAnchorLog

    func testTheAnchorIsTheRowAtTheTopBeforeTheResize() {
        var log = FoldAnchorLog<Int>()
        log.record(1, at: 10)
        log.record(14, at: 12)
        // The resize at 20 re-flows the list: row 30 reports in the same moment.
        log.record(30, at: 20.01)
        XCTAssertEqual(log.anchor(before: 20), 14)
    }

    func testReportsJustBeforeTheResizeBelongToTheNewLayout() {
        var log = FoldAnchorLog<Int>()
        log.record(14, at: 12)
        // The geometry change is read after the re-flowed rows reported.
        log.record(30, at: 19.98)
        XCTAssertEqual(log.anchor(before: 20), 14)
    }

    func testNoRowYetMeansNoAnchor() {
        let log = FoldAnchorLog<Int>()
        XCTAssertNil(log.anchor(before: 5))
    }

    func testSettleKeepsTheAnchorForTheNextResize() {
        var log = FoldAnchorLog<Int>()
        log.record(14, at: 12)
        log.record(30, at: 20.01)
        let anchor = log.anchor(before: 20)!
        log.settle(anchor, at: 20.2)
        log.record(31, at: 31.01)
        XCTAssertEqual(log.anchor(before: 31), 14)
    }

    func testTheLogStaysShort() {
        var log = FoldAnchorLog<Int>()
        for i in 0..<40 { log.record(i, at: TimeInterval(i)) }
        XCTAssertEqual(log.entries.count, 8)
        XCTAssertEqual(log.anchor(before: 100), 39)
    }

    // MARK: Requests deck

    func testTheDeckOpensOnTheFocusedRequest() {
        var focus = TriageQueueFocus()
        XCTAssertEqual(focus.deckOrder([4, 5, 6, 7]), [4, 5, 6, 7])
        focus.focus(6, in: [4, 5, 6, 7])
        XCTAssertEqual(focus.deckOrder([4, 5, 6, 7]), [6, 7, 4, 5])
    }

    func testADecidedFocusMovesToTheNextCard() {
        var focus = TriageQueueFocus()
        focus.focus(6, in: [4, 5, 6, 7])
        // 6 was decided: the card at its place comes to the front.
        XCTAssertEqual(focus.deckOrder([4, 5, 7]), [7, 4, 5])
        XCTAssertEqual(focus.deckOrder([]), [])
    }
}
