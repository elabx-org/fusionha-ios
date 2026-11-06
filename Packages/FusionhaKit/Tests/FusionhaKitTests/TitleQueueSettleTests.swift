import XCTest
@testable import FusionhaKit

final class TitleQueueSettleTests: XCTestCase {
    private func row(_ id: Int, item: Int = 7, status: String = "downloading", progress: Double = 50,
                     extra: String = "") throws -> QueueItem {
        let json = """
        {"id":\(id),"title":"Title","status":"\(status)","size":1e9,"sizeleft":5e8,"progress":\(progress),
         "stalled":false,"media_item_id":\(item),"edition_id":1,"tier":"HD-1080p"\(extra)}
        """
        return try APIClient.decoder.decode(QueueItem.self, from: Data(json.utf8))
    }

    func testRowLeavingTheQueueReloads() throws {
        let before = [try row(1)]
        XCTAssertTrue(TitleQueueSettle.shouldReload(itemId: 7, before: before, after: []))
        // A completed row that then leaves (the import landed) reloads too.
        XCTAssertTrue(TitleQueueSettle.shouldReload(itemId: 7, before: [try row(1, status: "completed")], after: []))
    }

    func testRowFinishingReloads() throws {
        let before = [try row(1)]
        XCTAssertTrue(TitleQueueSettle.shouldReload(itemId: 7, before: before, after: [try row(1, status: "completed", progress: 100)]))
        XCTAssertTrue(TitleQueueSettle.shouldReload(itemId: 7, before: before, after: [try row(1, status: "failed")]))
        XCTAssertTrue(TitleQueueSettle.shouldReload(itemId: 7, before: before,
                                                    after: [try row(1, extra: #","phase":"error","phase_terminal":true"#)]))
    }

    func testProgressAndNewRowsDoNotReload() throws {
        let before = [try row(1, progress: 40)]
        XCTAssertFalse(TitleQueueSettle.shouldReload(itemId: 7, before: before, after: [try row(1, progress: 60)]))
        XCTAssertFalse(TitleQueueSettle.shouldReload(itemId: 7, before: [], after: [try row(2)]))
        XCTAssertFalse(TitleQueueSettle.shouldReload(itemId: 7, before: before, after: [try row(1), try row(2)]))
        // A row that was already finished and stays finished: nothing new.
        let done = [try row(1, status: "completed", progress: 100)]
        XCTAssertFalse(TitleQueueSettle.shouldReload(itemId: 7, before: done, after: done))
    }

    func testOtherTitlesAreIgnored() throws {
        XCTAssertFalse(TitleQueueSettle.shouldReload(itemId: 7, before: [try row(1, item: 8)], after: []))
    }
}
