import XCTest
@testable import FusionhaKit

/// The hologram scene's layout (`TabletopScene`) against the seat mock's own
/// numbers (its `drawHolo` and `pts`, run in JavaScript): the focused card
/// across the hinge leaning back toward the eye, the waiting titles behind
/// the hinge, and the ring and its dial clear of the fold.
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
        XCTAssertEqual(card.width, 220.8, accuracy: tolerance)
        XCTAssertEqual(card.height, 331.2, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.17, accuracy: tolerance)
        // Over the ring's centre, 22 over the floor, leaning 14.4° at seat 50.
        XCTAssertEqual(card.centerX, 0, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, 130, accuracy: tolerance)
        XCTAssertEqual(card.lift, 22, accuracy: tolerance)
        XCTAssertEqual(card.lean * 180 / Double.pi, 14.4, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 1, accuracy: tolerance)
        XCTAssertEqual(card.ghost, 0, accuracy: tolerance)
        // Its reflection is back.
        XCTAssertEqual(card.reflectionOpacity, 0.82, accuracy: tolerance)
        let front = card.corners()
        assertVec(front[0], -108.8086, -342.7947, 66.3116)
        assertVec(front[1], 108.8086, -342.7947, 28.9562)
        assertVec(front[2], 108.8086, -22, 111.3223)
        assertVec(front[3], -108.8086, -22, 148.6777)
        let slice = card.slice(1)
        assertVec(slice[0], -111.6847, -342.7947, 49.5567)
        assertVec(slice[2], 105.9325, -22, 94.5673)
        // The mirror image leans the same way, under the floor.
        let mirror = card.corners(mirrored: true)
        assertVec(mirror[0], -108.8086, 342.7947, 66.3116)
        assertVec(mirror[2], 108.8086, 22, 111.3223)
        // The beam's top, the halo and the shade follow the lean.
        let beam = card.beam
        assertVec(beam[0], -101.568, -86.1589, 113.5268)
        assertVec(beam[2], 90, 0, 130)
        assertVec(card.halo[0], -300, -432.7947, 1.6339)
        assertVec(card.halo[2], 300, 20, 1.6339)
        assertVec(card.shade[0], -470, -552.7947, 1.6339)
        assertVec(card.shade[2], 470, 150, 1.6339)
        XCTAssertEqual(card.shadeOpacity, 1, accuracy: tolerance)
    }

    func testLeansBackTowardTheEye() throws {
        XCTAssertEqual(TabletopScene.lean(seat: 34), 0)
        XCTAssertEqual(TabletopScene.lean(seat: 26), 0)
        XCTAssertEqual(TabletopScene.lean(seat: 52) * 180 / Double.pi, 16.2, accuracy: 1e-9)
        XCTAssertEqual(TabletopScene.lean(seat: 90), TabletopScene.lean(seat: 68))

        // At seat 34 it stands upright: its top edge straight over its foot.
        let upright = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 34))
        XCTAssertEqual(upright.rise, upright.height, accuracy: tolerance)
        XCTAssertEqual(upright.setBack, 0, accuracy: tolerance)
        assertVec(upright.corners()[0], -108.8086, -353.2, 148.6777)

        // At seat 52: the top edge at lift + h·cos 16.2° and h·sin 16.2° back
        // toward the hinge; the bottom edge where it was.
        let leaned = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 52))
        XCTAssertEqual(leaned.rise, 318.0493, accuracy: tolerance)
        XCTAssertEqual(leaned.setBack, 92.4019, accuracy: tolerance)
        let top = leaned.corners(), foot = upright.corners()
        assertVec(top[0], -108.8086, -340.0493, 56.2759)
        assertVec(top[1], 108.8086, -340.0493, 18.9204)
        XCTAssertEqual(top[0].z, foot[0].z - 92.4019, accuracy: tolerance)
        XCTAssertEqual(top[2], foot[2])
        XCTAssertEqual(top[3], foot[3])

        // Half way to the focus it leans half as far.
        let turning = try XCTUnwrap(TabletopScene.card(offset: 0.5, seat: 52))
        XCTAssertEqual(turning.lean * 180 / Double.pi, 8.1, accuracy: tolerance)
        // A waiting title stands upright whatever the seat.
        XCTAssertEqual(try XCTUnwrap(TabletopScene.card(offset: 1, seat: 68)).lean, 0)
    }

    /// The card is the illusion: seen from the seat it is drawn for, its foot
    /// lands on the table and its head on the standing half.
    func testFocusedCardStandsAcrossTheHinge() throws {
        let eye = TabletopProjection.eye(elevation: 50)
        let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50))
        let corners = card.corners()
        // Seat 50, hinge 105.
        let head = corners[0...1].map { TabletopProjection.onScreen($0, phi: phi(105), eye: eye) }
        let foot = corners[2...3].map { TabletopProjection.onFloor($0, eye: eye) }
        assertPoint(head[0], -117.9764, 224.4175)
        assertPoint(head[1], 115.6745, 257.1767)
        assertPoint(foot[0], 110.1264, 93.9867)
        assertPoint(foot[1], -110.1264, 131.7946)
        // Over the hinge range, the sway and the bob: the foot at least 82 pt
        // out on the table, the head at least 183 pt up the standing half.
        for degrees in stride(from: 92.0, through: 135, by: 1) {
            for sway in [-0.24, 0, 0.17, 0.24] {
                for bob in [-5.0, 0, 5] {
                    let moving = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50, sway: sway, bob: bob)).corners()
                    for v in moving[0...1] {
                        XCTAssertGreaterThan(TabletopProjection.onScreen(v, phi: phi(degrees), eye: eye).y, 183)
                    }
                    for v in moving[2...3] { XCTAssertGreaterThan(TabletopProjection.onFloor(v, eye: eye).y, 82) }
                }
            }
        }
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
        XCTAssertEqual(card.centerZ, 28, accuracy: tolerance)
        XCTAssertEqual(card.width, 149.5, accuracy: tolerance)
        XCTAssertEqual(card.lift, 11, accuracy: tolerance)
        XCTAssertEqual(card.lean * 180 / Double.pi, 7.2, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 0.8, accuracy: tolerance)
        assertVec(card.corners()[0], -24.0838, -233.4817, 15.5887)
        assertVec(card.slice(1)[0], -25.8685, -233.4817, 7.2782)
    }

    func testFloorBehindTheHinge() {
        let low = TabletopProjection.eye(elevation: 34)
        let seen = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(105), eye: low) }
        assertPoint(seen[0], -422.601, 219.1732)
        assertPoint(seen[1], 422.601, 219.1732)
        assertPoint(seen[2], 501.75, 0)
        assertPoint(seen[3], -501.75, 0)
        let wide = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(130), eye: low) }
        assertPoint(wide[0], -439.663, 216.7866)
    }

    /// The floor behind the hinge runs off both sides of the display at every
    /// hinge angle and every seat, so its sides never draw an edge on the
    /// wall (60 pt off at the 34° seat; 11 pt at the least, seat 68).
    func testFloorBehindOutrunsTheDisplay() {
        XCTAssertEqual(TabletopScene.floorBehindWidth, 1003.5, accuracy: tolerance)
        let display = TabletopProjection.designWidth / 2
        for seat in [26.0, 34, 50, 68] {
            let eye = TabletopProjection.eye(elevation: seat), margin = seat == 34 ? 60.0 : 10
            for degrees in stride(from: 92.0, through: 135, by: 1) {
                let back = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(degrees), eye: eye) }
                XCTAssertLessThan(back[0].x, -display - margin, "\(seat)°, \(degrees)°")
                XCTAssertGreaterThan(back[1].x, display + margin, "\(seat)°, \(degrees)°")
            }
        }
    }
}
