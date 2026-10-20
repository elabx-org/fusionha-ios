import XCTest
@testable import FusionhaKit

final class DownloadsBarTests: XCTestCase {
    private func item(_ id: Int, status: String = "downloading", size: Double = 1e9, left: Double = 5e8,
                      progress: Double = 50, tier: String = "HD-1080p", age: Double = 600,
                      extra: String = "") throws -> QueueItem {
        let json = """
        {"id":\(id),"title":"Title \(id)","status":"\(status)","size":\(size),"sizeleft":\(left),"progress":\(progress),
         "stalled":false,"media_item_id":\(id + 1000),"edition_id":1,"tier":"\(tier)","age_seconds":\(age)\(extra)}
        """
        return try APIClient.decoder.decode(QueueItem.self, from: Data(json.utf8))
    }

    func testNeedsYouOutranksProgress() throws {
        let items = [try item(1, size: 9e9), try item(2, status: "failed"), try item(3, status: "held", progress: 100)]
        XCTAssertEqual(DownloadsBar.lead(items)?.id, 3)
        XCTAssertEqual(DownloadsBar.lead(Array(items.prefix(2)))?.id, 2)
        let stuck = try item(4, extra: #","needs_attention":true"#)
        XCTAssertEqual(DownloadsBar.lead([try item(1), stuck])?.id, 4)
    }

    func testLargestActiveThenMostRecent() throws {
        let items = [try item(1, size: 2e9, left: 1e9), try item(2, size: 8e9, left: 4e9),
                     try item(3, status: "queued", size: 50e9, left: 50e9, progress: 0)]
        XCTAssertEqual(DownloadsBar.lead(items)?.id, 2)
        let waiting = [try item(5, status: "queued", age: 900), try item(6, status: "completed", progress: 100, age: 60)]
        XCTAssertEqual(DownloadsBar.lead(waiting)?.id, 6)
        XCTAssertNil(DownloadsBar.lead([]))
    }

    func testSummaryWords() throws {
        let items = [
            try item(1, size: 4e9, left: 2e9, tier: "UHD-2160p",
                     extra: #","episode_label":"S02E07 · Chikhai Bardo","eta_seconds":360"#),
            try item(2, size: 2e9, left: 1.5e9, extra: #","eta_seconds":120"#),
        ]
        let s = try XCTUnwrap(DownloadsBar.summary(items))
        XCTAssertEqual(s.leadId, 1)
        XCTAssertEqual(s.heading, "Title 1 S02E07")
        XCTAssertEqual(s.tiers, [.uhd, .hd])
        XCTAssertEqual(s.percent, 42)
        XCTAssertEqual(s.leadFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(DownloadsBar.detailLine(s), "2 downloading · 2.3 of 5.6 GB · 6 min")
        XCTAssertEqual(DownloadsBar.inlineLine(s), "2 downloading")
        XCTAssertEqual(DownloadsBar.spoken(s), "Downloads, 2 downloading, 42 percent. Title 1 season 2 episode 7, 4K.")
    }

    func testNeedLineAndSpoken() throws {
        let items = [try item(1, status: "held", progress: 100), try item(2), try item(3)]
        let s = try XCTUnwrap(DownloadsBar.summary(items))
        XCTAssertEqual(s.need, .held)
        XCTAssertEqual(DownloadsBar.detailLine(s), "Import waiting · +2 downloading")
        XCTAssertEqual(DownloadsBar.inlineLine(s), "Import waiting")
        XCTAssertEqual(s.percent, 50)
        XCTAssertTrue(DownloadsBar.spoken(s).hasPrefix("Downloads, needs you: Import waiting, 2 downloading"))
        let alone = try XCTUnwrap(DownloadsBar.summary([try item(1, status: "held", progress: 100)]))
        XCTAssertEqual(DownloadsBar.detailLine(alone), "Import waiting")
        let display = try item(4, status: "held", extra: #","held":{"code":"x","short":"Not an upgrade","text":"Not an upgrade."}"#)
        XCTAssertEqual(DownloadsBar.summary([display])?.reason, "Not an upgrade")
    }

    func testFinishedOnlyAfterAMovingLead() throws {
        let moving = DownloadsBar.summary([try item(1)])
        let held = DownloadsBar.summary([try item(1, status: "held")])
        XCTAssertEqual(DownloadsBar.finished(previous: moving, nowEmpty: true)?.leadId, 1)
        XCTAssertNil(DownloadsBar.finished(previous: moving, nowEmpty: false))
        XCTAssertNil(DownloadsBar.finished(previous: held, nowEmpty: true))
        XCTAssertNil(DownloadsBar.finished(previous: nil, nowEmpty: true))
    }

    func testSizesAndDuration() {
        XCTAssertEqual(DownloadsBar.sizes(done: 640 * 1024 * 1024, total: 1.4 * 1024 * 1024 * 1024), "640 MB of 1.4 GB")
        XCTAssertEqual(DownloadsBar.duration(20), "<1 min")
        XCTAssertEqual(DownloadsBar.duration(360), "6 min")
        XCTAssertEqual(DownloadsBar.duration(4800), "1 h 20 min")
        XCTAssertEqual(DownloadsBar.duration(7200), "2 h")
    }
}
