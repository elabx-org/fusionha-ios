import XCTest
@testable import FusionhaKit

/// The Files tab's rows: one per file in episode order, double episodes as
/// one row, missing episodes in their place.
final class SeasonFileRowsTests: XCTestCase {
    func testEpisodeLabels() {
        XCTAssertEqual(EpisodeCode.fileEpisodes([1]), "E01")
        XCTAssertEqual(EpisodeCode.fileEpisodes([26, 25]), "E25–26")
        XCTAssertEqual(EpisodeCode.fileEpisodes([1, 2, 3]), "E01–03")
        XCTAssertEqual(EpisodeCode.fileEpisodes([1, 3]), "E01, 03")
        XCTAssertEqual(EpisodeCode.fileEpisodes([100]), "E100")
        XCTAssertEqual(EpisodeCode.fileEpisodes([]), "")
        XCTAssertEqual(EpisodeCode.fileCode(season: 1, episodes: [1]), "S01E01")
        XCTAssertEqual(EpisodeCode.fileCode(season: 1, episodes: [25, 26]), "S01E25–26")
    }

    private func season(_ json: String) throws -> Season {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(Season.self, from: Data(json.utf8))
    }

    private func episode(_ id: Int, _ n: Int, fileId: Int?, monitored: Bool = true, aired: String = "2001-01-01") -> String {
        let files = fileId.map { #"[{"version_id": 7, "tier": "HD-1080p", "file": {"id": \#($0), "size": 100}}]"# } ?? "[]"
        return #"{"id": \#(id), "episode_number": \#(n), "title": "Ep \#(n)", "air_date": "\#(aired)", "monitored": \#(monitored), "files": \#(files)}"#
    }

    func testRowsInEpisodeOrder() throws {
        let eps = [
            episode(1, 1, fileId: 501),
            episode(2, 2, fileId: nil),
            episode(3, 3, fileId: 503),
            episode(4, 4, fileId: 503),
            episode(5, 5, fileId: nil, monitored: false),
            episode(6, 6, fileId: nil, aired: "2999-01-01"),
        ].joined(separator: ",")
        let s = try season(#"{"season_number": 1, "monitored": true, "episodes": [\#(eps)]}"#)
        let rows = s.fileRows(editionId: 7)
        XCTAssertEqual(rows.map(\.label), ["E01", "E02", "E03–04"])
        XCTAssertEqual(rows.map(\.isMissing), [false, true, false])
        XCTAssertEqual(rows[2].title, "Ep 3 / Ep 4")
        XCTAssertEqual(s.fileSummary(editionId: 7, fileCount: 2), "3 of 4 episodes · 1 missing")
    }

    func testUnmonitoredSeasonShowsFilesOnly() throws {
        let eps = [episode(1, 1, fileId: 501), episode(2, 2, fileId: nil)].joined(separator: ",")
        let s = try season(#"{"season_number": 2, "monitored": false, "episodes": [\#(eps)]}"#)
        XCTAssertEqual(s.fileRows(editionId: 7).map(\.label), ["E01"])
        XCTAssertEqual(s.fileSummary(editionId: 7, fileCount: 1), "1 file")
    }

    func testCompleteSeasonCountsFiles() throws {
        let eps = [episode(1, 1, fileId: 501), episode(2, 2, fileId: 502)].joined(separator: ",")
        let s = try season(#"{"season_number": 1, "monitored": true, "episodes": [\#(eps)]}"#)
        XCTAssertEqual(s.fileSummary(editionId: 7, fileCount: 2), "2 of 2 episodes · 2 files")
    }
}
