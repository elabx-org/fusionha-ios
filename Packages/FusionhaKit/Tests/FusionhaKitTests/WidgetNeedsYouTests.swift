import XCTest
@testable import FusionhaKit

final class WidgetNeedsYouTests: XCTestCase {
    private func item(_ id: Int, title: String, status: String = "downloading", progress: Double = 50,
                      tier: String = "HD-1080p", extra: String = "") throws -> QueueItem {
        let json = """
        {"id":\(id),"title":"\(title)","status":"\(status)","size":1e9,"sizeleft":5e8,"progress":\(progress),
         "stalled":false,"media_item_id":\(id + 1000),"edition_id":1,"tier":"\(tier)"\(extra)}
        """
        return try APIClient.decoder.decode(QueueItem.self, from: Data(json.utf8))
    }

    func testNeedsRankedAndWorded() throws {
        let items = [
            try item(1, title: "VisionQuest", progress: 62, extra: #","episode_label":"S01E07 · Immolation""#),
            try item(2, title: "The Office", status: "failed", extra: #","episode_label":"S05""#),
            try item(3, title: "VisionQuest", status: "held", progress: 100, tier: "UHD-2160p",
                     extra: #","episode_label":"S01E07 · Immolation","held":{"code":"x","short":"not really 2160p","text":"Not really 2160p."}"#),
            try item(4, title: "Wicked", extra: #","phase":"importing""#),
        ]
        let s = WidgetNeedsYou.summary(items)
        XCTAssertEqual(s.needCount, 2)
        XCTAssertEqual(s.needs.map(\.short), ["VisionQuest E7 4K", "The Office S5 pack HD"])
        XCTAssertEqual(s.needs.map(\.detail), ["not really 2160p", "Download failed"])
        XCTAssertEqual(s.movingCount, 2)
        XCTAssertEqual(WidgetNeedsYou.Summary.joined(s.moving, withDetail: true), "VisionQuest E7 HD 62% · Wicked HD importing")
        XCTAssertEqual(s.needs.first?.title, "VisionQuest · S01E07")
    }

    func testEmpty() {
        let s = WidgetNeedsYou.summary([])
        XCTAssertEqual(s.needCount, 0)
        XCTAssertEqual(WidgetNeedsYou.Summary.joined(s.needs, withDetail: false), "")
    }
}
