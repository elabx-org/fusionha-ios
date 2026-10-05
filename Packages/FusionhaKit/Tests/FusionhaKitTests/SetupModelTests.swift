import XCTest
@testable import FusionhaKit

/// Setup progress (`GET /api/v1/library/setups`) decoding and the
/// setup-progress-format.ts copy.
final class SetupModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private let running = #"{"setups": [{"item_id": 7, "title": "Severance", "poster_url": null, "steps": [{"key": "added", "label": "Added to library", "source": null, "status": "done", "detail": null}, {"key": "tree", "label": "Seasons & episodes", "source": "TMDB", "status": "running", "detail": null}, {"key": "search", "label": "First search", "source": null, "status": "pending", "detail": null}], "result": null, "started_at": "2026-10-04T10:00:00", "finished_at": null}], "next_rss_at": null}"#

    func testRunningSetup() throws {
        let list = try decode(TitleSetupList.self, running)
        let setup = try XCTUnwrap(list.setups.first)
        XCTAssertTrue(list.anyActive)
        XCTAssertEqual(list.pollInterval, 2)
        XCTAssertEqual(setup.nowLabel, "Seasons & episodes…")
        XCTAssertEqual(setup.doneCount, 1)
        XCTAssertEqual(setup.progressFraction, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertNil(setup.resultLine(nextRssAt: nil))
        XCTAssertEqual(TitleSetup.cardTitle(list.setups), "Setting up Severance")
    }

    func testFinishedResultsOldAndNewKeys() throws {
        let json = #"{"setups": [{"item_id": 3, "title": "Dune", "poster_url": null, "steps": [], "result": [{"version_id": 1, "tier": "HD-1080p", "edition": null, "grabs": [{"quality": "WEBDL-1080p", "target": null, "release_title": "x"}], "grab_count": 2}, {"edition_id": 2, "tier": "UHD-2160p", "movie_edition": "IMAX", "grabs": [], "grab_count": 0}], "started_at": "2026-10-04T10:00:00", "finished_at": "2026-10-04T10:01:00"}, {"item_id": 4, "title": "Arrival", "poster_url": null, "steps": [], "result": [{"version_id": 5, "tier": "HD-1080p", "edition": null, "grabs": [], "grab_count": 0}], "started_at": "2026-10-04T10:00:00", "finished_at": "2026-10-04T10:01:00"}], "next_rss_at": "2026-10-04T10:12:00Z"}"#
        let list = try decode(TitleSetupList.self, json)
        XCTAssertFalse(list.anyActive)
        XCTAssertEqual(list.pollInterval, 20)
        let dune = list.setups[0]
        XCTAssertEqual(dune.result?[1].versionId, 2)
        XCTAssertEqual(dune.result?[1].label, "IMAX · UHD·4K")
        XCTAssertEqual(dune.nowLabel, "Ready · 2 grabbed")
        XCTAssertEqual(dune.resultLine(nextRssAt: nil)?.text,
                       "HD·1080p: grabbed WEBDL-1080p (+1 more). IMAX · UHD·4K: nothing yet.")
        let now = try XCTUnwrap(DetailText.instant("2026-10-04T10:00:00Z"))
        let arrival = list.setups[1]
        XCTAssertEqual(arrival.nowLabel, "Ready · nothing yet")
        XCTAssertEqual(arrival.resultLine(nextRssAt: list.nextRssAt, now: now)?.text,
                       "Nothing found yet. fusionha checks again with every RSS sync (next in 12 min).")
        XCTAssertEqual(TitleSetup.cardTitle(list.setups), "Setting up 2 titles")
    }

    func testEmptyPayload() throws {
        let list = try decode(TitleSetupList.self, "{}")
        XCTAssertTrue(list.setups.isEmpty)
    }
}
