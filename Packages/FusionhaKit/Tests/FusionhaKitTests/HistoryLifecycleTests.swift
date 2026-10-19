import XCTest
@testable import FusionhaKit

final class HistoryLifecycleTests: XCTestCase {
    private func entry(_ id: Int, type: String = "GRABBED", version: Int? = 1, tier: String? = "HD-1080p",
                       episode: Int? = nil, data: String = "null") throws -> HistoryEntry {
        let json = """
        {"id": \(id), "event_type": "\(type)", "created_at": "2026-07-01T00:00:00Z",
         "version_id": \(version.map(String.init) ?? "null"), "edition_id": \(version.map(String.init) ?? "null"),
         "tier": \(tier.map { "\"\($0)\"" } ?? "null"), "episode_id": \(episode.map(String.init) ?? "null"), "data": \(data)}
        """
        return try APIClient.decoder.decode(HistoryEntry.self, from: Data(json.utf8))
    }

    private let heldData = #"{"reason_code": "mislabeled_resolution", "reason": "x", "claimed_quality": "WEBDL-1080p", "probed_quality": "SDTV-480p", "probed_resolution": {"w": 640, "h": 480}, "release_group": "TSRG", "download_size": 1048576, "release_blocklisted": true}"#

    func testParsesHeldData() throws {
        let e = try entry(1, type: "HELD", data: heldData)
        let d = try XCTUnwrap(HeldEventData.parse(e.data))
        XCTAssertEqual(d.probedResolution, HeldResolution(w: 640, h: 480))
        XCTAssertEqual(d.releaseGroup, "TSRG")
        XCTAssertTrue(d.releaseBlocklisted)
        XCTAssertTrue(d.isProvenMislabel)
        XCTAssertEqual(d.stepTitle(held: nil), "Held: not really 1080p")
        XCTAssertEqual(d.probedLine, "Probed: 640×480 · Release says 1080p · file is 480p")
    }

    func testMalformedHeldData() throws {
        XCTAssertNil(HeldEventData.parse(try entry(1, type: "HELD", data: #"{"reason": "x"}"#).data))
    }

    func testEpisodeCode() {
        XCTAssertEqual(HistoryLifecycleModel.episodeCode("S2E3 · Pilot"), "S02·E03")
        XCTAssertEqual(HistoryLifecycleModel.episodeCode("S10E12"), "S10·E12")
        XCTAssertNil(HistoryLifecycleModel.episodeCode(nil))
        XCTAssertNil(HistoryLifecycleModel.episodeCode("2021"))
    }

    func testPackHeldNeverReadsPerEpisode() throws {
        let rows = [try entry(1, type: "HELD", episode: nil), try entry(2, type: "IMPORTED", episode: 9)]
        XCTAssertEqual(HistoryLifecycleModel.events(rows, versionId: 1, episodeId: 9).map(\.id), [2])
    }

    func testSwitchVersionsActiveFirstOnePerTier() throws {
        let rows = [try entry(1, version: 1, tier: "HD-1080p"), try entry(2, version: 2, tier: "UHD-2160p"),
                    try entry(3, version: 3, tier: "UHD-2160p")]
        let versions = HistoryLifecycleModel.switchVersions(rows, activeId: 2, fallbackTier: nil)
        XCTAssertEqual(versions.map(\.id), [2, 1])
        XCTAssertTrue(HistoryLifecycleModel.switchVersions([], activeId: nil, fallbackTier: nil).isEmpty)
    }

    func testFailureLine() throws {
        let failed = try entry(1, type: "DOWNLOAD_FAILED", data: #"{"error": "request timed out"}"#)
        XCTAssertEqual(HistoryLifecycleModel.failureLine(failed), "Timed out — The request timed out.")
        XCTAssertNil(HistoryLifecycleModel.failureLine(try entry(2)))
    }
}
