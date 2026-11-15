import XCTest
@testable import FusionhaKit

/// The projection light (`TabletopBeam`) against a Python copy of its maths:
/// brightest at the fold line, the same either side of it, gone by 45% of
/// the card's height up the upright half, and the cone and contact shadow
/// on the table.
final class TabletopBeamTests: XCTestCase {
    private let tolerance = 1e-3
    /// The card's height up the upright half at seat 35 / hinge 105 (its
    /// highest head corner, `TabletopSceneTests.testDefaultSeat`).
    private let height = 320.0

    func testTheBand() {
        XCTAssertEqual(TabletopBeam.band(0), 0.6, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.band(24), 0.6, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.band(50), 0.3321, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.band(-50), 0.3321, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.band(72), 0.0332, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.band(80), 0, accuracy: 1e-12)
        XCTAssertEqual(TabletopBeam.band(-120), 0, accuracy: 1e-12)
    }

    /// The same strength and the same width either side of the fold line.
    func testContinuousAcrossTheFold() {
        for h in [180.0, 250, 320, 420] {
            let above = TabletopBeam.strength(rise: 1e-9, cardHeight: h)
            let below = TabletopBeam.strength(rise: -1e-9, cardHeight: h)
            XCTAssertEqual(above, below, accuracy: 1e-6)
            XCTAssertEqual(TabletopBeam.strength(rise: 0, cardHeight: h), TabletopBeam.peak, accuracy: 1e-9)
            // Within a point either side, the light changes by under 0.1%.
            XCTAssertEqual(TabletopBeam.strength(rise: 1, cardHeight: h), TabletopBeam.strength(rise: -1, cardHeight: h),
                           accuracy: 1e-3)
        }
        XCTAssertEqual(TabletopBeam.peak, 0.9, accuracy: 1e-9)
        // One width for both halves: 1.3 of the card.
        XCTAssertEqual(TabletopBeam.width(cardWidth: 220.8), 287.04, accuracy: tolerance)
    }

    func testPeakInTheFoldBand() {
        let peak = TabletopBeam.strength(rise: 0, cardHeight: height)
        for rise in stride(from: -200.0, through: 500, by: 0.5) {
            XCTAssertLessThanOrEqual(TabletopBeam.strength(rise: rise, cardHeight: height), peak + 1e-12)
        }
        // Still most of it 24 pt either side, about half at 50.
        XCTAssertEqual(TabletopBeam.strength(rise: 24, cardHeight: height), 0.8778, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.strength(rise: -24, cardHeight: height), 0.8352, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.strength(rise: 50, cardHeight: height), 0.5487, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.strength(rise: -50, cardHeight: height), 0.4270, accuracy: tolerance)
        XCTAssertEqual(TabletopBeam.strength(rise: 100, cardHeight: height), 0.0669, accuracy: tolerance)
        // Out over the table it is gone by the band's reach.
        XCTAssertEqual(TabletopBeam.strength(rise: -80, cardHeight: height), 0, accuracy: 1e-12)
        XCTAssertEqual(TabletopBeam.strength(rise: -150, cardHeight: height), 0, accuracy: 1e-12)
    }

    func testGoneBy45PercentOfTheCard() {
        for h in [180.0, 256, 320, 420] {
            XCTAssertEqual(TabletopBeam.reach(cardHeight: h), 0.45 * h, accuracy: 1e-9)
            for rise in stride(from: 0.45 * h, through: h, by: 1) {
                XCTAssertEqual(TabletopBeam.strength(rise: rise, cardHeight: h), 0, accuracy: 1e-12)
            }
            XCTAssertGreaterThan(TabletopBeam.strength(rise: 0.4 * h, cardHeight: h), 0)
        }
        // A small card: the band still reaches 80.
        XCTAssertEqual(TabletopBeam.reach(cardHeight: 100), 80, accuracy: 1e-9)
    }

    func testMotion() {
        XCTAssertEqual(TabletopBeam.breath(at: nil), 1)
        XCTAssertEqual(TabletopBeam.breath(at: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(TabletopBeam.breath(at: 0.75), 1.08, accuracy: 1e-9)
        XCTAssertEqual(TabletopBeam.breath(at: 2.25), 0.92, accuracy: 1e-9)
        XCTAssertEqual(TabletopBeam.breath(at: 3), 1, accuracy: 1e-9)
        // The lift: nothing for two thirds, then in.
        XCTAssertEqual(TabletopBeam.lift(0.5), 0)
        XCTAssertEqual(TabletopBeam.lift(2.0 / 3.0), 0, accuracy: 1e-9)
        XCTAssertEqual(TabletopBeam.lift(5.0 / 6.0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(TabletopBeam.lift(1), 1)
        // A turn half way between two titles: a quarter of the light.
        XCTAssertEqual(TabletopBeam.focus(0.5), 0.25, accuracy: 1e-9)
        XCTAssertEqual(TabletopBeam.focus(1), 1)
    }

    func testScanLines() {
        // Still: one every 34 pt from 80 out on the table up to 45% of the card.
        let still = TabletopBeam.scanLines(at: nil, cardHeight: height)
        XCTAssertEqual(still, [-80, -46, -12, 22, 56, 90, 124])
        // They travel up 12 pt a second and wrap every 34.
        let later = TabletopBeam.scanLines(at: 1, cardHeight: height)
        XCTAssertEqual(later.first ?? 0, -68, accuracy: 1e-9)
        XCTAssertEqual(later.count, 7)
        let wrapped = TabletopBeam.scanLines(at: 3, cardHeight: height)
        XCTAssertEqual(wrapped.first ?? 0, -78, accuracy: 1e-9)
        for line in wrapped {
            XCTAssertLessThanOrEqual(line, TabletopBeam.reach(cardHeight: height))
        }
    }

    /// The contact shadow: the turned foot's footprint on the floor, slices
    /// and a 16 pt margin included (seat 50, resting turn).
    func testContactShadow() throws {
        let card = try XCTUnwrap(TabletopScene.card(offset: 0, seat: 50))
        let quad = TabletopBeam.contact(card)
        let expected: [(Double, Double)] = [(-76.0903, -67.6376), (132.5545, 75.104), (95.2881, 129.5762), (-113.3567, -13.1654)]
        for (v, e) in zip(quad, expected) {
            XCTAssertEqual(v.x, e.0, accuracy: tolerance)
            XCTAssertEqual(v.y, 0)
            XCTAssertEqual(v.z, e.1, accuracy: tolerance)
        }
        // Its near side is past the card's near right foot (z 107.3).
        XCTAssertGreaterThan(quad[2].z, card.corners()[2].z)
    }
}
