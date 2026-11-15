import XCTest
@testable import FusionhaKit

/// The slab is drawn just small enough that its head
/// stays 420 pt up the standing half at every seat and hinge angle
/// (`TabletopScene.cappedSlabScale`), and keeps 0.96 up to a seat of about 47
/// (turned three-quarters, its far edge is drawn higher than facing out).
final class TabletopSlabCapTests: XCTestCase {
    private let tolerance = 1e-3

    func testFullSizeUpToTheMiddleSeats() {
        XCTAssertEqual(TabletopScene.slabTopCap, 420)
        for seat in stride(from: 26.0, through: 47, by: 1) {
            for hinge in stride(from: 92.0, through: 135, by: 1) {
                XCTAssertEqual(TabletopScene.cappedSlabScale(seat: seat, hinge: hinge), 0.96, "seat \(seat) hinge \(hinge)")
            }
        }
        // The default seat (35) keeps it at every hinge; seat 50 at the resting one.
        for hinge in stride(from: 92.0, through: 135, by: 1) {
            XCTAssertEqual(TabletopScene.cappedSlabScale(seat: TabletopProjection.defaultSeat, hinge: hinge), 0.96)
        }
        XCTAssertEqual(TabletopScene.cappedSlabScale(seat: 50, hinge: 105), 0.96)
        // Uncapped, seat 68 at hinge 92 draws the head 632 pt up.
        XCTAssertEqual(TabletopScene.slabHead(scale: 0.96, seat: 68, hinge: 92), 632.4, accuracy: 0.1)
    }

    func testTheHeadStaysUnderTheCap() {
        for seat in stride(from: 26.0, through: 68, by: 2) {
            for hinge in stride(from: 92.0, through: 135, by: 3) {
                let scale = TabletopScene.cappedSlabScale(seat: seat, hinge: hinge)
                XCTAssertLessThanOrEqual(TabletopScene.slabHead(scale: scale, seat: seat, hinge: hinge), 420 + tolerance)
                XCTAssertLessThanOrEqual(scale, 0.96)
            }
        }
    }

    func testHighSeatsShrinkJustEnough() throws {
        XCTAssertEqual(TabletopScene.cappedSlabScale(seat: 68, hinge: 92), 0.6049, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.cappedSlabScale(seat: 68, hinge: 105), 0.8445, accuracy: tolerance)
        XCTAssertEqual(TabletopScene.cappedSlabScale(seat: 68, hinge: 135), 0.96)
        XCTAssertEqual(TabletopScene.slabHead(scale: TabletopScene.cappedSlabScale(seat: 60, hinge: 92), seat: 60, hinge: 92),
                       420, accuracy: tolerance)
        // The card follows the hinge it is drawn for; a waiting title keeps its size.
        let slab = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 68, hinge: 92))
        XCTAssertEqual(slab.width, 230 * 0.6049, accuracy: 0.05)
        let waiting = try XCTUnwrap(TabletopScene.card(offset: 1, seat: 68, hinge: 92))
        XCTAssertEqual(waiting.width, 230 * TabletopScene.markerScale, accuracy: tolerance)
    }
}
