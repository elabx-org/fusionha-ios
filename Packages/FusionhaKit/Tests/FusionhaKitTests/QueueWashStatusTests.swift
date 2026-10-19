import XCTest
@testable import FusionhaKit

final class QueueWashStatusTests: XCTestCase {
    func testGroupWashRank() {
        XCTAssertEqual(QueueWashStatus.mostUrgent([.queued, .working, .failed, .attention]), .failed)
        XCTAssertEqual(QueueWashStatus.mostUrgent([.queued, .attention, .working]), .attention)
        XCTAssertEqual(QueueWashStatus.mostUrgent([.queued, .working]), .working)
        XCTAssertEqual(QueueWashStatus.mostUrgent([.queued]), .queued)
        XCTAssertEqual(QueueWashStatus.mostUrgent([QueueWashStatus]()), .working)
    }

    func testRemoveAllMessages() {
        XCTAssertEqual(QueueRemoveAllCopy.message(total: 3, failedNames: [], blocklist: false).text,
                       "Removed 3 downloads from the queue")
        XCTAssertEqual(QueueRemoveAllCopy.message(total: 1, failedNames: [], blocklist: true).text,
                       "Blocklisted and removed 1 download")
        let all = QueueRemoveAllCopy.message(total: 2, failedNames: ["a", "b"], blocklist: false)
        XCTAssertEqual(all.text, "Could not remove any of the 2 downloads. Try again.")
        XCTAssertTrue(all.isError)
        XCTAssertEqual(QueueRemoveAllCopy.message(total: 1, failedNames: ["a"], blocklist: false).text,
                       "Could not remove the download. Try again.")
        XCTAssertEqual(QueueRemoveAllCopy.message(total: 3, failedNames: ["S01E02"], blocklist: false).text,
                       "Removed 2 of 3 downloads. Could not remove S01E02; they are still in the queue. Try again.")
    }

    func testStripLabel() {
        XCTAssertEqual(QueueRemoveAllCopy.stripLabel("S06E04 · Niagara (1)"), "S06E04")
        XCTAssertEqual(QueueRemoveAllCopy.stripLabel("S02"), "S02")
        XCTAssertNil(QueueRemoveAllCopy.stripLabel(nil))
        XCTAssertNil(QueueRemoveAllCopy.stripLabel(" "))
    }
}
