import XCTest
@testable import FusionhaKit

/// Mirrors the web's `held-cf.test.ts` (fusionha 0.4.234).
final class HeldCFTests: XCTestCase {
    func testReadsTheCandidateAgainstTheCopyOnDisk() {
        XCTAssertEqual(HeldCF.compareLine(4825, 4875), "CF 4825 vs your 4875")
    }

    func testUsesATrueMinusForNegatives() {
        XCTAssertEqual(HeldCF.compareLine(1075, -9245), "CF 1075 vs your \u{2212}9245")
        XCTAssertEqual(HeldCF.compareLine(-150, 0), "CF \u{2212}150 vs your 0")
    }

    func testNilWhenEitherScoreIsUnknown() {
        XCTAssertNil(HeldCF.compareLine(nil, 10))
        XCTAssertNil(HeldCF.compareLine(10, nil))
    }
}
