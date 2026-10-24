import XCTest
@testable import FusionhaKit

/// The open Duo's gestures (owner-approved 2026-10-24).
final class DuoSwipeTests: XCTestCase {
    func testCommitsPastAThirdOrOnAFling() {
        XCTAssertFalse(DuoSwipe.commits(translation: 100, predicted: 150, extent: 560))
        XCTAssertTrue(DuoSwipe.commits(translation: 170, predicted: 170, extent: 560))
        XCTAssertTrue(DuoSwipe.commits(translation: 60, predicted: 300, extent: 560))
        XCTAssertFalse(DuoSwipe.commits(translation: -200, predicted: 400, extent: 560))
        XCTAssertFalse(DuoSwipe.commits(translation: 10, predicted: 10, extent: 0))
    }

    func testPullPastTheTopClosesAtTheThreshold() {
        XCTAssertEqual(DuoSwipe.pullProgress(overscroll: -30), 0)
        XCTAssertEqual(DuoSwipe.pullProgress(overscroll: 40), 0.5)
        XCTAssertEqual(DuoSwipe.pullProgress(overscroll: DuoSwipe.pullClose), 1)
        XCTAssertEqual(DuoSwipe.pullProgress(overscroll: 400), 1)
    }

    func testHorizontalNeedsAClearSidewaysLead() {
        XCTAssertTrue(DuoSwipe.isHorizontal(dx: 40, dy: 10))
        XCTAssertTrue(DuoSwipe.isHorizontal(dx: -40, dy: 20))
        XCTAssertFalse(DuoSwipe.isHorizontal(dx: 40, dy: 30))
        XCTAssertFalse(DuoSwipe.isHorizontal(dx: 8, dy: 0))
    }

    func testEdgeSwipeRightClosesOrBringsTheListBackFirst() {
        XCTAssertEqual(DuoSwipe.edgeAction(dx: 80, listHidden: false, canHideList: true, canClose: true), .closePage)
        XCTAssertEqual(DuoSwipe.edgeAction(dx: 80, listHidden: true, canHideList: true, canClose: true), .showList)
        // Something pushed inside the page: the system Back owns the edge.
        XCTAssertEqual(DuoSwipe.edgeAction(dx: 80, listHidden: false, canHideList: true, canClose: false), .none)
    }

    func testEdgeSwipeLeftHidesTheListOnlyWhenItCan() {
        XCTAssertEqual(DuoSwipe.edgeAction(dx: -80, listHidden: false, canHideList: true, canClose: true), .hideList)
        XCTAssertEqual(DuoSwipe.edgeAction(dx: -80, listHidden: true, canHideList: true, canClose: true), .none)
        // Book pose: the list never hides.
        XCTAssertEqual(DuoSwipe.edgeAction(dx: -80, listHidden: false, canHideList: false, canClose: true), .none)
    }

    func testNeighborWalksTheGridOrderAndStopsAtTheEnds() {
        let order = [7, 3, 9]
        XCTAssertEqual(DuoSwipe.neighbor(of: 3, in: order, step: 1), 9)
        XCTAssertEqual(DuoSwipe.neighbor(of: 3, in: order, step: -1), 7)
        XCTAssertNil(DuoSwipe.neighbor(of: 9, in: order, step: 1))
        XCTAssertNil(DuoSwipe.neighbor(of: 7, in: order, step: -1))
        XCTAssertNil(DuoSwipe.neighbor(of: 42, in: order, step: 1))
    }

    func testReopenWindowIsFiveMinutes() {
        let closed = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(DuoSwipe.canReopen(closedAt: closed, now: closed.addingTimeInterval(299)))
        XCTAssertFalse(DuoSwipe.canReopen(closedAt: closed, now: closed.addingTimeInterval(301)))
        XCTAssertFalse(DuoSwipe.canReopen(closedAt: closed, now: closed.addingTimeInterval(-1)))
    }
}
