import XCTest
@testable import FusionhaKit

/// The emitter ring as a dial (tabletop plan, slice 6; the hinge-fix mock's
/// `dial` mode): 40° a title, clockwise to the next, followed a little past
/// either end, and only on the band round the rim, clear of the fold.
final class TabletopDialTests: XCTestCase {
    private let tolerance = 1e-9

    private func radians(_ degrees: Double) -> Double { degrees * Double.pi / 180 }

    func testUnwrapTakesTheShortWayRound() {
        XCTAssertEqual(TabletopDial.unwrap(0.1), 0.1, accuracy: tolerance)
        XCTAssertEqual(TabletopDial.unwrap(radians(270)), radians(-90), accuracy: tolerance)
        XCTAssertEqual(TabletopDial.unwrap(radians(-270)), radians(90), accuracy: tolerance)
        XCTAssertEqual(TabletopDial.unwrap(radians(340 + 360)), radians(-20), accuracy: tolerance)
    }

    func testNotchesTurnFortyDegreesATitle() {
        XCTAssertEqual(TabletopDial.turn(at: 0), 0, accuracy: tolerance)
        XCTAssertEqual(TabletopDial.turn(at: 1.5), radians(60), accuracy: tolerance)
        XCTAssertEqual(TabletopDial.notchStep * 2, TabletopDial.detent, accuracy: tolerance)
    }

    func testOnlyTheBandRoundTheRimTakesTheFinger() {
        // Half scale: the rim at 50, taken from 12 inside it to 6 past it.
        let centre = TabletopPoint(200, 300)
        let accepts = { (x: Double, y: Double, fold: Double) in
            TabletopDial.accepts(TabletopPoint(x, y), centre: centre, scale: 0.5, foldBottom: fold)
        }
        XCTAssertTrue(accepts(250, 300, 100))
        XCTAssertTrue(accepts(255, 300, 100))
        XCTAssertTrue(accepts(239, 300, 100))
        XCTAssertFalse(accepts(257, 300, 100))
        XCTAssertFalse(accepts(237, 300, 100))
        XCTAssertFalse(accepts(200, 300, 100), "the ring's middle")
        // The far side of the rim, 50 above the centre: clipped within 20 of the fold.
        XCTAssertTrue(accepts(200, 250, 230))
        XCTAssertFalse(accepts(200, 250, 231))
        XCTAssertFalse(accepts(200, 250, 245))
    }

    func testClockwiseIsNext() {
        let centre = TabletopPoint(0, 0)
        // y down: from the right of the centre to below it is clockwise on the display.
        let right = TabletopDial.angle(of: TabletopPoint(10, 0), centre: centre)
        let below = TabletopDial.angle(of: TabletopPoint(0, 10), centre: centre)
        var drag = TabletopDial.Drag(position: 1, count: 4, angle: right)
        drag.move(to: below)
        XCTAssertEqual(drag.position, 1 + 90.0 / 40, accuracy: tolerance)
        XCTAssertEqual(drag.nearest, 3)
    }

    func testFollowsTheFingerAcrossTheWrap() {
        var drag = TabletopDial.Drag(position: 1, count: 4, angle: radians(170))
        drag.move(to: radians(-175))
        XCTAssertEqual(drag.position, 1 + 15.0 / 40, accuracy: tolerance)
        XCTAssertEqual(drag.nearest, 1)
        drag.move(to: radians(-165))
        XCTAssertEqual(drag.position, 1 + 25.0 / 40, accuracy: tolerance)
        XCTAssertEqual(drag.nearest, 2)
        drag.move(to: radians(170))
        XCTAssertEqual(drag.position, 1, accuracy: tolerance)
    }

    func testFollowsALittlePastEitherEnd() {
        var drag = TabletopDial.Drag(position: 1, count: 4, angle: 0)
        for step in 1...10 { drag.move(to: TabletopDial.unwrap(radians(30 * Double(step)))) }
        XCTAssertEqual(drag.position, 3.3, accuracy: tolerance)
        XCTAssertEqual(drag.nearest, 3)

        var back = TabletopDial.Drag(position: 0, count: 4, angle: 0)
        back.move(to: radians(-90))
        XCTAssertEqual(back.position, -0.3, accuracy: tolerance)
        XCTAssertEqual(back.nearest, 0)
    }
}
