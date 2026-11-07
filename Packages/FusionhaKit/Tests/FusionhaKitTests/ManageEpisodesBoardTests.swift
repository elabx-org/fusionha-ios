import XCTest
@testable import FusionhaKit

final class ManageEpisodesBoardTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private let gb = ManageEpisodes.gigabyte

    private let detailJSON = """
    {"id": 7, "title": "13 Reasons Why", "kind": "series",
     "versions": [{"id": 1, "tier": "HD-1080p", "monitored": true}],
     "seasons": [
       {"season_number": 1, "monitored": true, "episodes": [
         {"id": 11, "episode_number": 1, "title": "Tape 1 Side A", "runtime": 54, "monitored": true,
          "files": [{"version_id": 1, "tier": "HD-1080p", "file": {"id": 1, "audio_codec": "EAC3", "audio_channels": "5.1"}}]},
         {"id": 12, "episode_number": 2, "title": "Tape 1 Side B", "runtime": 52, "monitored": true,
          "files": [{"version_id": 1, "tier": "HD-1080p", "file": {"id": 2, "audio_codec": "EAC3", "audio_channels": "5.1"}}]},
         {"id": 13, "episode_number": 3, "title": "Tape 2 Side A", "monitored": true,
          "files": [{"version_id": 1, "tier": "HD-1080p", "file": {"id": 3, "audio_codec": "EAC3", "audio_channels": "5.1"}}]}]},
       {"season_number": 4, "monitored": true, "episodes": [
         {"id": 41, "episode_number": 1, "title": "Winter Break", "monitored": true},
         {"id": 42, "episode_number": 2, "title": "College Tour", "monitored": true}]}]}
    """

    private func row(_ id: Int, season: Int?, episodes: [Int], group: String, quality: String, size: Double) -> String {
        """
        {"file_id": \(id), "version_id": 1, "tier": "HD-1080p", "relative_path": "S/\(id).mkv",
         "season": \(season.map(String.init) ?? "null"), "episodes": \(episodes), "release_group": "\(group)",
         "quality": "\(quality)", "languages": ["English"], "size": \(size), "indexer_flags": []}
        """
    }

    private func board() throws -> (ItemDetail, [ManageSeasonGroup]) {
        let detail = try decode(ItemDetail.self, detailJSON)
        let rows = try decode(ManagedFilesResponse.self, """
        {"rows": [\(row(42, season: 4, episodes: [2], group: "NTb", quality: "WEBRIP_1080P", size: 3.5 * gb)),
                  \(row(3, season: 1, episodes: [3], group: "NTb", quality: "WEBDL_1080P", size: 2.5 * gb)),
                  \(row(1, season: 1, episodes: [1], group: "Kitsune", quality: "WEBDL_1080P", size: 2 * gb)),
                  \(row(2, season: 1, episodes: [2], group: "Kitsune", quality: "WEBDL_1080P", size: 2 * gb)),
                  \(row(41, season: 4, episodes: [1], group: "NTb", quality: "WEBRIP_1080P", size: 4 * gb)),
                  \(row(99, season: nil, episodes: [], group: "X", quality: "WEBDL_1080P", size: 1 * gb))]}
        """).rows
        let items = ManagedFileRules.items(rows, detail: detail, scopeVersionIds: nil, season: nil)
        return (detail, ManageEpisodes.groups(items, detail: detail))
    }

    func testGroupsBySeasonWithSharedFactsAndDifferences() throws {
        let (_, groups) = try board()
        XCTAssertEqual(groups.map(\.season), [1, 4, -1])
        XCTAssertEqual(groups.map(\.title), ["Season 1", "Season 4", "Other files"])
        let s1 = groups[0]
        XCTAssertEqual(s1.lines.map(\.id), [1, 2, 3])
        XCTAssertEqual(s1.lines.map(\.code), ["S01·E01", "S01·E02", "S01·E03"])
        XCTAssertEqual(s1.lines[0].title, "Tape 1 Side A")
        XCTAssertEqual(s1.lines[0].minutes, 54)
        XCTAssertEqual(s1.count, 3)
        XCTAssertEqual(s1.bytes, 6.5 * gb)
        XCTAssertEqual(s1.tiers, [.hd])
        XCTAssertEqual(s1.shared.map(\.text), ["WEB-DL 1080p", "EAC3 5.1", "Kitsune"])
        // Rows that match say nothing; the odd group is flagged.
        XCTAssertTrue(s1.lines[0].chips.isEmpty)
        XCTAssertEqual(s1.lines[2].chips, [ManageFact(kind: .group, text: "NTb", differs: true)])
        // Season 4 has no audio probed: no audio chip anywhere.
        XCTAssertEqual(groups[1].shared.map(\.kind), [.source, .group])
        // A lone file shares nothing, so its facts show plainly on the row.
        XCTAssertTrue(groups[2].shared.isEmpty)
        XCTAssertEqual(groups[2].lines[0].chips.map(\.differs), [false, false])
        XCTAssertEqual(groups[2].lines[0].code, "—")
    }

    func testSeasonTriStateAndToggle() throws {
        let (_, groups) = try board()
        let s1 = groups[0]
        XCTAssertEqual(ManageEpisodes.state(s1, selected: []), .none)
        XCTAssertEqual(ManageEpisodes.state(s1, selected: [1]), .partial)
        var sel = ManageEpisodes.toggling(s1, in: [1, 41])
        XCTAssertEqual(sel, [1, 2, 3, 41])
        XCTAssertEqual(ManageEpisodes.state(s1, selected: sel), .all)
        sel = ManageEpisodes.toggling(s1, in: sel)
        XCTAssertEqual(sel, [41])
    }

    func testSummaryAndWords() throws {
        let (_, groups) = try board()
        let one = ManageEpisodes.summary([1, 2], groups: groups)
        XCTAssertEqual(one.count, 2)
        XCTAssertEqual(one.seasonsText, "Season 1")
        let two = ManageEpisodes.summary([1, 2, 3, 41, 42], groups: groups)
        XCTAssertEqual(two.count, 5)
        XCTAssertEqual(two.bytes, 14 * gb)
        XCTAssertEqual(two.seasons, [1, 4])
        XCTAssertEqual(two.seasonsText, "Seasons 1 and 4")
        XCTAssertEqual(two.size, "14 GB")
        XCTAssertEqual(ManageEpisodes.summary([1, 41, 99], groups: groups).seasonsText, "3 seasons")
        XCTAssertEqual(ManageEpisodes.seasonsText([0, 2]), "Specials and Season 2")
        XCTAssertEqual(ManageEpisodes.seasonsText([0]), "Specials")
        XCTAssertEqual(ManageEpisodes.deleteMessage(two, title: "13 Reasons Why"),
                       "Seasons 1 and 4 of 13 Reasons Why. This frees 14 GB. The files are removed from disk; the episodes stay in your library.")
    }

    func testSelectBy() throws {
        let (_, groups) = try board()
        XCTAssertEqual(ManageEpisodes.releaseGroups(groups), ["NTb", "Kitsune", "X"])
        XCTAssertEqual(ManageEpisodes.qualities(groups), ["WEBDL_1080P", "WEBRIP_1080P"])
        XCTAssertEqual(ManageEpisodes.ids(groups, releaseGroup: "Kitsune"), [1, 2])
        XCTAssertEqual(ManageEpisodes.ids(groups, quality: "WEBRIP_1080P"), [41, 42])
        XCTAssertEqual(ManageEpisodes.ids(groups, largerThan: 3 * gb), [41, 42])
        XCTAssertEqual(ManageEpisodes.sizeSteps(groups), [1, 2, 3])
    }

    func testEpisodeIdsForUnmonitor() throws {
        let (detail, groups) = try board()
        let items = groups.flatMap(\.lines).filter { [1, 41, 99].contains($0.id) }.map(\.item)
        XCTAssertEqual(ManageEpisodes.episodeIds(items, detail: detail), [11, 41])
    }

    func testSharedValueNeedsAMajority() {
        XCTAssertNil(ManageEpisodes.sharedValue(["a"]))
        XCTAssertNil(ManageEpisodes.sharedValue(["a", "b"]))
        XCTAssertEqual(ManageEpisodes.sharedValue(["a", "a", "b", nil]), "a")
    }
}
