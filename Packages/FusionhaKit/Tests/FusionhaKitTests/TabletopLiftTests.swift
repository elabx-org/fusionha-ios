import XCTest
@testable import FusionhaKit

/// The tabletop hologram's lift, print-in and idle motion against the
/// approved mock's own numbers (its `drawHolo`, `holo` action and idle loop,
/// run in JavaScript), and the flat carousel the lift starts from.
final class TabletopLiftTests: XCTestCase {
    private let tolerance = 1e-3

    private func assertQuad(_ quad: [TabletopPoint], _ want: [[Double]], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(quad.count, want.count, file: file, line: line)
        for (p, w) in zip(quad, want) {
            XCTAssertEqual(p.x, w[0], accuracy: tolerance, file: file, line: line)
            XCTAssertEqual(p.y, w[1], accuracy: tolerance, file: file, line: line)
        }
    }

    private func assertVec(_ v: TabletopVec, _ x: Double, _ y: Double, _ z: Double,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(v.x, x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(v.y, y, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(v.z, z, accuracy: tolerance, file: file, line: line)
    }

    /// The tabletop's carousel on the CI frame (669 wide, the fold at 475.5).
    private let flat = TabletopLift.Flat(centerX: 334.5, centerY: 282.5, width: 212, height: 318, step: 191,
                                         scales: [1, 0.74, 0.5], opacities: [1, 0.8, 0])

    func testStages() {
        // progress: floor, corners, depth, twins, reflection
        let want: [(Double, [Double])] = [
            (0, [0, 0, 0, 0, 0]),
            (0.1, [0.1431, 0, 0, 0, 0]),
            (0.25, [0.6411, 0.1066, 0, 0, 0]),
            (0.42, [1, 0.3993, 0, 0, 0]),
            (0.5, [1, 0.5607, 0, 0, 0]),
            (0.58, [1, 0.7164, 0, 0, 0.0686]),
            (0.7, [1, 0.9062, 0.1983, 0, 0.352]),
            (0.75, [1, 0.9592, 0.3589, 0.0741, 0.5]),
            (0.84, [1, 1, 0.6752, 0.4501, 0.7583]),
            (0.9, [1, 1, 0.8569, 0.7407, 0.896]),
            (1, [1, 1, 1, 1, 1]),
        ]
        for (progress, values) in want {
            let s = TabletopLift.Stages(progress)
            let got = [s.floor, s.corners, s.depth, s.twins, s.reflection]
            for (g, w) in zip(got, values) { XCTAssertEqual(g, w, accuracy: tolerance, "at \(progress)") }
        }
        XCTAssertEqual(TabletopLift.Stages(-1), TabletopLift.Stages(0))
        XCTAssertEqual(TabletopLift.Stages(2), TabletopLift.Stages.done)
        XCTAssertTrue(TabletopLift.Stages(0.4).keepsCarouselOrder)
        XCTAssertFalse(TabletopLift.Stages(0.5).keepsCarouselOrder)
    }

    func testPrintIn() {
        // rise: ring, beam, slab, then how much shows of the slab, the first
        // and second markers and a card half way through a turn
        let want: [(Double, [Double])] = [
            (0, [0, 0, 0, 0, 0, 0, 0]),
            (0.1, [0.784, 0, 0, 0, 0, 0, 0]),
            (0.2, [0.992, 0.6056, 0, 0, 0, 0, 0]),
            (0.28, [1, 0.8984, 0, 0, 0, 0, 0.0576]),
            (0.4, [1, 0.9997, 0.4213, 0.4213, 0.4073, 0, 0.524]),
            (0.55, [1, 1, 0.7559, 0.7559, 0.8425, 0.5254, 0.8409]),
            (0.7, [1, 1, 0.9277, 0.9277, 0.9862, 0.8894, 0.963]),
            (0.85, [1, 1, 0.991, 0.991, 1, 0.9942, 0.9955]),
            (1, [1, 1, 1, 1, 1, 1, 1]),
        ]
        for (rise, values) in want {
            let p = TabletopLift.Print(rise)
            let got = [p.ring, p.beam, p.slab, p.reveal(away: 0, focus: 1), p.reveal(away: 1, focus: 0),
                       p.reveal(away: 2, focus: 0), p.reveal(away: 0.5, focus: 0.5)]
            for (g, w) in zip(got, values) { XCTAssertEqual(g, w, accuracy: tolerance, "at \(rise)") }
        }
        // Printed is exactly whole, so nothing is masked once it stands.
        XCTAssertEqual(TabletopLift.Print.done.reveal(away: 2, focus: 0), 1)
        XCTAssertEqual(TabletopLift.Print.done.reveal(away: 0, focus: 1), 1)
    }

    func testFlatCarousel() {
        assertQuad(flat.quad(0), [[228.5, 123.5], [440.5, 123.5], [440.5, 441.5], [228.5, 441.5]])
        assertQuad(flat.quad(1), [[447.06, 164.84], [603.94, 164.84], [603.94, 400.16], [447.06, 400.16]])
        assertQuad(flat.quad(-1), [[65.06, 164.84], [221.94, 164.84], [221.94, 400.16], [65.06, 400.16]])
        assertQuad(flat.quad(2), [[663.5, 203], [769.5, 203], [769.5, 362], [663.5, 362]])
        assertQuad(flat.quad(-0.5), [[146.78, 144.17], [331.22, 144.17], [331.22, 420.83], [146.78, 420.83]])
        assertQuad(flat.quad(1.4), [[533.636, 180.104], [670.164, 180.104], [670.164, 384.896], [533.636, 384.896]])
        assertQuad(flat.quad(3), [[854.5, 203], [960.5, 203], [960.5, 362], [854.5, 362]])
        XCTAssertEqual(flat.scale(-0.5), 0.87, accuracy: tolerance)
        XCTAssertEqual(flat.opacity(1), 0.8, accuracy: tolerance)
        XCTAssertEqual(flat.opacity(1.4), 0.48, accuracy: tolerance)
        XCTAssertEqual(flat.opacity(2), 0, accuracy: tolerance)
        XCTAssertEqual(flat.opacity(3), 0, accuracy: tolerance)
    }

    /// A poster part of the way up: its corners between the carousel's and
    /// the scene's (a 105° hinge at y 475.5 of a 669-pt page, seat 50). The
    /// slab ends wholly above the hinge.
    func testCornersMidLift() throws {
        let phi = 15 * Double.pi / 180, eye = TabletopProjection.eye(elevation: 50)
        func top(_ offset: Double, _ progress: Double) throws -> (quad: [TabletopPoint], opacity: Double, ghost: Double) {
            let stages = TabletopLift.Stages(progress)
            let card = try XCTUnwrap(TabletopScene.card(offset: offset, seat: 50,
                                                        sway: TabletopScene.restingSway * stages.depth))
            let scene = card.corners().map { v -> TabletopPoint in
                let p = TabletopProjection.onScreen(v, phi: phi, eye: eye)
                return TabletopPoint(334.5 + p.x, 475.5 - p.y)
            }
            return (TabletopLift.mix(flat.quad(offset), scene, stages.corners),
                    TabletopLift.mix(flat.opacity(offset), card.opacity, stages.corners),
                    card.ghost * stages.corners)
        }
        var got = try top(0, 0.25)
        assertQuad(got.quad, [[231.5157, 131.8523], [437.4843, 131.8523], [437.474, 440.6272], [231.526, 440.6272]])
        XCTAssertEqual(got.opacity, 1, accuracy: tolerance)
        XCTAssertEqual(got.ghost, 0, accuracy: tolerance)
        got = try top(0, 0.5)
        assertQuad(got.quad, [[244.3603, 167.427], [424.6397, 167.427], [424.5856, 436.9097], [244.4144, 436.9097]])
        got = try top(1, 0.5)
        assertQuad(got.quad, [[472.6806, 249.0329], [576.8498, 231.5483], [575.0376, 385.3492], [471.3603, 403.4786]])
        XCTAssertEqual(got.opacity, 0.6879, accuracy: tolerance)
        XCTAssertEqual(got.ghost, 0.5607, accuracy: tolerance)
        got = try top(-1, 0.75)
        assertQuad(got.quad, [[111.4066, 278.9663], [178.1077, 308.8795], [180.3664, 405.8375], [114.507, 374.8212]])
        XCTAssertEqual(got.opacity, 0.6082, accuracy: tolerance)
        XCTAssertEqual(got.ghost, 0.9592, accuracy: tolerance)
        got = try top(2, 0.5)
        assertQuad(got.quad, [[630.0288, 252.0024], [693.7192, 222.6555], [691.3266, 341.9637], [627.8134, 372.4111]])
        XCTAssertEqual(got.opacity, 0.3364, accuracy: tolerance)
        // The ends are the carousel and the scene themselves: nothing jumps.
        assertQuad(try top(1, 0).quad, [[447.06, 164.84], [603.94, 164.84], [603.94, 400.16], [447.06, 400.16]])
        XCTAssertEqual(try top(1, 0).opacity, 0.8, accuracy: tolerance)
        XCTAssertEqual(try top(1, 1).opacity, 0.6, accuracy: tolerance)
        // The lift ends on the slab's resting shape, its foot above the hinge
        // (y 475.5), leaned for seat 50.
        assertQuad(try top(0, 1).quad, [[257.908, 201.8462], [410.1151, 181.0599], [410.0225, 409.6035], [258.003, 433.313]])
    }

    func testSlabGrowsItsThicknessAndItsTurn() throws {
        // Half the depth: half the resting turn, the slices half as far back.
        let thin = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50, sway: 0.17 * 0.5))
        let slice = thin.slice(1, thickness: 0.5)
        assertVec(slice[0], -75.5226, -317.8106, -24.4783)
        assertVec(slice[2], 74.0793, -99.6701, 18.7838)
        XCTAssertEqual(thin.slice(1, thickness: 0), thin.corners())
        let swayed = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50, sway: 0.2, bob: 4))
        assertVec(swayed.corners()[0], -73.5756, -321.8106, -16.0089)
        assertVec(swayed.corners()[2], 73.5756, -103.6701, 10.171)
    }

    func testScanBar() throws {
        // Half way up the leaned slab (seat 50): half its rise, half its set-back.
        let bar = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50)).scanBar(reveal: 0.5, half: 4)
        assertVec(bar[0], -73.9898, -212.7404, 13.9955)
        assertVec(bar[1], 73.9898, -212.7404, -11.4062)
        assertVec(bar[2], 73.9898, -204.7404, -11.4062)
        assertVec(bar[3], -73.9898, -204.7404, 13.9955)
    }

    func testIdle() {
        XCTAssertEqual(TabletopLift.sway(at: 0), 0, accuracy: tolerance)
        // ±0.62 rad at 0.5 rad/s (the stage bench's slower, wider turn).
        XCTAssertEqual(TabletopLift.sway(at: 1), 0.2972, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.sway(at: 2.5), 0.5884, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.bob(at: 1), 4.5638, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.bob(at: 10), -4.3773, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.spin(at: 2.5), 0.6042, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.spin(at: 36), TabletopLift.spin(at: 10), accuracy: 1e-9)
        for t in stride(from: 0.0, to: 30, by: 0.37) {
            XCTAssertLessThanOrEqual(abs(TabletopLift.sway(at: t)), 0.62)
            XCTAssertLessThanOrEqual(abs(TabletopLift.bob(at: t)), 5)
        }
        XCTAssertEqual(TabletopLift.easeOut(0.5), 0.875, accuracy: 1e-9)
    }
}
