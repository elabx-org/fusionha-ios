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
    /// the scene's (a 105° hinge at y 475.5 of a 669-pt page).
    func testCornersMidLift() throws {
        let phi = 15 * Double.pi / 180
        func top(_ offset: Double, _ progress: Double) throws -> (quad: [TabletopPoint], opacity: Double, ghost: Double) {
            let stages = TabletopLift.Stages(progress)
            let card = try XCTUnwrap(TabletopScene.card(offset: offset, sway: TabletopScene.restingSway * stages.depth))
            let scene = card.corners().map { v -> TabletopPoint in
                let p = TabletopProjection.onScreen(v, phi: phi)
                return TabletopPoint(334.5 + p.x, 475.5 - p.y)
            }
            return (TabletopLift.mix(flat.quad(offset), scene, stages.corners),
                    TabletopLift.mix(flat.opacity(offset), card.opacity, stages.corners),
                    card.ghost * stages.corners)
        }
        var got = try top(0, 0.25)
        assertQuad(got.quad, [[226.9079, 132.4577], [442.0921, 132.4577], [441.5798, 450.2568], [227.4202, 450.2568]])
        XCTAssertEqual(got.opacity, 1, accuracy: tolerance)
        XCTAssertEqual(got.ghost, 0, accuracy: tolerance)
        got = try top(0, 0.5)
        assertQuad(got.quad, [[220.1267, 170.6108], [448.8733, 170.6108], [446.179, 487.5544], [222.821, 487.5544]])
        got = try top(1, 0.5)
        assertQuad(got.quad, [[448.4604, 292.5217], [555.1922, 280.541], [553.8233, 442.3676], [447.5832, 455.144]])
        XCTAssertEqual(got.opacity, 0.6879, accuracy: tolerance)
        XCTAssertEqual(got.ghost, 0.5607, accuracy: tolerance)
        got = try top(-1, 0.75)
        assertQuad(got.quad, [[148.4591, 362.7844], [219.5441, 383.2814], [221.0448, 494.2282], [150.801, 472.3699]])
        XCTAssertEqual(got.opacity, 0.6082, accuracy: tolerance)
        XCTAssertEqual(got.ghost, 0.9592, accuracy: tolerance)
        got = try top(2, 0.5)
        assertQuad(got.quad, [[563.0347, 372.3548], [632.2355, 347.992], [630.7101, 479.617], [561.7957, 505.5431]])
        XCTAssertEqual(got.opacity, 0.3364, accuracy: tolerance)
        // The ends are the carousel and the scene themselves: nothing jumps.
        assertQuad(try top(1, 0).quad, [[447.06, 164.84], [603.94, 164.84], [603.94, 400.16], [447.06, 400.16]])
        XCTAssertEqual(try top(1, 0).opacity, 0.8, accuracy: tolerance)
        XCTAssertEqual(try top(1, 1).opacity, 0.6, accuracy: tolerance)
    }

    func testSlabGrowsItsThicknessAndItsTurn() throws {
        // Half the depth: half the resting turn, the slices half as far back.
        let thin = try XCTUnwrap(TabletopScene.card(offset: 0, sway: 0.17 * 0.5))
        let slice = thin.slice(1, thickness: 0.5)
        assertVec(slice[0], -110.7231, -353.2, 110.9034)
        assertVec(slice[2], 109.2798, -22, 92.158)
        XCTAssertEqual(thin.slice(1, thickness: 0), thin.corners())
        let swayed = try XCTUnwrap(TabletopScene.card(offset: 0, sway: 0.2, bob: 4))
        assertVec(swayed.corners()[0], -108.1994, -357.2, 131.9331)
        assertVec(swayed.corners()[2], 108.1994, -26, 88.0669)
    }

    func testScanBar() throws {
        let bar = try XCTUnwrap(TabletopScene.card(offset: 0)).scanBar(reveal: 0.5, half: 4)
        assertVec(bar[0], -108.8086, -191.6, 130.6777)
        assertVec(bar[1], 108.8086, -191.6, 93.3223)
        assertVec(bar[2], 108.8086, -183.6, 93.3223)
        assertVec(bar[3], -108.8086, -183.6, 130.6777)
    }

    func testIdle() {
        XCTAssertEqual(TabletopLift.sway(at: 0), 0, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.sway(at: 1), 0.1636, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.sway(at: 2.5), 0.229, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.bob(at: 1), 4.5638, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.bob(at: 10), -4.3773, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.spin(at: 2.5), 0.6042, accuracy: tolerance)
        XCTAssertEqual(TabletopLift.spin(at: 36), TabletopLift.spin(at: 10), accuracy: 1e-9)
        for t in stride(from: 0.0, to: 30, by: 0.37) {
            XCTAssertLessThanOrEqual(abs(TabletopLift.sway(at: t)), 0.24)
            XCTAssertLessThanOrEqual(abs(TabletopLift.bob(at: t)), 5)
        }
        XCTAssertEqual(TabletopLift.easeOut(0.5), 0.875, accuracy: 1e-9)
    }
}
