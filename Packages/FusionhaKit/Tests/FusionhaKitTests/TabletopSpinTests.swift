import XCTest
@testable import FusionhaKit

/// Spinning the floating slab (tabletop plan, slice 6) against the hinge-fix
/// mock's `coast`, run frame by frame in JavaScript: start 0.5 rad at 0.2 rad
/// a frame coasts 85 frames to 4.8557, then eases to 2π and is home at frame 155.
final class TabletopSpinTests: XCTestCase {
    private let tolerance = 1e-4

    func testDragAndSpeed() {
        XCTAssertEqual(TabletopSpin.turn(points: 100), 1.1, accuracy: tolerance)
        XCTAssertEqual(TabletopSpin.velocity(pointsPerSecond: 600), 0.11, accuracy: tolerance)
    }

    func testCoastsSlowsAndSettlesFacingTheViewer() throws {
        let coast = TabletopSpin.Coast(start: 0.5, velocity: 0.2)
        XCTAssertEqual(coast.coastFrames, 85)
        XCTAssertEqual(coast.home, 2 * Double.pi, accuracy: tolerance)
        XCTAssertEqual(try XCTUnwrap(coast.angle(afterFrames: 0)), 0.5, accuracy: tolerance)
        XCTAssertEqual(try XCTUnwrap(coast.angle(afterFrames: 10)), 2.13997, accuracy: tolerance)
        XCTAssertEqual(try XCTUnwrap(coast.angle(afterFrames: 85)), 4.85571, accuracy: tolerance)
        XCTAssertEqual(try XCTUnwrap(coast.angle(afterFrames: 105)), 6.06672, accuracy: tolerance)
        XCTAssertEqual(try XCTUnwrap(coast.angle(afterFrames: 154)), 6.28106, accuracy: tolerance)
        XCTAssertNil(coast.angle(afterFrames: 155))
        XCTAssertNil(coast.angle(afterFrames: 1000))
        XCTAssertEqual(try XCTUnwrap(coast.angle(after: 10 / 60)), 2.13997, accuracy: tolerance)
    }

    func testLetGoStillEasesHome() throws {
        let still = TabletopSpin.Coast(start: 0.3, velocity: 0)
        XCTAssertEqual(still.coastFrames, 0)
        XCTAssertEqual(still.home, 0, accuracy: tolerance)
        XCTAssertEqual(try XCTUnwrap(still.angle(afterFrames: 30)), 0.01772, accuracy: tolerance)
        XCTAssertNil(still.angle(afterFrames: 54))
        XCTAssertEqual(TabletopSpin.Coast(start: -0.5, velocity: -0.2).home, -2 * Double.pi, accuracy: tolerance)
    }

    /// Over a whole turn the slab is edge-on at 90° and 270°, and then its
    /// near edge reaches past the hinge as the eye sees it: the turn is not
    /// clear of the hinge the way the slab facing the viewer is (26.8 pt,
    /// `testNothingSolidCrossesTheHinge`). Measured, not changed (slice 6
    /// keeps `slabLift`): the least is about 27 pt below the hinge, at 92°.
    func testASpinDipsBelowTheHinge() {
        var lowest = Double.infinity, facing = Double.infinity
        for degrees in stride(from: 92.0, through: 135, by: 1) {
            let phi = (degrees - 90) * Double.pi / 180
            for turn in 0..<360 {
                for sway in [-0.24, 0, 0.24] {
                    for bob in [-5.0, 5] {
                        let spin = Double(turn) * Double.pi / 180
                        guard let card = TabletopScene.card(offset: 0, sway: sway + spin, bob: bob) else { continue }
                        let slices = (0..<TabletopScene.sliceCount).map { card.slice($0) }
                        for v in ([card.corners()] + slices).joined() {
                            let y = TabletopProjection.onScreen(v, phi: phi).y
                            lowest = min(lowest, y)
                            if turn == 0 { facing = min(facing, y) }
                        }
                    }
                }
            }
        }
        print("Spin clearance over a whole turn: \(lowest) pt (facing: \(facing) pt)")
        XCTAssertGreaterThan(facing, 26.5)
        XCTAssertEqual(lowest, -27.1, accuracy: 1)
    }
}
