import XCTest
@testable import FusionhaKit

/// The queue's one state per download (`QueueItem.rowState`) and the figure
/// its bar, badge and percent share, against what the stored-state
/// `/api/v1/queue` really sends: `status` stays "queued" and `sizeleft` 0.
final class QueueRowStateTests: XCTestCase {
    private func item(status: String = "queued", size: Double = 1.5e9, left: Double = 0, progress: Double = 0,
                      extra: String = "") throws -> QueueItem {
        let json = """
        {"id":1,"title":"Daisy Jones & the Six","status":"\(status)","size":\(size),"sizeleft":\(left),
         "progress":\(progress),"stalled":false,"media_item_id":7,"edition_id":3,"tier":"HD-1080p",
         "protocol":"usenet"\(extra)}
        """
        return try APIClient.decoder.decode(QueueItem.self, from: Data(json.utf8))
    }

    private let bytesPlan = #","stages":{"mode":"bytes","optional_source":"settings"}"#

    // The 06:22 screenshot: HONE 1.5 GB at 100%, nothing imported yet.
    func testFinishedDownloadAwaitsImport() throws {
        let done = try item(progress: 100, extra: bytesPlan)
        XCTAssertEqual(done.rowState, .awaitingImport)
        XCTAssertEqual(done.percentDone, 100)
        XCTAssertEqual(done.fraction, 1)
        XCTAssertTrue(done.finishedDownloading)
        // The same on a server that does report "downloading".
        XCTAssertEqual(try item(status: "downloading", progress: 100).rowState, .awaitingImport)
    }

    func testImportRunningIsImporting() throws {
        XCTAssertEqual(try item(progress: 100, extra: #","phase":"importing","step":"tv""#).rowState, .importing)
        XCTAssertEqual(try item(status: "completed", progress: 100).rowState, .importing)
        XCTAssertEqual(try item(progress: 100, extra: #","phase":"complete","phase_percent":100"#).rowState, .importing)
    }

    func testProgressMeansDownloadingWhateverTheStatusSays() throws {
        let moving = try item(progress: 42, extra: bytesPlan)
        XCTAssertEqual(moving.rowState, .downloading)
        XCTAssertEqual(moving.percentDone, 42)   // not 100 from the missing sizeleft
        XCTAssertEqual(moving.fraction, 0.42, accuracy: 0.0001)
        XCTAssertEqual(try item(status: "downloading", progress: 10).rowState, .downloading)
        // A live remaining count still wins when the server has one.
        let live = try item(status: "downloading", size: 1e9, left: 2.5e8, progress: 0)
        XCTAssertEqual(live.percentDone, 75)
        XCTAssertEqual(live.rowState, .downloading)
    }

    func testNotStartedIsQueued() throws {
        let waiting = try item(progress: 0, extra: bytesPlan)
        XCTAssertEqual(waiting.rowState, .queued)
        XCTAssertEqual(waiting.percentDone, 0)
        XCTAssertFalse(waiting.hasStarted)
        XCTAssertEqual(try item(size: 3.4e9, left: 3.4e9).rowState, .queued)
        XCTAssertEqual(try item(status: "paused").rowState, .queued)
        // decypharr's first usenet stage is a queue too.
        XCTAssertEqual(try item(extra: #","phase":"queued","phase_percent":5"#).rowState, .queued)
    }

    func testHeldAndStuckNeedYou() throws {
        XCTAssertEqual(try item(status: "held", progress: 100, extra: #","held_reason":"not_an_upgrade""#).rowState, .held)
        XCTAssertEqual(try item(progress: 100, extra: #","needs_attention":true"#).rowState, .stuck)
    }

    func testPhaseJobsAndClientLimbo() throws {
        XCTAssertEqual(try item(progress: 100, extra: #","phase":"linking","phase_percent":65"#).rowState, .processing)
        XCTAssertEqual(try item(extra: #","phase":"error","phase_terminal":true,"phase_percent":0"#).rowState, .failed)
        XCTAssertEqual(try item(extra: #","warning":"awaiting the download client""#).rowState, .waitingForClient)
    }

    func testTitleBadgeProgressUsesTheSameFigure() throws {
        XCTAssertEqual(QueueProgress(try item(progress: 30)).percent, 30)
        XCTAssertEqual(QueueProgress(try item(status: "downloading", size: 1e9, left: 5e8, progress: 0)).percent, 50)
    }
}
