import XCTest
@testable import FusionhaKit

/// The tabletop hologram's maths against the approved mock's own numbers
/// (its `onScreen`, `onFloor`, `quad` and `drawHolo`, run in JavaScript).
final class TabletopProjectionTests: XCTestCase {
    private let tolerance = 1e-3

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

    func testEye() {
        assertVec(TabletopProjection.eye, 0, -1342.063, 1989.6902)
    }

    func testOnScreen() {
        let p = TabletopProjection.self
        assertPoint(p.onScreen(TabletopVec(0, 0, 0), phi: phi(105)), 0, 0)
        assertPoint(p.onScreen(TabletopVec(100, -200, -150), phi: phi(105)), 96.058, 253.6637)
        assertPoint(p.onScreen(TabletopVec(-334.5, 0, -440), phi: phi(105)), -281.734, 219.1732)
        assertPoint(p.onScreen(TabletopVec(0, -322, 110), phi: phi(105)), 0, 237.0844)
        assertPoint(p.onScreen(TabletopVec(120, -50, 60), phi: phi(130)), 124.0594, 8.2126)
        assertPoint(p.onScreen(TabletopVec(0, -100, -100), phi: phi(92)), 0, 156.2909)
    }

    func testOnFloor() {
        let p = TabletopProjection.self
        assertPoint(p.onFloor(TabletopVec(0, 0, 50)), 0, 50)
        assertPoint(p.onFloor(TabletopVec(0, -34, 50)), 0, -0.4177)
        assertPoint(p.onFloor(TabletopVec(96.6, -322.6, 110)), 127.1682, -484.8113)
        assertPoint(p.onFloor(TabletopVec(-80, -20, -30)), -81.2102, -60.5536)
        assertPoint(p.onFloor(TabletopVec(50, 120, 40)), 45.8962, 200.0224)
    }

    func testHomography() {
        let quad = [TabletopPoint(237.9, 96.4), TabletopPoint(431.1, 96.4),
                    TabletopPoint(427.6, 372.2), TabletopPoint(241.4, 372.2)]
        let got = TabletopProjection.homography(width: 230, height: 345, quad: quad)
        let want = [0.84, 0.03644982, 237.9, 0, 0.83997821, 96.4, 0, 0.00010896807]
        XCTAssertEqual(got.count, 8)
        for (g, w) in zip(got, want) { XCTAssertEqual(g, w, accuracy: 1e-6) }
        // The coefficients carry each corner of the box onto the quad.
        let box = [(0.0, 0.0), (230.0, 0.0), (230.0, 345.0), (0.0, 345.0)]
        for (corner, target) in zip(box, quad) {
            let (x, y) = corner
            let w = got[6] * x + got[7] * y + 1
            XCTAssertEqual((got[0] * x + got[1] * y + got[2]) / w, target.x, accuracy: tolerance)
            XCTAssertEqual((got[3] * x + got[4] * y + got[5]) / w, target.y, accuracy: tolerance)
        }
    }

    func testAStandingThingMeetsItselfAtTheHinge() {
        // A point on the hinge line is seen at the same x on both halves, at the hinge.
        for hinge in [92.0, 105, 130] {
            let onLine = TabletopVec(57, 0, 0)
            assertPoint(TabletopProjection.onScreen(onLine, phi: phi(hinge)), 57, 0)
            assertPoint(TabletopProjection.onFloor(onLine), 57, 0)
        }
    }

    func testHingeAngle() {
        let p = TabletopProjection.self
        XCTAssertEqual(p.phi(hingeDegrees: 105), 15 * Double.pi / 180, accuracy: 1e-9)
        XCTAssertEqual(p.phi(hingeDegrees: 60), 2 * Double.pi / 180, accuracy: 1e-9)
        XCTAssertEqual(p.phi(hingeDegrees: 180), 45 * Double.pi / 180, accuracy: 1e-9)
        XCTAssertEqual(p.phi(hingeDegrees: .nan), 15 * Double.pi / 180, accuracy: 1e-9)
        XCTAssertEqual(p.heldHinge(115), 115, accuracy: 1e-9)
        XCTAssertEqual(p.heldHinge(170), 135, accuracy: 1e-9)
        XCTAssertEqual(p.heldHinge(20), 92, accuracy: 1e-9)
        XCTAssertEqual(p.heldHinge(.infinity), 105, accuracy: 1e-9)
    }

    func testContains() {
        let quad = [TabletopPoint(0, 0), TabletopPoint(10, 1), TabletopPoint(9, 12), TabletopPoint(-1, 10)]
        XCTAssertTrue(TabletopProjection.contains(quad, TabletopPoint(5, 5)))
        XCTAssertFalse(TabletopProjection.contains(quad, TabletopPoint(11, 5)))
        XCTAssertFalse(TabletopProjection.contains(quad, TabletopPoint(5, -1)))
        XCTAssertTrue(TabletopProjection.contains(Array(quad.reversed()), TabletopPoint(5, 5)))
    }

    // MARK: The scene

