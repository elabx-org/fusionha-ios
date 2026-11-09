import XCTest
@testable import FusionhaKit

final class FoldSeasTests: XCTestCase {
    func testEachSideIsItsOwnSea() {
        let f = FoldSeas.field(width: 70, height: 200, meeting: 0.5)
        XCTAssertEqual(f.sea.count, 70 * 200)
        XCTAssertEqual(f.shade.count, 70 * 200 * 4)
        for y in stride(from: 0, to: 200, by: 20) {
            XCTAssertLessThan(f.sea[y * 70], 40, "leading edge is the leading sea")
            XCTAssertGreaterThan(f.sea[y * 70 + 69], 215, "trailing edge is the trailing sea")
        }
    }

    func testTheLineMeanders() {
        let f = FoldSeas.field(width: 70, height: 400, meeting: 0.5)
        let crossings: [Int] = (0..<400).map { y -> Int in
            (0..<70).first(where: { f.sea[y * 70 + $0] >= 128 }) ?? 70
        }
        XCTAssertGreaterThan((crossings.max() ?? 0) - (crossings.min() ?? 0), 4)
    }

    func testSameSeedSameWater() {
        XCTAssertEqual(FoldSeas.field(width: 30, height: 60, meeting: 0.5),
                       FoldSeas.field(width: 30, height: 60, meeting: 0.5))
    }

    func testBrighterSeaReachesFurther() {
        XCTAssertLessThan(FoldSeas.meeting(leading: 0.1, trailing: 0.4), 0.5)
        XCTAssertGreaterThan(FoldSeas.meeting(leading: 0.4, trailing: 0.1), 0.5)
        XCTAssertEqual(FoldSeas.meeting(leading: 0, trailing: 1), 0.2, accuracy: 1e-9)
    }

    func testShadeOnlyDarkensExceptTheSeam() {
        let f = FoldSeas.field(width: 70, height: 100, meeting: 0.5)
        for i in stride(from: 0, to: f.shade.count, by: 4) {
            XCTAssertLessThanOrEqual(f.shade[i], f.shade[i + 3], "premultiplied grey never exceeds alpha")
        }
    }

    func testOnlyDarkGroundsAreLifted() {
        XCTAssertEqual(FoldSeas.lift(luminance: 0.3), 0)
        XCTAssertGreaterThan(FoldSeas.lift(luminance: 0.01), FoldSeas.lift(luminance: 0.06))
    }
}
