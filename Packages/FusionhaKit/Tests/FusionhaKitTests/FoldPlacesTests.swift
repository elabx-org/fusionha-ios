import XCTest
@testable import FusionhaKit

final class FoldPlacesTests: XCTestCase {
    // MARK: FoldHeaderOffset

    func testBelowTheHeaderKeepsTheDistancePastItsFoot() {
        // Folded: a 300pt hero, scrolled 500 (200 into the tabs).
        let place = FoldHeaderOffset.place(offset: 500, header: 300)
        XCTAssertEqual(place, .below(200))
        // Open: a 120pt header, so the same content sits at 320.
        XCTAssertEqual(place.offset(header: 120), 320)
    }

    func testInsideTheHeaderKeepsTheFraction() {
        let place = FoldHeaderOffset.place(offset: 150, header: 300)
        XCTAssertEqual(place, .inHeader(fraction: 0.5))
        XCTAssertEqual(place.offset(header: 120), 60)
    }

    func testAtTheTopStaysAtTheTop() {
        XCTAssertEqual(FoldHeaderOffset.place(offset: 0, header: 300).offset(header: 120), 0)
        XCTAssertEqual(FoldHeaderOffset.place(offset: -40, header: 300).offset(header: 120), 0)
    }

    func testFoldAndUnfoldComesBackToTheSameOffset() {
        let folded = FoldHeaderOffset.place(offset: 640, header: 300)
        let open = folded.offset(header: 120)
        let back = FoldHeaderOffset.place(offset: open, header: 120).offset(header: 300)
        XCTAssertEqual(back, 640)
    }

    func testAnUnmeasuredHeaderCountsAsBelow() {
        XCTAssertEqual(FoldHeaderOffset.place(offset: 80, header: 0), .below(80))
    }

    // MARK: FoldPagePlaces

    func testPushingOrAFoldKeepsEveryPlace() {
        XCTAssertEqual(FoldPagePlaces.drop(from: 1, to: 2), .none)
        XCTAssertEqual(FoldPagePlaces.drop(from: 2, to: 2), .none)
    }

    func testBackToTheTitleDropsEveryPlace() {
        XCTAssertEqual(FoldPagePlaces.drop(from: 1, to: 0), .all)
        XCTAssertEqual(FoldPagePlaces.drop(from: 2, to: 0), .all)
    }

    func testBackToTheSeasonDropsTheEpisodes() {
        XCTAssertEqual(FoldPagePlaces.drop(from: 2, to: 1), .top)
    }

    // MARK: AllTitlesPush

    func testATapPushesOnce() {
        var push = AllTitlesPush()
        XCTAssertTrue(push.open())
        XCTAssertFalse(push.open())
        XCTAssertTrue(push.wanted)
        XCTAssertTrue(push.presented)
    }

    func testBackPopsOnceAndStaysPopped() {
        var push = AllTitlesPush()
        push.open()
        XCTAssertTrue(push.stackSet(false))
        XCTAssertFalse(push.wanted)
        XCTAssertFalse(push.presented)
        // A second write, or Home checking for a dropped push, changes nothing.
        XCTAssertFalse(push.stackSet(false))
        XCTAssertFalse(push.dropped(pageOnScreen: false))
        XCTAssertFalse(push.reassert())
        XCTAssertFalse(push.presented)
    }

    func testTheStackNeverPushesOnItsOwn() {
        var push = AllTitlesPush()
        XCTAssertFalse(push.stackSet(true))
        XCTAssertFalse(push.wanted)
    }

    func testADroppedPushIsPutBackWithoutClosing() {
        var push = AllTitlesPush()
        push.open()
        XCTAssertFalse(push.dropped(pageOnScreen: true))
        XCTAssertTrue(push.dropped(pageOnScreen: false))
        push.withdraw()
        XCTAssertTrue(push.wanted)
        XCTAssertFalse(push.presented)
        // The stack echoing the withdrawn binding is not a pop.
        XCTAssertFalse(push.stackSet(false))
        // A tap meanwhile doesn't push a second time.
        XCTAssertFalse(push.open())
        XCTAssertTrue(push.reassert())
        XCTAssertTrue(push.presented)
        XCTAssertFalse(push.reassert())
    }

    func testClosedWhileBeingPutBackStaysClosed() {
        var push = AllTitlesPush()
        push.open()
        push.withdraw()
        push.close()
        XCTAssertFalse(push.reassert())
        XCTAssertFalse(push.presented)
    }
}
