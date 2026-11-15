import XCTest
@testable import FusionhaKit

/// The hologram scene's layout (`TabletopScene`) against the stage bench's
/// numbers (its `drawHolo` and `pts`, with the draw-back, run in Python):
/// the focused card standing on the table just in front of the hinge and
/// leaning back toward the eye, the waiting titles behind the hinge, and
/// the ring and its dial clear of the fold.
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
        // Full size (0.96 of the card) at every seat.
        XCTAssertEqual(card.width, 220.8, accuracy: tolerance)
        XCTAssertEqual(card.height, 331.2, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.17, accuracy: tolerance)
        // Its foot 45 in front of the hinge, 10 over the table; leaning
        // 14.4° at seat 50.
        XCTAssertEqual(card.centerX, 0, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, 45, accuracy: tolerance)
        XCTAssertEqual(card.lift, 10, accuracy: tolerance)
        XCTAssertEqual(card.lean * 180 / Double.pi, 14.4, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 1, accuracy: tolerance)
        XCTAssertEqual(card.ghost, 0, accuracy: tolerance)
        XCTAssertEqual(card.reflectionOpacity, 0.82, accuracy: tolerance)
        let front = card.corners()
        assertVec(front[0], -108.8086, -330.7947, -18.6884)
        assertVec(front[1], 108.8086, -330.7947, -56.0438)
        assertVec(front[2], 108.8086, -10, 26.3223)
        assertVec(front[3], -108.8086, -10, 63.6777)
        let slice = card.slice(1)
        assertVec(slice[0], -111.6847, -330.7947, -35.4433)
        assertVec(slice[2], 105.9325, -10, 9.5673)
        // The reflection is the card mirrored in the floor, from its foot.
        let mirror = card.corners(mirrored: true)
        assertVec(mirror[0], -108.8086, 330.7947, -18.6884)
        assertVec(mirror[2], 108.8086, 10, 26.3223)
        // The beam: from the emitter's rim to the slab's foot, no higher.
        let beam = card.beam
        assertVec(beam[0], -110.4, -10, 45)
        assertVec(beam[2], 90, 0, 130)
        assertVec(card.halo[0], -300, -420.7947, -83.3661)
        assertVec(card.halo[2], 300, 20, -83.3661)
    }

    func testStandAndDrawBack() throws {
        XCTAssertEqual(TabletopScene.slabZ, 45)
        XCTAssertEqual(TabletopScene.slabLift, 10)
        XCTAssertEqual(TabletopScene.slabScale, 0.96)
        // The same lift at every seat, and full size up to the cap's seats
        // (`TabletopSlabCapTests`).
        for seat in [20.0, 26, 50, 68, 90] {
            XCTAssertEqual(try XCTUnwrap(TabletopScene.card(offset: 0, seat: seat)).lift, 10, accuracy: tolerance)
        }
        for seat in [20.0, 26, 50] {
            let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: seat))
            XCTAssertEqual(card.lift, 10, accuracy: tolerance)
            XCTAssertEqual(card.width, 220.8, accuracy: tolerance)
        }
        // At its resting turn the foot is at `slabZ`; turned further it draws
        // back toward the hinge, facing straight on it comes out, held 8…60.
        let half = 110.4, slices = 34.0
        XCTAssertEqual(TabletopScene.stand(yaw: TabletopScene.restingSway, halfWidth: half, sliceDepth: slices), 45, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.stand(yaw: 0, halfWidth: half, sliceDepth: slices), 60, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.stand(yaw: 0.4, halfWidth: half, sliceDepth: slices), 20.6859, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.stand(yaw: -0.62, halfWidth: half, sliceDepth: slices), 8, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.stand(yaw: Double.pi / 2, halfWidth: half, sliceDepth: slices), 8, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.stand(yaw: Double.pi, halfWidth: half, sliceDepth: slices), 29.6777, accuracy: tolerance)
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

        // At seat 34 it stands upright: its top edge straight over its foot.
        let upright = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 34))
        XCTAssertEqual(upright.height, 331.2, accuracy: tolerance)
        XCTAssertEqual(upright.rise, upright.height, accuracy: tolerance)
        XCTAssertEqual(upright.setBack, 0, accuracy: tolerance)
        assertVec(upright.corners()[0], -108.8086, -341.2, 63.6777)

        // At seat 52: the top edge at lift + h·cos 16.2° and h·sin 16.2° back
        // toward the hinge; the bottom edge where it was.
        let leaned = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 52))
        XCTAssertEqual(leaned.rise, 318.0493, accuracy: tolerance)
        XCTAssertEqual(leaned.setBack, 92.4019, accuracy: tolerance)
        let top = leaned.corners(), foot = upright.corners()
        assertVec(top[0], -108.8086, -328.0493, -28.7241)
        assertVec(top[1], 108.8086, -328.0493, -66.0796)
        XCTAssertEqual(top[2], foot[2])
        XCTAssertEqual(top[3], foot[3])

        // Half way to the focus it leans half as far.
        let turning = try XCTUnwrap(TabletopScene.card(offset: 0.5, seat: 52))
        XCTAssertEqual(turning.lean * 180 / Double.pi, 8.1, accuracy: tolerance)
        // A waiting title stands upright whatever the seat.
        XCTAssertEqual(try XCTUnwrap(TabletopScene.card(offset: 1, seat: 68)).lean, 0)
    }

    /// The card stands just in front of the fold: seen from the seat it is
    /// drawn for (50, hinge 105), its foot lands on the table and its head
    /// on the standing half, and the two pieces meet at the fold, about 35
    /// pt up the card (a tenth of it on the table).
    func testFocusedCardStandsJustInFrontOfTheFold() throws {
        let eye = TabletopProjection.eye(elevation: 50)
        let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50))
        let corners = card.corners()
        let head = corners[0...1].map { TabletopProjection.onScreen($0, phi: phi(105), eye: eye) }
        let foot = corners[2...3].map { TabletopProjection.onFloor($0, eye: eye) }
        assertPoint(head[0], -112.6811, 286.9113)
        assertPoint(head[1], 110.5793, 317.0618)
        assertPoint(foot[0], 109.4036, 18.0293)
        assertPoint(foot[1], -109.4036, 55.5891)
        // Up its middle: still on the table 34 pt up, on the standing half by 36.
        func up(_ s: Double) -> TabletopVec {
            TabletopVec(0, -(card.lift + s * cos(card.lean)), card.centerZ - s * sin(card.lean))
        }
        XCTAssertGreaterThan(TabletopProjection.onFloor(up(34), eye: eye).y, 0)
        XCTAssertLessThan(TabletopProjection.onScreen(up(34), phi: phi(105), eye: eye).y, 0)
        XCTAssertLessThan(TabletopProjection.onFloor(up(36), eye: eye).y, 0)
        XCTAssertGreaterThan(TabletopProjection.onScreen(up(36), phi: phi(105), eye: eye).y, 0)
        // Over the hinge range, the sway and the bob, its head stays at
        // least 240 pt up the standing half.
        for degrees in stride(from: 92.0, through: 135, by: 1) {
            for sway in [-TabletopScene.swayReach, 0, TabletopScene.restingSway, TabletopScene.swayReach] {
                for bob in [-5.0, 0, 5] {
                    let moving = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50, sway: sway, bob: bob)).corners()
                    for v in moving[0...1] {
                        XCTAssertGreaterThan(TabletopProjection.onScreen(v, phi: phi(degrees), eye: eye).y, 240)
                    }
                }
            }
        }
    }

    /// However it turns (the idle sway, a finger's spin) and bobs, at every
    /// seat, the centre of the slab's foot stays 8…60 pt in front of the
    /// hinge: never behind the fold, never out over the ring.
    func testFootStaysJustInFrontOfTheFold() throws {
        var near = Double.infinity, far = -Double.infinity
        for seat in stride(from: 26.0, through: 68, by: 2) {
            for turn in stride(from: 0, to: 360, by: 2) {
                for bob in [-TabletopScene.bobReach, 0, TabletopScene.bobReach] {
                    let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: seat, sway: Double(turn) * Double.pi / 180,
                                                                bob: bob))
                    near = min(near, card.centerZ)
                    far = max(far, card.centerZ)
                    XCTAssertGreaterThanOrEqual(card.lift, 5 - tolerance)
                }
            }
        }
        XCTAssertEqual(near, TabletopScene.slabFootNear, accuracy: tolerance)
        XCTAssertEqual(far, TabletopScene.slabFootFar, accuracy: tolerance)
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
        XCTAssertEqual(card.centerZ, -16.0241, accuracy: tolerance)
        XCTAssertEqual(card.width, 149.5, accuracy: tolerance)
        XCTAssertEqual(card.lift, 5, accuracy: tolerance)
        XCTAssertEqual(card.lean * 180 / Double.pi, 7.2, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 0.8, accuracy: tolerance)
        assertVec(card.corners()[0], -24.0838, -227.4817, -28.4354)
        assertVec(card.slice(1)[0], -25.8685, -227.4817, -36.746)
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
