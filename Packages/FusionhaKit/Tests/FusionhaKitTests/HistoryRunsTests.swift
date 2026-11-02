import XCTest
@testable import FusionhaKit

/// Same-minute runs of one event kind fold into one timeline row.
final class HistoryRunsTests: XCTestCase {
    func testFoldsConsecutiveEqualKeys() {
        let runs = HistoryRuns.runs(["a", "a", "a", "b", "a"]) { $0 }
        XCTAssertEqual(runs, [["a", "a", "a"], ["b"], ["a"]])
    }

    func testNilKeyNeverFolds() {
        let runs = HistoryRuns.runs(["x", "x"]) { _ in nil as String? }
        XCTAssertEqual(runs.count, 2)
    }

    func testKeyBySameMinuteKindAndVersion() {
        let t = Date(timeIntervalSince1970: 1_760_380_560)  // on a minute boundary
        let a = HistoryRuns.key(eventType: "RENUMBERED", editionId: 1, date: t)
        XCTAssertEqual(a, HistoryRuns.key(eventType: "RENUMBERED", editionId: 1, date: t.addingTimeInterval(30)))
        XCTAssertNotEqual(a, HistoryRuns.key(eventType: "RENUMBERED", editionId: 1, date: t.addingTimeInterval(61)))
        XCTAssertNotEqual(a, HistoryRuns.key(eventType: "RENUMBERED", editionId: 2, date: t))
        XCTAssertNotEqual(a, HistoryRuns.key(eventType: "RENAMED", editionId: 1, date: t))
        XCTAssertNil(HistoryRuns.key(eventType: "GRABBED", editionId: 1, date: t))
        XCTAssertNil(HistoryRuns.key(eventType: "RENUMBERED", editionId: 1, date: nil))
    }
}
