import XCTest
@testable import FusionhaKit

final class ManagedFilesTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private let detailJSON = """
    {"id": 7, "title": "Show", "kind": "series",
     "versions": [{"id": 1, "tier": "HD-1080p", "monitored": true}, {"id": 2, "tier": "UHD-2160p", "monitored": false}],
     "seasons": [{"season_number": 1, "monitored": true, "episodes": [
        {"id": 11, "episode_number": 1, "monitored": true}, {"id": 12, "episode_number": 2, "monitored": false}]},
       {"season_number": 2, "monitored": true, "episodes": [{"id": 21, "episode_number": 1, "monitored": true}]}]}
    """

    private func row(_ id: Int, version: Int, season: Int?, episodes: [Int], extra: String = "") -> String {
        """
        {"file_id": \(id), "version_id": \(version), "tier": "\(version == 1 ? "HD-1080p" : "UHD-2160p")",
         "relative_path": "Season 01/Show - S01E0\(id).mkv", "season": \(season.map(String.init) ?? "null"),
         "episodes": \(episodes), "release_group": "NTb", "quality": "WEBDL_1080P", "languages": ["English"],
         "size": 1500000000, "release_type": "singleEpisode", "indexer_flags": [], "proper_version": 1,
         "is_real": false, "cf_score": 0, "link_unresolved": false, "unresolved": false\(extra)}
        """
    }

    func testScopeSeasonAndMonitoredGate() throws {
        let detail = try decode(ItemDetail.self, detailJSON)
        let rows = try decode(ManagedFilesResponse.self, """
        {"rows": [\(row(1, version: 1, season: 1, episodes: [1])), \(row(2, version: 1, season: 1, episodes: [2])),
                  \(row(3, version: 2, season: 1, episodes: [1])), \(row(4, version: 1, season: 2, episodes: [1]))]}
        """).rows

        let all = ManagedFileRules.items(rows, detail: detail, scopeVersionIds: nil, season: nil)
        XCTAssertEqual(all.map(\.id), [1, 2, 3, 4])
        // Unmonitored episode, and an unmonitored version, fall back to Clean up.
        XCTAssertEqual(all.map(\.monitored), [true, false, false, true])

        let hdSeason1 = ManagedFileRules.items(rows, detail: detail, scopeVersionIds: [1], season: 1)
        XCTAssertEqual(hdSeason1.map(\.id), [1, 2])
        XCTAssertEqual(ManagedFileRules.commonSeason(hdSeason1), 1)
        XCTAssertNil(ManagedFileRules.commonSeason(all))
    }

    func testLabelsAndHealth() throws {
        let r = try decode(ManagedFileRow.self, row(5, version: 1, season: 1, episodes: [3, 1, 2],
                                                    extra: #", "runtime_seconds": 2714"#))
        let item = ManagedFileItem(row: r, monitored: true)
        XCTAssertEqual(item.episodeLabel, "S01·E01–E03")
        XCTAssertEqual(item.name, "Show - S01E05.mkv")
        XCTAssertTrue(item.facts.contains("WEBDL-1080p"))
        XCTAssertTrue(item.facts.contains("45m 14s"))
        XCTAssertFalse(item.dead)

        let dead = try decode(ManagedFileRow.self, row(6, version: 1, season: nil, episodes: [])
            .replacingOccurrences(of: "\"unresolved\": false", with: "\"unresolved\": true"))
        let deadItem = ManagedFileItem(row: dead, monitored: true)
        XCTAssertTrue(deadItem.dead)
        XCTAssertTrue(deadItem.absent)
        XCTAssertNil(deadItem.episodeLabel)
        XCTAssertEqual(ManagedFileVocab.runtime(300), "5m")
        XCTAssertEqual(ManagedFileVocab.releaseTypeLabel("seasonPack"), "Season Pack")
    }
}
