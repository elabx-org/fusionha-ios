import XCTest
@testable import FusionhaKit

final class QueueRulesTests: XCTestCase {

    func testLinkingCounterIsStrict() {
        XCTAssertEqual(QueueRules.linking(step: "Linking (3/10)"), QueueRules.Linking(done: 3, total: 10))
        XCTAssertNil(QueueRules.linking(step: "Pushing (3/10)"))      // a storage push, not linking
        XCTAssertNil(QueueRules.linking(step: "Linking (0/0)"))       // nothing yet
        XCTAssertNil(QueueRules.linking(step: "Caching"))
        XCTAssertNil(QueueRules.linking(step: "Linking 3 of 10"))
        XCTAssertNil(QueueRules.linking(step: nil))
        XCTAssertEqual(QueueRules.linking(step: "Linking (12/10)")?.done, 10)   // never past the total
    }

    func testModes() {
        XCTAssertFalse(QueueRules.isPhaseMode(phase: nil))
        XCTAssertFalse(QueueRules.isPhaseMode(phase: "downloading"))
        XCTAssertTrue(QueueRules.isPhaseMode(phase: "caching"))
        // A grab decypharr hasn't started: status downloading, zero bytes.
        XCTAssertFalse(QueueRules.hasRealBytes(progress: 0, size: 4_000_000_000, sizeleft: 4_000_000_000))
        XCTAssertTrue(QueueRules.hasRealBytes(progress: 0, size: 4_000_000_000, sizeleft: 3_000_000_000))
        XCTAssertTrue(QueueRules.hasRealBytes(progress: 12, size: 0, sizeleft: 0))
    }

    func testRails() {
        XCTAssertEqual(QueueRules.stages(route: .debrid), ["Downloading", "Linking", "Caching", "Importing"])
        XCTAssertEqual(QueueRules.stages(route: .usenet), ["Parsing", "Processed", "Linking", "Caching", "Importing"])
        XCTAssertEqual(QueueRules.stages(route: .usenet, including: "validating").count, 6)
        XCTAssertEqual(QueueRules.route(protocol: "TORRENT"), .debrid)
        XCTAssertEqual(QueueRules.route(protocol: "usenet"), .usenet)
    }

    func testRingCountsCompletedStagesOnly() {
        let s = QueueRules.state(protocol: "usenet", phase: "linking", phaseTerminal: false)
        XCTAssertEqual(s.currentLabel, "Linking")
        XCTAssertEqual(s.completed, 2)
        XCTAssertEqual(s.ring, 2.0 / 5.0, accuracy: 0.0001)
        XCTAssertFalse(s.failed)
        let importing = QueueRules.state(protocol: "torrent", phase: "complete", phaseTerminal: true)
        XCTAssertEqual(importing.currentLabel, "Importing")
        XCTAssertFalse(importing.failed)   // complete + terminal is success, not failure
    }

    func testErrorHoldsAtTheLastStageSeen() {
        let s = QueueRules.state(protocol: "usenet", phase: "error", phaseTerminal: true, lastSeenPhase: "caching")
        XCTAssertTrue(s.failed)
        XCTAssertEqual(s.currentLabel, "Caching")
        XCTAssertEqual(s.completed, 3)
    }

    func testColdErrorHasNoPosition() {
        let s = QueueRules.state(protocol: "usenet", phase: "error", phaseTerminal: true)
        XCTAssertTrue(s.failed)
        XCTAssertNil(s.current)
        XCTAssertEqual(s.ring, 0)
    }

    func testMemoryKeepsTheLastLivePhase() {
        var memory = QueueRules.remember([:], items: [(id: 1, phase: "parsing"), (id: 2, phase: "linking")])
        memory = QueueRules.remember(memory, items: [(id: 1, phase: "caching"), (id: 2, phase: "error")])
        XCTAssertEqual(memory[1], "caching")
        XCTAssertEqual(memory[2], "linking")          // the error didn't overwrite it
        memory = QueueRules.remember(memory, items: [(id: 2, phase: "error")])
        XCTAssertNil(memory[1])                       // left the queue: forgotten
    }
}
