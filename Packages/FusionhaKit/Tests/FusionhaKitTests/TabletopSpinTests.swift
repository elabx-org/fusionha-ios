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

    /// Over a whole turn the slab is edge-on at 90° and 270°: undrawn, its
    /// near edge reached 27 pt below the hinge as the eye sees it. It draws
    /// back toward the hinge by what the turn brings it forward
    /// (`TabletopScene.drawBack`), so at every hinge angle and every turn it
    /// is never lower over the hinge than facing the viewer (26.8 pt, at
    /// 123°). Its far top corner goes higher while it is edge-on (the slab's
    /// whole width is then depth): about 450 pt up at 92°, against 395 facing.
    func testASpinNeverDipsBelowTheSlabFacingTheViewer() {
        var lowest = Double.infinity, facing = Double.infinity
        var top = -Double.infinity, facingTop = -Double.infinity
        for degrees in stride(from: 92.0, through: 135, by: 1) {
            let phi = (degrees - 90) * Double.pi / 180
            for turn in 0..<360 {
                for sway in [-0.24, 0, 0.24] {
                    for bob in [-5.0, 0, 5] {
                        let spin = Double(turn) * Double.pi / 180
                        guard let card = TabletopScene.card(offset: 0, sway: sway + spin, bob: bob) else { continue }
                        let slices = (0..<TabletopScene.sliceCount).map { card.slice($0) }
                        for v in ([card.corners()] + slices).joined() {
                            let y = TabletopProjection.onScreen(v, phi: phi).y
                            lowest = min(lowest, y)
                            top = max(top, y)
                            if turn == 0 {
                                facing = min(facing, y)
                                facingTop = max(facingTop, y)
                            }
                        }
                    }
                }
            }
        }
        print("Spin over a whole turn: least \(lowest) pt over the hinge (facing \(facing)); top \(top) pt (facing \(facingTop))")
        XCTAssertGreaterThan(facing, 26.5)
        XCTAssertGreaterThanOrEqual(lowest, facing - 0.01)
        XCTAssertLessThan(facingTop, 400)
        XCTAssertEqual(top, 449.9, accuracy: 1)
    }

    func testDrawsBackOnlyPastTheIdleSway() {
        let hw = 100.0, depth = 34.0
        XCTAssertEqual(TabletopScene.drawBack(yaw: 0, halfWidth: hw, sliceDepth: depth), 0)
        XCTAssertEqual(TabletopScene.drawBack(yaw: -0.24, halfWidth: hw, sliceDepth: depth), 0)
        let near = hw * sin(0.24)
        XCTAssertEqual(TabletopScene.drawBack(yaw: Double.pi / 2, halfWidth: hw, sliceDepth: depth), hw - near, accuracy: tolerance)
        // Back to front, the slices are in front of the poster.
        XCTAssertEqual(TabletopScene.drawBack(yaw: Double.pi, halfWidth: hw, sliceDepth: depth), depth - near, accuracy: tolerance)
    }
}
