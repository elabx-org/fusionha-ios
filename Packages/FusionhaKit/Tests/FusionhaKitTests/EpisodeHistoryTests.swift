import XCTest
@testable import FusionhaKit

final class EpisodeHistoryTests: XCTestCase {
    private func history() throws -> [HistoryEntry] {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode([HistoryEntry].self, from: Data(#"""
            [{"id": 1, "event_type": "GRABBED", "created_at": "2026-10-01T10:00:00Z", "episode_id": 5, "version_id": 1,
              "edition_id": 1, "download_id": "abc"},
             {"id": 2, "event_type": "IMPORTED", "created_at": "2026-10-02T10:00:00Z", "episode_id": null, "edition_id": 1,
              "download_id": "abc"},
             {"id": 3, "event_type": "GRABBED", "created_at": "2026-10-03T10:00:00Z", "episode_id": null, "edition_id": 2,
              "data": {"season": 2}},
             {"id": 4, "event_type": "GRABBED", "created_at": "2026-10-04T10:00:00Z", "episode_id": null, "edition_id": 1,
              "data": {"season": 3}},
             {"id": 5, "event_type": "GRABBED", "created_at": "2026-10-05T10:00:00Z", "episode_id": 6, "edition_id": 1}]
            """#.utf8))
    }

    func testDirectAndPackRowsNewestFirst() throws {
        let rows = EpisodeHistory.rows(try history(), episodeId: 5, seasonNumber: 2)
        XCTAssertEqual(rows.map(\.id), [3, 2, 1])
    }

    func testScopedToVersions() throws {
        let rows = EpisodeHistory.rows(try history(), episodeId: 5, seasonNumber: 2, versionIds: [1])
        XCTAssertEqual(rows.map(\.id), [2, 1])
    }
}
