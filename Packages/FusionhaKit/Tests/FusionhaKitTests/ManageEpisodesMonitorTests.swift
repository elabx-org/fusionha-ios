import XCTest
@testable import FusionhaKit

/// "Stop monitoring" on v2 Manage episodes (0.4.240): the bulk monitor call,
/// the multi-version default (web `cross-version.ts`) and the sheet's refresh.
final class ManageEpisodesMonitorTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func detail(uhd: Bool?) throws -> ItemDetail {
        let versions = [#"{"id": 1, "tier": "HD-1080p", "monitored": true}"#]
            + (uhd.map { [#"{"id": 2, "tier": "UHD-2160p", "monitored": \#($0)}"#] } ?? [])
        return try decode(ItemDetail.self, """
        {"id": 7, "title": "Peep Show", "kind": "series", "versions": [\(versions.joined(separator: ","))],
         "seasons": [{"season_number": 1, "monitored": true, "episodes": [
           {"id": 11, "episode_number": 1, "monitored": true},
           {"id": 12, "episode_number": 2, "monitored": true},
           {"id": 13, "episode_number": 3, "monitored": true}]},
          {"season_number": 2, "monitored": true, "episodes": [
           {"id": 21, "episode_number": 1, "monitored": true}]}]}
        """)
    }

    private func row(_ id: Int, version: Int, season: Int, episodes: [Int]) -> String {
        """
        {"file_id": \(id), "version_id": \(version), "tier": "\(version == 1 ? "HD-1080p" : "UHD-2160p")",
         "relative_path": "S/\(id).mkv", "season": \(season), "episodes": \(episodes),
         "quality": "WEBDL_1080P", "languages": [], "size": 1, "indexer_flags": []}
        """
    }

    private func rows(_ json: [String]) throws -> [ManagedFileRow] {
        try decode(ManagedFilesResponse.self, #"{"rows": [\#(json.joined(separator: ","))]}"#).rows
    }

    /// HD: a season-1 pack (E01–E03) and S02E01. UHD (with `uhdFiles`): S01E01–E03 singles.
    private func board(uhd: Bool?, uhdFiles: Bool) throws -> (ItemDetail, [ManagedFileRow], [ManagedFileItem]) {
        let d = try detail(uhd: uhd)
        var json = [row(1, version: 1, season: 1, episodes: [1, 2, 3]), row(2, version: 1, season: 2, episodes: [1])]
        if uhdFiles { json += [1, 2, 3].map { row(100 + $0, version: 2, season: 1, episodes: [$0]) } }
        let all = try rows(json)
        return (d, all, ManagedFileRules.items(all, detail: d, scopeVersionIds: nil, season: nil))
    }

    private func pick(_ items: [ManagedFileItem], _ ids: Set<Int>) -> [ManagedFileItem] {
        items.filter { ids.contains($0.id) }
    }

    func testOneVersionTitleIsPlainAndOn() throws {
        let (d, all, items) = try board(uhd: nil, uhdFiles: false)
        XCTAssertEqual(ManageEpisodes.monitorImpact(detail: d, allRows: all, deleting: pick(items, [1])), .single)
    }

    func testUnmonitoredSecondVersionCountsAsOne() throws {
        let (d, all, items) = try board(uhd: false, uhdFiles: true)
        XCTAssertEqual(ManageEpisodes.monitorImpact(detail: d, allRows: all, deleting: pick(items, [1])), .single)
    }

    func testOtherVersionKeepsFilesDefaultsOff() throws {
        let (d, all, items) = try board(uhd: true, uhdFiles: true)
        let impact = ManageEpisodes.monitorImpact(detail: d, allRows: all, deleting: pick(items, [1]))
        XCTAssertEqual(impact, ManageMonitorImpact(multiVersion: true, otherVersionIds: [2], defaultStop: false))
    }

    func testOtherVersionWantedSlotDefaultsOff() throws {
        let (d, all, items) = try board(uhd: true, uhdFiles: false)
        let impact = ManageEpisodes.monitorImpact(detail: d, allRows: all, deleting: pick(items, [2]))
        XCTAssertEqual(impact, ManageMonitorImpact(multiVersion: true, otherVersionIds: [2], defaultStop: false))
    }

    func testClearingEveryVersionDefaultsOn() throws {
        let (d, all, items) = try board(uhd: true, uhdFiles: true)
        let impact = ManageEpisodes.monitorImpact(detail: d, allRows: all, deleting: pick(items, [1, 101, 102, 103]))
        XCTAssertEqual(impact, ManageMonitorImpact(multiVersion: true, otherVersionIds: [], defaultStop: true))
    }

    func testScopedSheetStillSeesTheOtherVersionsFiles() throws {
        let (d, all, _) = try board(uhd: true, uhdFiles: true)
        let hdOnly = ManagedFileRules.items(all, detail: d, scopeVersionIds: [1], season: nil)
        XCTAssertFalse(ManageEpisodes.monitorImpact(detail: d, allRows: all, deleting: pick(hdOnly, [1])).defaultStop)
    }

    func testSeasonPackSendsEveryEpisodeItCovers() throws {
        let (d, _, items) = try board(uhd: nil, uhdFiles: false)
        XCTAssertEqual(ManageEpisodes.episodeIds(pick(items, [1]), detail: d), [11, 12, 13])
    }

    func testUnmonitoringRedrawsOnlyTheCoveredRows() throws {
        let (d, _, items) = try board(uhd: true, uhdFiles: true)
        XCTAssertTrue(items.allSatisfy(\.monitored))
        let after = ManageEpisodes.unmonitoring(items, episodeIds: [12], detail: d)
        XCTAssertEqual(after.filter { !$0.monitored }.map(\.id), [1, 102])
        XCTAssertEqual(ManageEpisodes.unmonitoring(items, episodeIds: [], detail: d), items)
    }

    func testBulkMonitorRequestAndDecode() async throws {
        ItemActionsStubProtocol.responseBody = Data(#"{"updated_ids": [11, 12], "skipped_ids": [99]}"#.utf8)
        ItemActionsStubProtocol.status = 200
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ItemActionsStubProtocol.self]
        let api = APIClient(baseURL: URL(string: "http://fh.test")!, token: "k", session: URLSession(configuration: config))
        let result = try await api.setEpisodesMonitored(itemId: 7, episodeIds: [11, 12, 99], monitored: false)
        XCTAssertEqual(result, EpisodesMonitorResult(updatedIds: [11, 12], skippedIds: [99]))
        XCTAssertEqual(ItemActionsStubProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(ItemActionsStubProtocol.lastRequest?.url?.path, "/api/v1/library/7/episodes/monitor")
        let body = try XCTUnwrap(ItemActionsStubProtocol.lastBody)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(sent.keys), ["episode_ids", "monitored"])
        XCTAssertEqual(sent["episode_ids"] as? [Int], [11, 12, 99])
        XCTAssertEqual(sent["monitored"] as? Bool, false)
    }
}
