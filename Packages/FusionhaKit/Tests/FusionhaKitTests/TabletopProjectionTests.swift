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
        XCTAssertEqual(card.width, 197.8, accuracy: tolerance)
        XCTAssertEqual(card.height, 296.7, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.17, accuracy: tolerance)
        // Floating over the ring's centre (the hinge-fix mock: 125 over the floor).
        XCTAssertEqual(card.centerX, 0, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, 110, accuracy: tolerance)
        XCTAssertEqual(card.lift, 125, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 1, accuracy: tolerance)
        // The slab has no reflection; the shadow under it replaces it.
        XCTAssertEqual(card.reflectionOpacity, 0, accuracy: tolerance)
        XCTAssertEqual(card.ghost, 0, accuracy: tolerance)
        let front = card.corners()
        assertVec(front[0], -97.4743, -421.7, 126.7321)
        assertVec(front[1], 97.4743, -421.7, 93.2679)
        assertVec(front[2], 97.4743, -125, 93.2679)
        assertVec(front[3], -97.4743, -125, 126.7321)
        let slice = card.slice(1)
        assertVec(slice[0], -100.3504, -421.7, 109.9772)
        assertVec(slice[2], 94.5982, -125, 76.5129)
        let mirror = card.corners(mirrored: true)
        assertVec(mirror[0], -97.4743, 421.7, 126.7321)
        assertVec(mirror[2], 97.4743, 125, 93.2679)
        let beam = card.beam
        assertVec(beam[0], -90.988, -184.34, 110)
        assertVec(beam[2], 108, 0, 110)
        // Seen at a 105° hinge: the whole slab on the standing half, its foot
        // 37 pt over the hinge.
        let seen = front.map { TabletopProjection.onScreen($0, phi: phi(105)) }
        assertPoint(seen[0], -108.5511, 328.2987)
        assertPoint(seen[1], 106.856, 344.8683)
        assertPoint(seen[2], 103.0338, 57.546)
        assertPoint(seen[3], -104.6088, 37.1859)
        let halo = card.halo.map { TabletopProjection.onScreen($0, phi: phi(105)) }
        assertPoint(halo[0], -328.0855, 449.2713)
        assertPoint(halo[2], 307.68, -56.8045)
        // The pool of shadow: the halo's plane, 470 either side, 210 over the slab's head.
        let shade = card.shade
        assertVec(shade[0], -470, -631.7, 64)
        assertVec(shade[2], 470, 150, 64)
        XCTAssertEqual(card.shadeOpacity, 1, accuracy: tolerance)
        // The contact shadow on the table, under the ring's centre, breathing with the bob.
        XCTAssertEqual(card.contact.centerX, 0, accuracy: tolerance)
        XCTAssertEqual(card.contact.centerZ, 110, accuracy: tolerance)
        XCTAssertEqual(card.contact.width, 221.536, accuracy: tolerance)
        XCTAssertEqual(card.contact.depth, 75.3222, accuracy: tolerance)
        XCTAssertEqual(card.contactOpacity, 0.9, accuracy: tolerance)
        let up = try XCTUnwrap(TabletopScene.card(offset: 0, bob: 5))
        XCTAssertEqual(up.contact.width, 209.668, accuracy: tolerance)
        XCTAssertEqual(up.contactOpacity, 0.8, accuracy: tolerance)
    }

    /// Nothing solid crosses the hinge: every title, at every place, the
    /// sway's widest, the bob's lowest and every hinge angle, is seen over
    /// the hinge on the standing half (the slab's slices too); the slab's
    /// head stays under the bar (400 pt at most).
    func testNothingSolidCrossesTheHinge() throws {
        var lowest = Double.infinity, slabTop = -Double.infinity
        for degrees in stride(from: 92.0, through: 135, by: 1) {
            let p = phi(degrees)
            for step in -50...50 {
                let offset = Double(step) / 20
                for sway in [-0.24, 0, 0.17, 0.24] {
                    for bob in [-5.0, 0, 5] {
                        guard let card = TabletopScene.card(offset: offset, sway: sway, bob: bob) else { continue }
                        let slices = card.hasSlices ? (0..<TabletopScene.sliceCount).map { card.slice($0) } : []
                        for v in ([card.corners()] + slices).joined() {
                            let y = TabletopProjection.onScreen(v, phi: p).y
                            lowest = min(lowest, y)
                            if step == 0 { slabTop = max(slabTop, y) }
                        }
                    }
                }
            }
        }
        // The least is 26.8 pt, at 123° (the slab at the bob's lowest, turned 0.24).
        XCTAssertGreaterThan(lowest, 26.5)
        XCTAssertLessThan(slabTop, 400)
        // The slab's foot at the bob's lowest and the sway's widest, at each
        // end of the range and the resting angle.
        let low = try XCTUnwrap(TabletopScene.card(offset: 0, sway: TabletopScene.swayReach, bob: -TabletopScene.bobReach))
        for (degrees, least) in [(92.0, 31.4), (105, 28.25), (135, 27.37)] {
            let feet = low.corners()[2...3].map { TabletopProjection.onScreen($0, phi: phi(degrees)).y }
            XCTAssertEqual(feet.min() ?? 0, least, accuracy: 0.01, "\(degrees)°")
        }
    }

    func testWaitingTitlesStandBehindTheHinge() throws {
        let next = try XCTUnwrap(TabletopScene.card(offset: 1))
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

        let back = try XCTUnwrap(TabletopScene.card(offset: -2))
        XCTAssertEqual(back.centerX, -300, accuracy: tolerance)
        XCTAssertEqual(back.centerZ, -140, accuracy: tolerance)
        assertVec(back.corners()[1], -279.2802, -117.3, -106.8413)
        let far = TabletopScene.waiting(2.6)
        XCTAssertEqual(far.x, 362.4, accuracy: tolerance)
        XCTAssertEqual(far.z, -166.4, accuracy: tolerance)

        let fading = try XCTUnwrap(TabletopScene.card(offset: 2.3))
        XCTAssertEqual(fading.opacity, 0.36, accuracy: tolerance)
        XCTAssertNil(TabletopScene.card(offset: 2.6))
        XCTAssertNil(TabletopScene.card(offset: -3))
    }

    func testHalfwayThroughATurn() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0.5))
        XCTAssertEqual(card.focus, 0.5, accuracy: tolerance)
        XCTAssertEqual(card.yaw, 0.2115, accuracy: tolerance)
        XCTAssertEqual(card.centerX, 49, accuracy: tolerance)
        XCTAssertEqual(card.centerZ, 18, accuracy: tolerance)
        XCTAssertEqual(card.width, 138, accuracy: tolerance)
        XCTAssertEqual(card.lift, 62.5, accuracy: tolerance)
        XCTAssertEqual(card.opacity, 0.8, accuracy: tolerance)
        assertVec(card.corners()[0], -18.462, -269.5, 32.4874)
        assertVec(card.slice(1)[0], -20.2466, -269.5, 24.1769)
    }

    func testFloorBehindTheHinge() {
        let seen = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(105)) }
        assertPoint(seen[0], -422.601, 219.1732)
        assertPoint(seen[1], 422.601, 219.1732)
        assertPoint(seen[2], 501.75, 0)
        assertPoint(seen[3], -501.75, 0)
        let wide = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(130)) }
        assertPoint(wide[0], -439.663, 216.7866)
    }

    /// The floor behind the hinge runs off both sides of the display at every
    /// hinge angle, so its sides never draw an edge on the wall.
    func testFloorBehindOutrunsTheDisplay() {
        XCTAssertEqual(TabletopScene.floorBehindWidth, 1003.5, accuracy: tolerance)
        let display = TabletopProjection.designWidth / 2
        for degrees in [92.0, 105, 120, 135] {
            let back = TabletopScene.floorBehind.map { TabletopProjection.onScreen($0, phi: phi(degrees)) }
            XCTAssertLessThan(back[0].x, -display - 60, "\(degrees)°")
            XCTAssertGreaterThan(back[1].x, display + 60, "\(degrees)°")
        }
    }
}
