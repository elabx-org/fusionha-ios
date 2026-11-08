import XCTest
@testable import FusionhaKit

final class ManageFixTests: XCTestCase {
    private func item(_ id: Int, season: Int? = 4, unresolved: Bool = false, link: Bool = false,
                      analysis: String? = nil, missingSince: String? = nil, monitored: Bool = true) throws -> ManagedFileItem {
        let json = """
        {"file_id": \(id), "version_id": 1, "tier": "HD-1080p", "relative_path": "Season 04/E\(id).mkv",
         "season": \(season.map(String.init) ?? "null"), "episodes": [\(id)], "quality": "WEBDL_1080P",
         "languages": [], "size": 1073741824, "indexer_flags": [], "unresolved": \(unresolved),
         "link_unresolved": \(link), "analysis": \(analysis.map { "\"\($0)\"" } ?? "null"),
         "missing_since": \(missingSince.map { "\"\($0)\"" } ?? "null")}
        """
        let row = try APIClient.decoder.decode(ManagedFileRow.self, from: Data(json.utf8))
        return ManagedFileItem(row: row, monitored: monitored)
    }

    func testKindsAndPrimary() throws {
        let bad = try item(5, analysis: "failed")
        let gone = try item(4, unresolved: true)
        let dangling = try item(6, unresolved: true, link: true)
        XCTAssertEqual(ManageFixKind(bad), .unreadable)
        XCTAssertEqual(ManageFixKind(gone), .gone)
        XCTAssertEqual(ManageFixKind(dangling), .deadLink)
        XCTAssertNil(ManageFixKind(try item(7)))

        XCTAssertEqual(ManageFix.primary([bad]), .replace)
        XCTAssertEqual(ManageFix.primary([gone, dangling]), .searchNew)
        XCTAssertEqual(ManageFix.primary([gone, bad]), .replace)
        XCTAssertTrue(ManageFix.blocklistByDefault([bad]))
        XCTAssertFalse(ManageFix.blocklistByDefault([gone]))
        XCTAssertEqual(ManageFix.groups([dangling, gone, bad]).map(\.kind), [.unreadable, .gone, .deadLink])
        XCTAssertEqual(ManageFix.primaryLabel(.searchNew, count: 2), "Search for new copies")
    }

    func testWords() throws {
        let bad = try item(5, analysis: "failed")
        let gone = try item(4, unresolved: true, missingSince: "2026-11-08T06:12:00")
        XCTAssertEqual(ManageFix.groups([bad])[0].headline, "1 file can’t be read")
        XCTAssertEqual(ManageFix.groups([gone, try item(6, unresolved: true)])[0].headline, "2 files are gone from disk")
        XCTAssertEqual(ManageFix.reason(bad, clock: { _ in "x" }), "Can’t be read · MediaInfo failed")
        XCTAssertEqual(ManageFix.reason(gone, clock: { _ in "06:12" }), "Gone from disk since 06:12")
        XCTAssertEqual(ManageFix.subtitle(title: "The Morning Show", count: 1), "The Morning Show · 1 problem")
        XCTAssertEqual(ManageFix.confirmTitle(.replace, count: 1, name: "Amari"), "Replace Amari?")
        XCTAssertEqual(ManageFix.confirmMessage([bad], isSeries: true),
                       "Deletes the damaged file (1 GB) and searches for a new copy now. Season 4 stays monitored.")
    }

    func testOthersLine() throws {
        let bad = try item(5, analysis: "failed")
        let all = [bad, try item(1), try item(2), try item(3, season: 3)]
        XCTAssertEqual(ManageFix.othersLine(problems: [bad], all: all), "Season 4 · 2 other files are fine")
        XCTAssertNil(ManageFix.othersLine(problems: [bad], all: [bad]))
    }

    func testBlocklistTargetDecodes() throws {
        let t = try APIClient.decoder.decode(FileBlocklistTarget?.self, from: Data(
            #"{"release_title": "Show S04E05 1080p-FLUX", "protocol": "usenet", "has_infohash": false}"#.utf8))
        XCTAssertEqual(t?.releaseTitle, "Show S04E05 1080p-FLUX")
        XCTAssertEqual(t?.transportLabel, "Usenet")
        XCTAssertNil(try APIClient.decoder.decode(FileBlocklistTarget?.self, from: Data("null".utf8)))
    }
}
