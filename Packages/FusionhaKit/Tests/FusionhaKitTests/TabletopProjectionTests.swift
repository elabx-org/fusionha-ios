import XCTest
@testable import FusionhaKit

/// The tabletop hologram's maths against the approved mock's own numbers
/// (its `onScreen`, `onFloor`, `quad` and `drawHolo`, run in JavaScript;
/// the seat mock's eye and lean). The scene's own layout is in
/// `TabletopSceneTests`.
final class TabletopProjectionTests: XCTestCase {
    private let tolerance = 1e-3
    /// The eye the first mocks were drawn for, and the default seat's.
    private let low = TabletopProjection.eye(elevation: 34)
    private let seated = TabletopProjection.eye(elevation: 50)

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

    func testEyeFollowsTheSeat() {
        let p = TabletopProjection.self
        assertVec(low, 0, -1342.063, 1989.6902)
        assertVec(seated, 0, -1838.5067, 1542.6903)
        // Held to the seat's range, and always 2400 pt from the hinge.
        assertVec(p.eye(elevation: 80), 0, -2225.2413, 899.0558)
        assertVec(p.eye(elevation: 10), 0, -1052.0908, 2157.1057)
        assertVec(p.eye(elevation: .nan), 0, -1838.5067, 1542.6903)
        for seat in stride(from: 26.0, through: 68, by: 7) {
            let eye = p.eye(elevation: seat)
            XCTAssertEqual(hypot(eye.y, eye.z), 2400, accuracy: tolerance)
            XCTAssertEqual(atan2(-eye.y, eye.z) * 180 / Double.pi, seat, accuracy: 1e-9)
        }
        XCTAssertEqual(p.defaultSeat, 50)
        XCTAssertEqual(p.heldSeat(20), 26)
        XCTAssertEqual(p.heldSeat(70), 68)
        XCTAssertEqual(p.heldSeat(52), 52)
    }

    func testOnScreen() {
        let p = TabletopProjection.self
        assertPoint(p.onScreen(TabletopVec(0, 0, 0), phi: phi(105), eye: low), 0, 0)
        assertPoint(p.onScreen(TabletopVec(100, -200, -150), phi: phi(105), eye: low), 96.058, 253.6637)
        assertPoint(p.onScreen(TabletopVec(-334.5, 0, -440), phi: phi(105), eye: low), -281.734, 219.1732)
        assertPoint(p.onScreen(TabletopVec(0, -322, 110), phi: phi(105), eye: low), 0, 237.0844)
        assertPoint(p.onScreen(TabletopVec(120, -50, 60), phi: phi(130), eye: low), 124.0594, 8.2126)
        assertPoint(p.onScreen(TabletopVec(0, -100, -100), phi: phi(92), eye: low), 0, 156.2909)
        assertPoint(p.onScreen(TabletopVec(100, -200, -150), phi: phi(105), eye: seated), 95.4774, 283.773)
        assertPoint(p.onScreen(TabletopVec(0, -322, 110), phi: phi(105), eye: seated), 0, 165.7932)
    }

    func testOnFloor() {
        let p = TabletopProjection.self
        assertPoint(p.onFloor(TabletopVec(0, 0, 50), eye: low), 0, 50)
        assertPoint(p.onFloor(TabletopVec(0, -34, 50), eye: low), 0, -0.4177)
        assertPoint(p.onFloor(TabletopVec(96.6, -322.6, 110), eye: low), 127.1682, -484.8113)
        assertPoint(p.onFloor(TabletopVec(-80, -20, -30), eye: low), -81.2102, -60.5536)
        assertPoint(p.onFloor(TabletopVec(50, 120, 40), eye: low), 45.8962, 200.0224)
        assertPoint(p.onFloor(TabletopVec(0, 0, 50), eye: seated), 0, 50)
        assertPoint(p.onFloor(TabletopVec(0, -34, 50), eye: seated), 0, 21.8752)
        assertPoint(p.onFloor(TabletopVec(96.6, -322.6, 110), eye: seated), 117.1574, -194.8907)
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
        // A point on the hinge line is seen at the same x on both halves, at
        // the hinge, from any seat.
        for hinge in [92.0, 105, 130] {
            for seat in [26.0, 50, 68] {
                let eye = TabletopProjection.eye(elevation: seat), onLine = TabletopVec(57, 0, 0)
                assertPoint(TabletopProjection.onScreen(onLine, phi: phi(hinge), eye: eye), 57, 0)
                assertPoint(TabletopProjection.onFloor(onLine, eye: eye), 57, 0)
            }
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
}
