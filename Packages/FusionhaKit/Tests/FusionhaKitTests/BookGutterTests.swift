import XCTest
@testable import FusionhaKit

final class BookGutterTests: XCTestCase {
    func testDepthFollowsTheHinge() {
        XCTAssertEqual(BookGutter.depth(degrees: 180), 0)
        XCTAssertEqual(BookGutter.depth(degrees: 170), 0)
        XCTAssertEqual(BookGutter.depth(degrees: 132.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(BookGutter.depth(degrees: 95), 1)
        XCTAssertEqual(BookGutter.depth(degrees: 40), 1)
    }

    func testReduceMotionSteps() {
        XCTAssertEqual(BookGutter.depth(degrees: 165, steps: true), 0)
        XCTAssertEqual(BookGutter.depth(degrees: 130, steps: true), 0.5)
        XCTAssertEqual(BookGutter.depth(degrees: 100, steps: true), 1)
    }

    func testShadowIsDeepestAtTheCreaseAndRightPageDarker() {
        let crease = BookGutter.shadow(at: 0, rightPage: false, depth: 1)
        let mid = BookGutter.shadow(at: 50, rightPage: false, depth: 1)
        XCTAssertGreaterThan(crease, mid)
        XCTAssertEqual(BookGutter.shadow(at: 200, rightPage: false, depth: 1), 0)
        XCTAssertGreaterThan(BookGutter.shadow(at: 20, rightPage: true, depth: 1),
                             BookGutter.shadow(at: 20, rightPage: false, depth: 1))
    }

    func testOnlyDarkGroundsAreLifted() {
        XCTAssertEqual(BookGutter.lift(luminance: 0.3), 0)
        XCTAssertGreaterThan(BookGutter.lift(luminance: 0.01), BookGutter.lift(luminance: 0.06))
    }
}