    func testFocusedSlab() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0))
        XCTAssertEqual(card.focus, 1, accuracy: tolerance)
        XCTAssertEqual(card.width, 220.8, accuracy: tolerance)
        XCTAssertEqual(card.height, 331.2, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.17, accuracy: tolerance)
        XCTAssertEqual(card.lift, 22, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 1, accuracy: tolerance)
        XCTAssertEqual(card.reflectionOpacity, 0.82, accuracy: tolerance)
        XCTAssertEqual(card.ghost, 0, accuracy: tolerance)
        let front = card.corners()
        assertVec(front[0], -108.8086, -353.2, 128.6777)
        assertVec(front[1], 108.8086, -353.2, 91.3223)
        assertVec(front[2], 108.8086, -22, 91.3223)
        assertVec(front[3], -108.8086, -22, 128.6777)
        let slice = card.slice(1)
        assertVec(slice[0], -111.6847, -353.2, 111.9228)
        assertVec(slice[2], 105.9325, -22, 74.5673)
        let mirror = card.corners(mirrored: true)
        assertVec(mirror[0], -108.8086, 353.2, 128.6777)
        assertVec(mirror[2], 108.8086, 22, 91.3223)
        let beam = card.beam
        assertVec(beam[0], -101.568, -88.24, 110)
        assertVec(beam[2], 108, 0, 110)
        // Seen at a 105° hinge: its top on the standing half, its foot on the table.
        let seen = front.map { TabletopProjection.onScreen($0, phi: phi(105)) }
        assertPoint(seen[0], -120.2381, 258.123)
        assertPoint(seen[1], 118.1618, 277.6575)
        assertPoint(seen[2], 113.5056, -36.2183)
        let floor = front.map(TabletopProjection.onFloor)
        assertPoint(floor[2], 110.6219, 59.6843)
        assertPoint(floor[3], -110.6219, 97.6623)
        let halo = card.halo.map { TabletopProjection.onScreen($0, phi: phi(105)) }
        assertPoint(halo[0], -325.306, 380.3375)
        assertPoint(halo[2], 307.68, -56.8045)
        // The pool of shadow: the halo's plane, 470 either side, 210 over the slab's head.
        let shade = card.shade
        assertVec(shade[0], -470, -563.2, 64)
        assertVec(shade[2], 470, 150, 64)
        XCTAssertEqual(card.shadeOpacity, 1, accuracy: tolerance)
    }

    /// The reflection ends before the page dots: the eye sees the last of
    /// the slab's mirror image on the table short of 297 pt from the hinge.
    func testReflectionEndsBeforeTheDots() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0, sway: 0))
        let depth = card.lift + card.height * TabletopScene.reflectionReach
        let end = TabletopProjection.onFloor(TabletopVec(0, depth, card.centerZ))
        XCTAssertGreaterThan(end.y, 240)
        XCTAssertLessThan(end.y, 285)
    }

    func testMarkersOnTheRing() throws {
        let next = try XCTUnwrap(TabletopScene.card(offset: 1))
        XCTAssertEqual(next.focus, 0, accuracy: tolerance)
        XCTAssertEqual(next.yaw, 0.5061, accuracy: tolerance)
        XCTAssertEqual(next.centerX, 145.8643, accuracy: tolerance)
        XCTAssertEqual(next.centerZ, 18.8539, accuracy: tolerance)
        XCTAssertEqual(next.opacity, 0.6, accuracy: tolerance)
        XCTAssertEqual(next.reflectionOpacity, 0.132, accuracy: tolerance)
        XCTAssertFalse(next.hasSlices)
        assertVec(next.corners()[0], 111.6666, -117.3, 37.8099)
        assertVec(next.corners()[2], 180.0619, 0, -0.1022)

        let back = try XCTUnwrap(TabletopScene.card(offset: -2))
        XCTAssertEqual(back.centerX, -154.5926, accuracy: tolerance)
        XCTAssertEqual(back.centerZ, 185.3998, accuracy: tolerance)
        assertVec(back.corners()[1], -133.8727, -117.3, 218.5585)

        let fading = try XCTUnwrap(TabletopScene.card(offset: 2.3))
        XCTAssertEqual(fading.opacity, 0.36, accuracy: tolerance)
        XCTAssertNil(TabletopScene.card(offset: 2.6))
        XCTAssertNil(TabletopScene.card(offset: -3))
    }

    func testHalfwayThroughATurn() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0.5))
        XCTAssertEqual(card.focus, 0.5, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.2115, accuracy: tolerance)
        XCTAssertEqual(card.centerX, 41.6936, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, 34.7827, accuracy: tolerance)
        XCTAssertEqual(card.lift, 11, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 0.8, accuracy: tolerance)
        assertVec(card.corners()[0], -31.3902, -235.25, 50.4774)
        assertVec(card.slice(1)[0], -33.1748, -235.25, 42.1669)
    }

    func testFloorBehindTheHinge() {
        let seen = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(105)) }
        assertPoint(seen[0], -281.734, 219.1732)
        assertPoint(seen[1], 281.734, 219.1732)
        assertPoint(seen[2], 334.5, 0)
        assertPoint(seen[3], -334.5, 0)
        let wide = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(130)) }
        assertPoint(wide[0], -293.1086, 216.7866)
    }
}
