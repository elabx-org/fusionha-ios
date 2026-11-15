import XCTest
@testable import FusionhaKit

/// The hologram scene's layout (`TabletopScene`) against the stage bench's
/// numbers (its `drawHolo` and `pts`, with the draw-back and the per-seat
/// size, run in Python): the focused card floating wholly on the standing
/// half and leaning back toward the eye, the waiting titles behind the
/// hinge, and the ring and its dial clear of the fold.
final class TabletopSceneTests: XCTestCase {
    private let tolerance = 1e-3
    private let seat = TabletopProjection.defaultSeat

    private func phi(_ hinge: Double) -> Double { (hinge - 90) * Double.pi / 180 }

    private func assertPoint(_ p: TabletopPoint, _ x: Double, _ y: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.x, x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(p.y, y, accuracy: tolerance, file: file, line: line)
    }

    private func assertVec(_ v: TabletopVec, _ x: Double, _ y: Double, _ z: Double,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(v.x, x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(v.y, y, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(v.z, z, accuracy: tolerance, file: file, line: line)
    }

    func testFocusedSlab() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: seat))
        XCTAssertEqual(card.focus, 1, accuracy: tolerance)
        // 0.6528 of the card at seat 50 (`heldSlabScale`).
        XCTAssertEqual(card.width, 150.144, accuracy: tolerance)
        XCTAssertEqual(card.height, 225.216, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.17, accuracy: tolerance)
        // Its foot 40 in front of the hinge, drawn back by its resting turn;
        // 40·tan 50° + 52 over the floor; leaning 14.4° at seat 50.
        XCTAssertEqual(card.centerX, 0, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, 27.2991, accuracy: tolerance)
        XCTAssertEqual(card.lift, 99.6701, accuracy: tolerance)
        XCTAssertEqual(card.lean * 180 / Double.pi, 14.4, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 1, accuracy: tolerance)
        XCTAssertEqual(card.ghost, 0, accuracy: tolerance)
        XCTAssertEqual(card.reflectionOpacity, 0.82, accuracy: tolerance)
        let front = card.corners()
        assertVec(front[0], -73.9898, -317.8106, -16.0089)
        assertVec(front[1], 73.9898, -317.8106, -41.4107)
        assertVec(front[2], 73.9898, -99.6701, 14.5983)
        // Its nearest point is exactly `slabZ` in front of the hinge.
        assertVec(front[3], -73.9898, -99.6701, 40)
        let slice = card.slice(1)
        assertVec(slice[0], -76.8659, -317.8106, -32.7639)
        assertVec(slice[2], 71.1137, -99.6701, -2.1567)
        let mirror = card.corners(mirrored: true)
        assertVec(mirror[0], -73.9898, 317.8106, -16.0089)
        assertVec(mirror[2], 73.9898, 99.6701, 14.5983)
        // The beam: as wide as the slab at its foot, down to the emitter's rim.
        let beam = card.beam
        assertVec(beam[0], -75.072, -106.2144, 25.6189)
        assertVec(beam[2], 90, 0, 130)
        assertVec(card.halo[0], -300, -407.8106, -74.7098)
        assertVec(card.halo[2], 300, 20, -74.7098)
    }

    func testLiftScaleAndDrawBack() {
        XCTAssertEqual(TabletopScene.slabLift(seat: 50), 99.6701, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.slabLift(seat: 26), 71.5093, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.slabLift(seat: 90), TabletopScene.slabLift(seat: 68))
        let scales = [20.0, 26, 30, 36, 50, 68, 90].map { TabletopScene.heldSlabScale(seat: $0) }
        for (got, want) in zip(scales, [0.828, 0.828, 0.86, 0.86, 0.6528, 0.3864, 0.3864]) {
            XCTAssertEqual(got, want, accuracy: 1e-9)
        }
        XCTAssertEqual(TabletopScene.forward(yaw: 0, halfWidth: 100, sliceDepth: 34), 0)
        XCTAssertEqual(TabletopScene.forward(yaw: Double.pi / 2, halfWidth: 100, sliceDepth: 34), 100, accuracy: tolerance)
        // Back to front, the slices are in front of the poster.
        XCTAssertEqual(TabletopScene.forward(yaw: Double.pi, halfWidth: 100, sliceDepth: 34), 34, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.forward(yaw: -0.3, halfWidth: 100, sliceDepth: 34), 29.552, accuracy: tolerance)
    }

    func testLeansBackTowardTheEye() throws {
        XCTAssertEqual(TabletopScene.lean(seat: 34), 0)
        XCTAssertEqual(TabletopScene.lean(seat: 26), 0)
        XCTAssertEqual(TabletopScene.lean(seat: 52) * 180 / Double.pi, 16.2, accuracy: 1e-9)
        XCTAssertEqual(TabletopScene.lean(seat: 90), TabletopScene.lean(seat: 68))

        // At seat 34 it stands upright, full size: its top edge straight over its foot.
        let upright = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 34))
        XCTAssertEqual(upright.height, 296.7, accuracy: tolerance)
        XCTAssertEqual(upright.rise, upright.height, accuracy: tolerance)
        XCTAssertEqual(upright.setBack, 0, accuracy: tolerance)
        assertVec(upright.corners()[0], -97.4743, -375.6803, 40)

        // At seat 52: the top edge at lift + h·cos 16.2° and h·sin 16.2° back
        // toward the hinge; the bottom edge stays put.
        let leaned = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 52))
        XCTAssertEqual(leaned.rise, 206.467, accuracy: tolerance)
        XCTAssertEqual(leaned.setBack, 59.9842, accuracy: tolerance)
        let top = leaned.corners()
        assertVec(top[0], -70.6349, -309.6646, -19.9842)
        assertVec(top[1], 70.6349, -309.6646, -44.2341)
        assertVec(top[2], 70.6349, -103.1977, 15.7501)
        XCTAssertEqual(top[3].z, 40, accuracy: tolerance)

        // Half way to the focus it leans half as far.
        let turning = try XCTUnwrap(TabletopScene.card(offset: 0.5, seat: 52))
        XCTAssertEqual(turning.lean * 180 / Double.pi, 8.1, accuracy: tolerance)
        // A waiting title stands upright whatever the seat.
        XCTAssertEqual(try XCTUnwrap(TabletopScene.card(offset: 1, seat: 68)).lean, 0)
    }

    /// Nothing with an edge crosses the fold: at every seat and hinge angle,
    /// with the bob at its lowest and over a whole turn (the idle sway and a
    /// finger's spin), every corner of the slab and its slices is seen at
    /// least 20 pt up the standing half (20.3 at the least: seat 68, hinge
    /// 135, facing the viewer).
    func testSlabStaysWhollyOnTheStandingHalf() throws {
        var lowest = Double.infinity
        for seat in stride(from: 26.0, through: 68, by: 1) {
            let eye = TabletopProjection.eye(elevation: seat)
            for degrees in stride(from: 92.0, through: 135, by: 1) {
                for turn in stride(from: 0, to: 360, by: 2) {
                    let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: seat, sway: Double(turn) * Double.pi / 180,
                                                                bob: -TabletopScene.bobReach))
                    let pieces = [card.corners()] + (0..<TabletopScene.sliceCount).map { card.slice($0) }
                    for v in pieces.joined() {
                        lowest = min(lowest, TabletopProjection.onScreen(v, phi: phi(degrees), eye: eye).y)
                    }
                }
            }
        }
        print("Slab clearance over the hinge: \(lowest) pt")
        XCTAssertGreaterThanOrEqual(lowest, 20)
        XCTAssertEqual(lowest, 20.338, accuracy: 0.01)
    }

    /// Its top at rest (facing, at its still turn either way, bob up) stays
    /// at most 400 pt up the standing half at every seat and hinge angle:
    /// the slab is smaller away from 30°…36° for that (`heldSlabScale`).
    func testSlabTopStaysUnder400() throws {
        var highest = -Double.infinity
        for seat in stride(from: 26.0, through: 68, by: 1) {
            let eye = TabletopProjection.eye(elevation: seat)
            for degrees in stride(from: 92.0, through: 135, by: 1) {
                for sway in [-TabletopScene.restingSway, 0, TabletopScene.restingSway] {
                    let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: seat, sway: sway, bob: TabletopScene.bobReach))
                    let pieces = [card.corners()] + (0..<TabletopScene.sliceCount).map { card.slice($0) }
                    for v in pieces.joined() {
                        highest = max(highest, TabletopProjection.onScreen(v, phi: phi(degrees), eye: eye).y)
                    }
                }
            }
        }
        print("Slab top at rest: \(highest) pt")
        XCTAssertLessThanOrEqual(highest, 400)
    }

    /// Nothing hard of the ring or its dial comes within 20 pt of the hinge:
    /// the bottom half lies flat on the table, so at any hinge angle.
    func testRingAndDialClearTheFold() {
        XCTAssertEqual(TabletopScene.ringZ, 130)
        XCTAssertEqual(TabletopScene.emitterRadius, 100)
        XCTAssertEqual(TabletopDial.notchInner, 99.12, accuracy: tolerance)
        XCTAssertEqual(TabletopDial.notchOuter, 109.76, accuracy: tolerance)
        XCTAssertLessThanOrEqual(TabletopDial.notchOuter, 110)
        XCTAssertGreaterThanOrEqual(TabletopScene.ringZ - TabletopDial.notchOuter, TabletopDial.foldClearance)
        XCTAssertGreaterThanOrEqual(TabletopScene.ringZ - TabletopScene.emitterRadius, TabletopDial.foldClearance)
        XCTAssertEqual(TabletopDial.foldClearance, 20)
    }

    func testWaitingTitlesStandBehindTheHinge() throws {
        let next = try XCTUnwrap(TabletopScene.card(offset: 1, seat: seat))
        XCTAssertEqual(next.focus, 0, accuracy: tolerance)
        XCTAssertEqual(next.yaw, 0.5061, accuracy: tolerance)
        XCTAssertEqual(next.centerX, 196, accuracy: tolerance)
        XCTAssertEqual(next.centerZ, -96, accuracy: tolerance)
        XCTAssertEqual(next.lift, 0, accuracy: tolerance)
        XCTAssertEqual(next.opacity, 0.6, accuracy: tolerance)
        XCTAssertEqual(next.reflectionOpacity, 0.132, accuracy: tolerance)
        XCTAssertFalse(next.hasSlices)
        assertVec(next.corners()[0], 161.8024, -117.3, -77.0439)
        assertVec(next.corners()[2], 230.1976, 0, -114.9561)

        let back = try XCTUnwrap(TabletopScene.card(offset: -2, seat: seat))
        XCTAssertEqual(back.centerX, -300, accuracy: tolerance)
        XCTAssertEqual(back.centerZ, -140, accuracy: tolerance)
        assertVec(back.corners()[1], -279.2802, -117.3, -106.8413)
        let far = TabletopScene.waiting(2.6)
        XCTAssertEqual(far.x, 362.4, accuracy: tolerance)
        XCTAssertEqual(far.z, -166.4, accuracy: tolerance)

        let fading = try XCTUnwrap(TabletopScene.card(offset: 2.3, seat: seat))
        XCTAssertEqual(fading.opacity, 0.36, accuracy: tolerance)
        XCTAssertNil(TabletopScene.card(offset: 2.6, seat: seat))
        XCTAssertNil(TabletopScene.card(offset: -3, seat: seat))
    }

    func testHalfwayThroughATurn() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0.5, seat: seat))
        XCTAssertEqual(card.focus, 0.5, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.2115, accuracy: tolerance)
        XCTAssertEqual(card.centerX, 49, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, -22.993, accuracy: tolerance)
        XCTAssertEqual(card.width, 114.172, accuracy: tolerance)
        XCTAssertEqual(card.lift, 49.8351, accuracy: tolerance)
        XCTAssertEqual(card.lean * 180 / Double.pi, 7.2, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 0.8, accuracy: tolerance)
        assertVec(card.corners()[0], -6.8135, -219.7427, -32.4714)
        assertVec(card.slice(1)[0], -8.5982, -219.7427, -40.7819)
    }

    func testFloorBehindTheHinge() {
        let low = TabletopProjection.eye(elevation: 34)
        let seen = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(105), eye: low) }
        assertPoint(seen[0], -296.622, 157.3331)
        assertPoint(seen[1], 296.622, 157.3331)
        assertPoint(seen[2], 334.5, 0)
        assertPoint(seen[3], -334.5, 0)
        let wide = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(130), eye: low) }
        assertPoint(wide[0], -305.1219, 153.8671)
    }

    /// The floor behind the hinge is the room's: as wide as the display and
    /// as deep as the back wall, so its sides are the side walls' feet.
    func testFloorBehindIsTheRoomsFloor() {
        XCTAssertEqual(TabletopScene.floorBehindWidth, 669, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.floorDepth, 300, accuracy: tolerance)
        let back = TabletopRoom.backVerticals
        XCTAssertEqual(TabletopScene.floorBehind[0], back[0].from)
        XCTAssertEqual(TabletopScene.floorBehind[1], back[TabletopRoom.columns].from)
        XCTAssertEqual(TabletopScene.floorBehind[3], TabletopRoom.sideVerticals[3].from)
    }
}
