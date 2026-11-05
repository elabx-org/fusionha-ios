import XCTest
@testable import FusionhaKit

/// v2 one-ink rails: on disk, the aired rest, then not out yet.
final class OneInkRailTests: XCTestCase {
    func testSpansFollowTheSeason() {
        // VisionQuest S1 in the mock: 8 episodes, 6 on disk, 7 aired.
        let spans = OneInkRail.spans(have: 6, aired: 7, total: 8, rest: .downloading)
        XCTAssertEqual(spans.map(\.piece), [.onDisk, .downloading, .unaired])
        XCTAssertEqual(spans.map(\.fraction), [0.75, 0.125, 0.125])
    }

    func testEmptyStretchesAreLeftOut() {
        XCTAssertEqual(OneInkRail.spans(have: 8, aired: 8, total: 8).map(\.piece), [.onDisk])
        XCTAssertEqual(OneInkRail.spans(have: 0, aired: 0, total: 4).map(\.piece), [.unaired])
        XCTAssertTrue(OneInkRail.spans(have: 0, aired: 0, total: 0).isEmpty)
    }

    func testCountsAreClamped() {
        let n = OneInkRail.normalized(have: 9, aired: 12, total: 10)
        XCTAssertEqual(n.have, 9)
        XCTAssertEqual(n.aired, 10)
        XCTAssertEqual(n.total, 10)
        XCTAssertEqual(OneInkRail.normalized(have: 5, aired: 3, total: 10).have, 3)
        XCTAssertEqual(OneInkRail.normalized(have: -1, aired: -2, total: -3).total, 0)
    }

    func testTicksOnePerEpisode() {
        XCTAssertEqual(OneInkRail.ticks(have: 2, aired: 3, total: 5, rest: .held),
                       [.onDisk, .onDisk, .held, .unaired, .unaired])
        XCTAssertEqual(OneInkRail.ticks(have: 26, aired: 26, total: 26)?.count, 26)
        XCTAssertNil(OneInkRail.ticks(have: 1, aired: 27, total: 27))
    }

    func testRestFollowsTheBadge() {
        XCTAssertEqual(OneInkRail.rest(for: .downloading(progress: 0.3)), .downloading)
        XCTAssertEqual(OneInkRail.rest(for: .held), .held)
        XCTAssertEqual(OneInkRail.rest(for: .partial(have: 1, of: 3)), .missing)
        XCTAssertEqual(OneInkRail.countLine(have: 6, aired: 7), "6 of 7")
    }
}
