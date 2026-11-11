import XCTest
@testable import FusionhaKit

/// v2's split handle (owner-approved 2026-11-05).
final class DuoSeamTests: XCTestCase {
    /// The Duo's inner landscape shell and v2's third.
    private let width = 951.0
    private let split = 317.0

    func testTheSplitRestsAtAThirdOrAHalf() {
        XCTAssertEqual(DuoSeam.splitShare(x: 300, width: 951), 1.0 / 3)
        XCTAssertEqual(DuoSeam.splitShare(x: 380, width: 951), 1.0 / 3)
        XCTAssertEqual(DuoSeam.splitShare(x: 410, width: 951), 0.5)
        XCTAssertEqual(DuoSeam.splitShare(x: 520, width: 951), 0.5)
        XCTAssertEqual(DuoSeam.splitShare(x: 10, width: 0), 1.0 / 3)
    }

    func testStopsArePlaces() {
        XCTAssertEqual(DuoSeam.position(of: .fullWidth, width: width, split: split), 0)
        XCTAssertEqual(DuoSeam.position(of: .split, width: width, split: split), split)
        XCTAssertEqual(DuoSeam.position(of: .closed, width: width, split: split), width)
    }

    func testSlowReleaseGoesToTheZone() {
        XCTAssertEqual(DuoSeam.zone(150, width: width, split: split), .fullWidth)
        XCTAssertEqual(DuoSeam.zone(160, width: width, split: split), .split)
        XCTAssertEqual(DuoSeam.zone(600, width: width, split: split), .split)
        XCTAssertEqual(DuoSeam.zone(630, width: width, split: split), .closed)
        XCTAssertEqual(DuoSeam.target(x: 630, velocity: 100, width: width, split: split), .closed)
        XCTAssertEqual(DuoSeam.target(x: 100, velocity: -100, width: width, split: split), .fullWidth)
    }

    func testAFlickGoesToTheNextStopInItsDirection() {
        XCTAssertEqual(DuoSeam.target(x: 20, velocity: 900, width: width, split: split), .split)
        XCTAssertEqual(DuoSeam.target(x: 340, velocity: 900, width: width, split: split), .closed)
        XCTAssertEqual(DuoSeam.target(x: 300, velocity: -900, width: width, split: split), .fullWidth)
        XCTAssertEqual(DuoSeam.target(x: 800, velocity: -900, width: width, split: split), .split)
        // Just under the flick speed it is a slow release.
        XCTAssertEqual(DuoSeam.target(x: 340, velocity: 499, width: width, split: split), .split)
    }

    func testPastEitherEndItRubberBands() {
        XCTAssertEqual(DuoSeam.rubberBand(200, width: width), 200)
        XCTAssertEqual(DuoSeam.rubberBand(-100, width: width), -pow(100, 0.7), accuracy: 0.001)
        XCTAssertEqual(DuoSeam.rubberBand(width + 100, width: width), width + pow(100, 0.7), accuracy: 0.001)
        XCTAssertLessThan(DuoSeam.rubberBand(-100, width: width), 0)
        XCTAssertGreaterThan(DuoSeam.rubberBand(-100, width: width), -100)
    }

    func testTapSwitchesSplitAndFullWidth() {
        XCTAssertEqual(DuoSeam.tapTarget(x: split, split: split), .fullWidth)
        XCTAssertEqual(DuoSeam.tapTarget(x: split + 1, split: split), .fullWidth)
        XCTAssertEqual(DuoSeam.tapTarget(x: 0, split: split), .split)
    }

    func testAdjustStepsOneStop() {
        XCTAssertEqual(DuoSeam.next(from: .fullWidth, towardClose: true), .split)
        XCTAssertEqual(DuoSeam.next(from: .split, towardClose: true), .closed)
        XCTAssertEqual(DuoSeam.next(from: .split, towardClose: false), .fullWidth)
        XCTAssertEqual(DuoSeam.next(from: .fullWidth, towardClose: false), .fullWidth)
    }

    func testLabelsAndTheClosingLookFollowTheSeam() {
        XCTAssertEqual(DuoSeam.closeLabel(x: split + 60, split: split), 0)
        XCTAssertEqual(DuoSeam.closeLabel(x: split + 135, split: split), 0.5, accuracy: 0.001)
        XCTAssertEqual(DuoSeam.closeLabel(x: width, split: split), 1)
        XCTAssertEqual(DuoSeam.fullLabel(x: split, split: split), 0)
        XCTAssertEqual(DuoSeam.fullLabel(x: 0, split: split), 1)
        XCTAssertEqual(DuoSeam.closeProgress(x: split, width: width, split: split), 0)
        XCTAssertEqual(DuoSeam.closeProgress(x: 100, width: width, split: split), 0)
        XCTAssertEqual(DuoSeam.closeProgress(x: width, width: width, split: split), 1)
        XCTAssertEqual(DuoSeam.listShade(x: split, split: split), 0)
        XCTAssertEqual(DuoSeam.listShade(x: 0, split: split), 0.55, accuracy: 0.001)
        XCTAssertEqual(DuoSeam.listShade(x: 500, split: split), 0)
    }

    func testTheSpringSettlesOnItsTarget() {
        var spring = DuoSeam.Spring(x: 500, velocity: 0)
        var frames = 0
        while !spring.settled(at: split), frames < 600 {
            spring.step(toward: split, dt: 1.0 / 120)
            frames += 1
        }
        XCTAssertTrue(spring.settled(at: split))
        // About half a second, never stuck.
        XCTAssertLessThan(frames, 240)
    }

    func testTheSpringBarelyOvershoots() {
        var spring = DuoSeam.Spring(x: 0, velocity: 0)
        var peak = 0.0
        for _ in 0..<240 {
            spring.step(toward: split, dt: 1.0 / 120)
            peak = max(peak, spring.x)
        }
        XCTAssertGreaterThan(peak, split)
        XCTAssertLessThan(peak, split * 1.05)
        var critical = DuoSeam.Spring(x: 0, velocity: 0)
        var criticalPeak = 0.0
        for _ in 0..<240 {
            critical.step(toward: split, dt: 1.0 / 120, dampingRatio: 1)
            criticalPeak = max(criticalPeak, critical.x)
        }
        XCTAssertLessThanOrEqual(criticalPeak, split + 0.5)
    }

    func testAStalledFrameIsCapped() {
        var spring = DuoSeam.Spring(x: 0, velocity: 0)
        spring.step(toward: split, dt: 5)
        var capped = DuoSeam.Spring(x: 0, velocity: 0)
        capped.step(toward: split, dt: 0.032)
        XCTAssertEqual(spring, capped)
    }
}
