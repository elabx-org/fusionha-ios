import XCTest
@testable import FusionhaKit

/// The title page's version strip (D4): chip labels and status mapping.
final class VersionStripTests: XCTestCase {
    private func detail(_ json: String) throws -> ItemDetail {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(json.utf8))
    }

    private func fixture(_ name: String) throws -> ItemDetail {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(contentsOf: url))
    }

    private func queue(_ id: Int, status: String = "downloading", progress: Double = 42, item: Int = 1,
                       edition: Int = 2, extra: String = "") throws -> QueueItem {
        let json = """
        {"id":\(id),"title":"T","status":"\(status)","size":1e9,"sizeleft":5e8,"progress":\(progress),
         "stalled":false,"media_item_id":\(item),"edition_id":\(edition),"tier":"UHD-2160p"\(extra)}
        """
        return try APIClient.decoder.decode(QueueItem.self, from: Data(json.utf8))
    }

    private let done = VersionStatusDisplay(key: .downloaded, word: "Downloaded", count: nil)
    private let wanted = VersionStatusDisplay(key: .missing, word: "Wanted", count: nil)

    func testQualityWords() {
        XCTAssertEqual(VersionStrip.quality("BLURAY_1080P"), "1080p")
        XCTAssertEqual(VersionStrip.quality("WEBDL_2160P"), "2160p")
        XCTAssertEqual(VersionStrip.quality("REMUX_2160P"), "2160p Remux")
        XCTAssertEqual(VersionStrip.quality("DVD"), "DVD")
        XCTAssertNil(VersionStrip.quality(nil))
        XCTAssertNil(VersionStrip.quality(""))
        XCTAssertNil(VersionStrip.quality("UNKNOWN"))
    }

    func testLabels() {
        let hd = VersionStripChip(editionId: 1, tier: .hd, edition: "", qualityCode: "BLURAY_1080P",
                                  status: done, progress: nil, held: false)
        XCTAssertEqual(hd.text, "HD · 1080p")
        XCTAssertNil(hd.detail)
        XCTAssertEqual(hd.status, .downloaded)

        let cut = VersionStripChip(editionId: 2, tier: .uhd, edition: "Director's Cut", qualityCode: "REMUX_2160P",
                                   status: done, progress: nil, held: false)
        XCTAssertEqual(cut.text, "4K · 2160p Remux · Director's Cut")

        let none = VersionStripChip(editionId: 3, tier: .uhd, edition: "", qualityCode: nil,
                                    status: wanted, progress: nil, held: false)
        XCTAssertEqual(none.text, "4K · wanted")
        XCTAssertEqual(none.status, .missing)
    }

    func testStatusMapping() {
        let dl = VersionStatusDisplay(key: .downloading, word: "Downloading", count: nil)
        XCTAssertEqual(VersionStrip.detail(status: dl, progress: 41.6, held: false), "42%")
        XCTAssertEqual(VersionStrip.detail(status: dl, progress: nil, held: false), "downloading")
        let up = VersionStatusDisplay(key: .upgrading, word: "Upgrading", count: nil)
        XCTAssertEqual(VersionStrip.detail(status: up, progress: 120, held: false), "upgrading 100%")
        let missing = VersionStatusDisplay(key: .missing, word: "Missing", count: 3)
        XCTAssertEqual(VersionStrip.detail(status: missing, progress: nil, held: false), "missing 3")
        XCTAssertNil(VersionStrip.detail(status: done, progress: nil, held: false))

        let held = VersionStripChip(editionId: 4, tier: .hd, edition: "", qualityCode: nil,
                                    status: dl, progress: 100, held: true)
        XCTAssertEqual(held.text, "HD · needs you")
        XCTAssertEqual(held.status, .stuck)
    }

    func testMovieQualityFromFixture() throws {
        let matrix = try fixture("detail_matrix")
        let codes = matrix.versionsSorted.map { VersionStrip.qualityCode(matrix, edition: $0) }
        XCTAssertEqual(codes, ["BLURAY_1080P", "REMUX_2160P"])
    }

    func testSeriesQualityIsTheMostCommon() throws {
        let show = try detail("""
        {"id": 5, "title": "Show", "kind": "series",
         "versions": [{"id": 7, "tier": "HD-1080p", "monitored": true},
                      {"id": 8, "tier": "UHD-2160p", "monitored": true}],
         "seasons": [{"season_number": 1, "monitored": true, "episodes": [
            {"id": 1, "episode_number": 1, "files": [{"version_id": 7, "file": {"id": 1, "quality": "HDTV_1080P"}}]},
            {"id": 2, "episode_number": 2, "files": [{"version_id": 7, "file": {"id": 2, "quality": "WEBDL_1080P"}}]},
            {"id": 3, "episode_number": 3, "files": [{"version_id": 7, "file": {"id": 3, "quality": "WEBDL_1080P"}}]}]}]}
        """)
        let hd = try XCTUnwrap(show.editions.first { $0.id == 7 })
        let uhd = try XCTUnwrap(show.editions.first { $0.id == 8 })
        XCTAssertEqual(VersionStrip.qualityCode(show, edition: hd), "WEBDL_1080P")
        XCTAssertNil(VersionStrip.qualityCode(show, edition: uhd))
        XCTAssertTrue(VersionStrip.hasFiles(show, editionId: 7))
        XCTAssertFalse(VersionStrip.hasFiles(show, editionId: 8))
    }

    func testQueueRows() throws {
        let rows = [try queue(1, progress: 40), try queue(2, progress: 60), try queue(3, status: "completed"),
                    try queue(4, item: 9), try queue(5, edition: 3)]
        let live = VersionStrip.liveRows(rows, itemId: 1, editionId: 2)
        XCTAssertEqual(live.map(\.id), [1, 2])
        XCTAssertEqual(VersionStrip.progress(live), 50)
        XCTAssertNil(VersionStrip.progress([]))
        XCTAssertFalse(VersionStrip.isHeld(live))
        XCTAssertTrue(VersionStrip.isHeld([try queue(6, status: "held")]))
        XCTAssertTrue(VersionStrip.isHeld([try queue(7, extra: #","needs_attention":true"#)]))
    }
}
