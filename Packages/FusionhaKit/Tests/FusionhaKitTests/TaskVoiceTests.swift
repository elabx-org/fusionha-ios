import XCTest
@testable import FusionhaKit

final class TaskVoiceTests: XCTestCase {
    func testQuipKind() {
        XCTAssertEqual(TaskVoice.quipKind("movie"), .movie)
        XCTAssertEqual(TaskVoice.quipKind("anime"), .anime)
        XCTAssertEqual(TaskVoice.quipKind("series"), .series)
        XCTAssertEqual(TaskVoice.quipKind(nil), .series)
    }

    func testOutcomeOrder() {
        XCTAssertEqual(TaskVoice.outcome(status: "failed", grabbed: 3, upgraded: 0), .failed)
        XCTAssertEqual(TaskVoice.outcome(status: "running", grabbed: 3, upgraded: 0), .running)
        XCTAssertEqual(TaskVoice.outcome(status: "completed", grabbed: 1, upgraded: 1), .grabbed)
        XCTAssertEqual(TaskVoice.outcome(status: "completed", grabbed: 0, upgraded: 2), .upgraded)
        XCTAssertEqual(TaskVoice.outcome(status: "completed", grabbed: 0, upgraded: 0), .noRelease)
    }

    func testFailureUsesFailurePool() {
        let line = VoiceQuip.mediaSuffix(kind: .movie, title: "Dune",
                                         outcome: TaskVoice.outcome(status: "failed", grabbed: 0, upgraded: 0))
        XCTAssertTrue(VoiceQuip.pools[.failure]!.contains(line))
    }
}
