import XCTest
@testable import FusionhaKit

final class QueueDuoRuleV2Tests: XCTestCase {
    func testSplitsOnTheOpenDuoAndWidePanes() {
        XCTAssertFalse(QueueDuoRuleV2.splits(width: 402, duoOpen: false))
        XCTAssertFalse(QueueDuoRuleV2.splits(width: 402, duoOpen: true))
        XCTAssertTrue(QueueDuoRuleV2.splits(width: 951, duoOpen: true))
        XCTAssertFalse(QueueDuoRuleV2.splits(width: 700, duoOpen: false))
        XCTAssertTrue(QueueDuoRuleV2.splits(width: 820, duoOpen: false))
    }

    func testFlatListIsAboutAThird() {
        XCTAssertEqual(QueueDuoRuleV2.listWidth(width: 951, bookPose: false), 317)
        XCTAssertEqual(QueueDuoRuleV2.listWidth(width: 1200, bookPose: false), 400)
        // Never under the folded column, never past half.
        XCTAssertEqual(QueueDuoRuleV2.listWidth(width: 720, bookPose: false), 300)
        XCTAssertEqual(QueueDuoRuleV2.listWidth(width: 600, bookPose: false), 300)
    }

    func testBookPoseKeepsEqualPagesAndTheGutter() {
        XCTAssertEqual(QueueDuoRuleV2.listWidth(width: 951, bookPose: true), 455.5)
        XCTAssertEqual(QueueDuoRuleV2.gap(bookPose: true), 40)
        XCTAssertEqual(QueueDuoRuleV2.gap(bookPose: false), 0)
    }
}
