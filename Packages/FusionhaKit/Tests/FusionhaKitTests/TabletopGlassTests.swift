import XCTest
@testable import FusionhaKit

/// "At the fold" (`TabletopGlass`): the slab stands in the upright screen's
/// plane, its foot 22 pt up from the hinge, at 0.96, upright; a turn moves it
/// back into the glass rather than up, and its head stays under the cap.
final class TabletopGlassTests: XCTestCase {
    private let tolerance = 1e-3

    private func phi(_ hinge: Double) -> Double { (hinge - 90) * Double.pi / 180 }

    func testFacingStraightOutItStandsOnTheGlass() throws {
        let card = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: 50, hinge: 105, sway: 0))
        XCTAssertEqual(card.width, 220.8, accuracy: tolerance)
        XCTAssertEqual(card.height, 331.2, accuracy: tolerance)
        XCTAssertEqual(card.lean, 0)
        XCTAssertEqual(card.tilt, phi(105), accuracy: tolerance)
        // In the screen's plane, a point is drawn where it is: 22 pt up for
        // the foot, 22 + 331.2 for the head, from any seat.
        for seat in [26.0, 50, 68] {
            let eye = TabletopProjection.eye(elevation: seat)
            let seen = card.corners().map { TabletopProjection.onScreen($0, phi: phi(105), eye: eye) }
            XCTAssertEqual(seen[0].x, -110.4, accuracy: tolerance)
            XCTAssertEqual(seen[0].y, 353.2, accuracy: tolerance)
            XCTAssertEqual(seen[2].x, 110.4, accuracy: tolerance)
            XCTAssertEqual(seen[2].y, 22, accuracy: tolerance)
        }
    }

    /// At its resting turn its near edge would come out of the glass, so it
    /// goes back into the glass by that much (18.7 pt) and its foot stays 22 up.
    func testAtItsRestingTurnItGoesBackIntoTheGlass() throws {
        let card = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: 50, hinge: 105))
        XCTAssertEqual(TabletopGlass.footRise(yaw: TabletopScene.restingSway, width: 220.8, height: 331.2,
                                              seat: 50, hinge: 105), 22, accuracy: tolerance)
        XCTAssertEqual(TabletopGlass.shift(yaw: TabletopScene.restingSway, width: 220.8, foot: 22, seat: 50, hinge: 105),
                       -18.6777, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, -23.7353, accuracy: tolerance)
        XCTAssertEqual(card.lift, 16.4162, accuracy: tolerance)
        let eye = TabletopProjection.eye(elevation: 50)
        let seen = card.corners().map { TabletopProjection.onScreen($0, phi: phi(105), eye: eye) }
        XCTAssertEqual(seen[0].y, 353.2, accuracy: tolerance)
        XCTAssertEqual(seen[1].y, 372.2828, accuracy: tolerance)
        XCTAssertEqual(seen[2].y, 47.2586, accuracy: tolerance)
        XCTAssertEqual(seen[3].y, 22, accuracy: tolerance)
        XCTAssertEqual(TabletopGlass.swayShare, 0.5)
    }

    /// Over a full turn, every seat and hinge and the bob, the foot stays
    /// 22…27 pt up (27 only at the top of the bob: no turn ever lifts it)
    /// and the head stays at most 420 pt up (the card is drawn smaller
    /// where it would go higher).
    func testFootStaysPutAndTheHeadUnderTheCap() throws {
        for seat in stride(from: 26.0, through: 68, by: 6) {
            for hinge in stride(from: 92.0, through: 135, by: 7) {
                for turn in stride(from: 0, to: 360, by: 10) {
                    let yaw = Double(turn) * Double.pi / 180
                    for bob in [-TabletopScene.bobReach, 0, TabletopScene.bobReach] {
                        let k = TabletopGlass.fitScale(yaw: yaw, seat: seat, hinge: hinge, bob: bob)
                        let foot = TabletopGlass.footRise(yaw: yaw, width: 230 * k, height: 345 * k,
                                                          seat: seat, hinge: hinge, bob: bob)
                        XCTAssertGreaterThanOrEqual(foot, 22 - tolerance)
                        XCTAssertLessThanOrEqual(foot, 22 + max(0, bob) + tolerance)
                        let card = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: seat, hinge: hinge, sway: yaw, bob: bob))
                        let seen = TabletopGlass.seen(card, seat: seat, hinge: hinge)
                        XCTAssertLessThanOrEqual(seen.high, TabletopScene.slabTopCap + tolerance)
                        XCTAssertGreaterThanOrEqual(seen.low, 22 - tolerance)
                    }
                }
            }
        }
        // Facing out it is full size; turned edge-on from a high seat it shrinks.
        XCTAssertEqual(TabletopGlass.fitScale(yaw: 0, seat: 68, hinge: 92), 0.96)
        XCTAssertEqual(TabletopGlass.fitScale(yaw: Double.pi / 2, seat: 50, hinge: 105), 0.8711, accuracy: tolerance)
    }

    /// Every seat, hinge, turn and bob: nothing of the slab or its slices is
    /// seen below 20 pt up the standing half, so none of it is on the table half.
    func testNothingIsSeenBelowTheClearance() throws {
        for seat in stride(from: 26.0, through: 68, by: 6) {
            let eye = TabletopProjection.eye(elevation: seat)
            for hinge in stride(from: 92.0, through: 135, by: 7) {
                for turn in stride(from: 0, to: 360, by: 15) {
                    for bob in [-TabletopScene.bobReach, 0, TabletopScene.bobReach] {
                        let card = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: seat, hinge: hinge,
                                                                    sway: Double(turn) * Double.pi / 180, bob: bob))
                        for index in -1..<TabletopScene.sliceCount {
                            let quad = index < 0 ? card.corners() : card.slice(index)
                            for v in quad {
                                let y = TabletopProjection.onScreen(v, phi: phi(hinge), eye: eye).y
                                XCTAssertGreaterThanOrEqual(y, 20 - tolerance, "seat \(seat) hinge \(hinge) turn \(turn)")
                            }
                        }
                    }
                }
            }
        }
    }

    func testWaitingTitlesStandWhereTheyDoAcross() throws {
        for offset in [1.0, -1, 2, -2.3] {
            let glass = try XCTUnwrap(TabletopGlass.card(offset: offset, seat: 50))
            let across = try XCTUnwrap(TabletopScene.card(offset: offset, seat: 50))
            XCTAssertEqual(glass, across)
        }
        XCTAssertNil(TabletopGlass.card(offset: 2.6, seat: 50))
    }

    func testTheChangeOfStyleMovesBetweenTheTwo() throws {
        let across = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50, hinge: 105))
        let glass = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: 50, hinge: 105))
        let start = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: 50, hinge: 105, sway: TabletopScene.restingSway,
                                                     bob: 0, amount: 0))
        let end = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: 50, hinge: 105, sway: TabletopScene.restingSway,
                                                   bob: 0, amount: 1))
        XCTAssertEqual(start, across)
        XCTAssertEqual(end, glass)
        let half = try XCTUnwrap(TabletopGlass.card(offset: 0, seat: 50, hinge: 105, sway: TabletopScene.restingSway,
                                                    bob: 0, amount: 0.5))
        XCTAssertEqual(half.centerZ, (across.centerZ + glass.centerZ) / 2, accuracy: tolerance)
        XCTAssertEqual(half.tilt, glass.tilt / 2, accuracy: tolerance)
        XCTAssertEqual(half.lean, across.lean / 2, accuracy: tolerance)
    }
}
