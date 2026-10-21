import XCTest
@testable import FusionhaKit

/// The web's `living/fusion-dance.test.ts` (v0.4.224), same numbers.
final class FusionDanceTests: XCTestCase {
    typealias D = FusionDance
    typealias T = FusionDance.T

    /// px per box unit (a 170px mark).
    let sPx = 1.7

    private func placed(_ pair: FusionPair, _ side: FusionSide, _ t: Double, _ p: LivingPoly) -> LivingPoly {
        let geo = D.layout(pair, sPx)
        let m = D.pose(t, side, pair, geo).m
        return p.map(m.apply)
    }

    func testSplitsFromTheFAndTravelsToContactInOrder() {
        XCTAssertEqual(D.travel(D.start), 0)
        XCTAssertEqual(D.travel(T.steps[0].1), 0.2, accuracy: 1e-5)
        XCTAssertEqual(D.travel(T.swing.1), 0.72, accuracy: 1e-5)
        XCTAssertEqual(D.travel(T.touch), 1, accuracy: 1e-5)
    }

    func testHoldsTheLeanAtContactWithNoHopSquashOrSwayLeft() {
        let m = D.motion(T.touch)
        XCTAssertEqual(m.tilt, D.leanDeg, accuracy: 1e-5)
        XCTAssertEqual(m.lift, 0, accuracy: 1e-5)
        XCTAssertEqual(m.sx, 1, accuracy: 1e-5)
        XCTAssertEqual(m.sy, 1, accuracy: 1e-5)
    }

    func testLandsTheSecondClapOnContactTheFirstMidDance() {
        XCTAssertEqual(D.clapHits[1], T.touch, accuracy: 1e-5)
        XCTAssertGreaterThan(D.clapHits[0], T.steps[0].0)
        XCTAssertLessThan(D.clapHits[0], T.swing.1)
        XCTAssertEqual(D.clapArm(T.touch), 0)
        XCTAssertEqual(D.clapArm(2.2), -24)
    }

    func testNeverPlaysTheTVsCRTOffOn() {
        var t = D.start
        while t <= D.end {
            let tv = D.tvTime(t)
            XCTAssertTrue(tv < 1700 || tv >= 3050, "t = \(t): \(tv)")
            t += 0.01
        }
    }

    func testInnerEdgesMeetExactlyOnTheCentreLineAtContact() {
        for pair in [FusionPair.media, .quality] {
            let (l, r) = D.outlines(pair, sPx)
            let left = D.edges(placed(pair, .left, T.touch, l))
            let right = D.edges(placed(pair, .right, T.touch, r))
            XCTAssertLessThan(abs(left.max - D.cx), 1, "\(pair)")
            XCTAssertLessThan(abs(right.min - D.cx), 1, "\(pair)")
            XCTAssertLessThanOrEqual(left.max, right.min + 1, "\(pair)")
        }
    }

    func testLeftAndRightMoveAsMirrorImages() {
        for pair in [FusionPair.media, .quality] {
            let geo = D.layout(pair, sPx)
            let (l, r) = D.outlines(pair, sPx)
            // pose A: both inner edges the same distance from the centre line
            let a = T.steps[0].0
            let gl = D.cx - D.edges(placed(pair, .left, a, l)).max
            let gr = D.edges(placed(pair, .right, a, r)).min - D.cx
            XCTAssertGreaterThan(gl, 20, "\(pair)")
            XCTAssertLessThan(abs(gl - gr), 1, "\(pair)")
            var t = a
            while t < T.back.0 {
                let pl = D.pose(t, .left, pair, geo)
                let pr = D.pose(t, .right, pair, geo)
                XCTAssertEqual(pr.lift, pl.lift, accuracy: 1e-6)
                // same hop height, opposite tilt: the frames' linear parts mirror
                XCTAssertEqual(pr.m.a, pl.m.a, accuracy: 1e-6)
                XCTAssertEqual(pr.m.d, pl.m.d, accuracy: 1e-6)
                XCTAssertEqual(pr.m.b, -pl.m.b, accuracy: 1e-6)
                XCTAssertEqual(pr.m.c, -pl.m.c, accuracy: 1e-6)
                t += 0.05
            }
        }
    }

    func testQuality4KCopyIsTheHDCopyMirroredAboutTheCentreLine() {
        let p = LivingVector.fShapes.flatMap { $0 }.enumerated().filter { $0.offset % 6 == 0 }.map(\.element)
        let mirrorBox = p.map { LivingPt(100 - $0.x, $0.y) }
        var t = T.split.1
        while t < T.back.0 {
            let l = placed(.quality, .left, t, p)
            let r = placed(.quality, .right, t, mirrorBox)
            for (j, q) in l.enumerated() {
                XCTAssertEqual(r[j].x, 2 * D.cx - q.x, accuracy: 1e-4)
                XCTAssertEqual(r[j].y, q.y, accuracy: 1e-4)
            }
            t += 0.07
        }
    }

    func testEndsOnTheFRestState() {
        for pair in [FusionPair.media, .quality] {
            let geo = D.layout(pair, sPx)
            for side in [FusionSide.left, .right] {
                let p = D.pose(D.end, side, pair, geo)
                let id = p.m.mul(.identity)
                let want = LivingMat.identity
                for (got, exp) in zip([id.a, id.b, id.c, id.d, id.e, id.f], [want.a, want.b, want.c, want.d, want.e, want.f]) {
                    XCTAssertEqual(got, exp, accuracy: 1e-6)
                }
                XCTAssertNil(p.lag)
            }
        }
        XCTAssertEqual(D.qualityScale(D.end), 1)
        XCTAssertEqual(D.qualityFlip(D.end), 1, accuracy: 1e-6)
    }
}
