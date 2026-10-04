import XCTest
@testable import FusionhaKit

/// The Versions panel's logic (version-coverage.ts / version-display.ts) and the
/// 0.4.122 `versions` / `edition` / `version_id` wire names.
final class VersionLogicTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    private func item(_ name: String) throws -> ItemDetail {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(contentsOf: url))
    }

    func testDecodesNewWireNames() throws {
        let detail = try decode(ItemDetail.self, """
        {"id": 5, "title": "Show", "kind": "series",
         "versions": [{"id": 7, "tier": "UHD-2160p", "edition": "Black & White", "monitored": true,
                       "missing_file_count": 2, "has_unresolved_links": true}],
         "seasons": [{"season_number": 1, "monitored": true, "episodes": [
            {"id": 1, "episode_number": 1, "monitored": true,
             "files": [{"version_id": 7, "tier": "UHD-2160p", "file": {"id": 3, "size": 10}}],
             "download_states": [{"version_id": 7, "state": "upgrading"}]}]}]}
        """)
        let v = try XCTUnwrap(detail.editions.first)
        XCTAssertEqual(v.movieEdition, "Black & White")
        XCTAssertEqual(v.versionKey, "Black & White")
        XCTAssertEqual(v.unresolvedCount, 3)
        let ep = try XCTUnwrap(detail.allEpisodes.first)
        XCTAssertEqual(ep.files?.first?.editionId, 7)
        XCTAssertEqual(ep.downloadStates?.first?.editionId, 7)
    }

    func testDecodesLegacyWireNames() throws {
        let detail = try decode(ItemDetail.self, """
        {"id": 5, "title": "Film", "kind": "movie",
         "editions": [{"id": 9, "tier": "HD-1080p", "movie_edition": "Extended", "monitored": true,
                       "unresolved_file_count": 1}]}
        """)
        XCTAssertEqual(detail.editions.first?.movieEdition, "Extended")
        XCTAssertEqual(detail.editions.first?.unresolvedCount, 1)
    }

    func testOrderingAndGaps() throws {
        let got = try item("detail_got")
        XCTAssertEqual(got.versionsSorted.map(\.id), [12, 14, 13])
        XCTAssertEqual(got.editionKeysSorted, ["", "Black & White"])
        XCTAssertTrue(got.needsEditionTag)
        XCTAssertEqual(got.missingVersions, [MissingVersion(tier: .uhd, edition: "Black & White")])

        let bb = try item("detail_breaking_bad")
        XCTAssertFalse(bb.needsEditionTag)
        XCTAssertEqual(bb.missingVersions, [MissingVersion(tier: .uhd, edition: "")])
        XCTAssertEqual(bb.versionName(bb.editions[0]), "HD·1080p")
        XCTAssertEqual(got.versionName(got.editions.first { $0.id == 14 }!), "HD·1080p · Black & White")
    }

    func testFocusAndLabels() throws {
        let got = try item("detail_got")
        XCTAssertNil(got.focusedVersion(.all))
        XCTAssertEqual(got.focusedVersion(DetailScope(tier: "HD-1080p", version: "all"))?.id, 12)
        XCTAssertEqual(got.focusedVersion(DetailScope(tier: "HD-1080p", version: "Black & White"))?.id, 14)
        XCTAssertEqual(got.showingLabel(.all), "All versions")
        XCTAssertEqual(got.showingLabel(DetailScope(tier: "HD-1080p", version: "")), "Standard · HD·1080p")
        XCTAssertEqual(got.appliesToLabel(.all), "all versions")

        // A sole-tier title never opens its only row, but its labels coerce to the tier.
        let bb = try item("detail_breaking_bad")
        XCTAssertNil(bb.focusedVersion(.all))
        XCTAssertEqual(bb.appliesToLabel(.all), "HD·1080p")
        XCTAssertEqual(bb.showingLabel(.all), "HD·1080p")
    }

    func testSeriesStatusAndSeasons() throws {
        let bb = try item("detail_breaking_bad")
        let hd = bb.editions[0]
        let cover = bb.cover(edition: hd)
        XCTAssertEqual(seriesVersionStatus(cover).text, "Downloading 1")
        XCTAssertNil(bb.untrackedNote(cover))
        XCTAssertEqual(bb.defaultSeason(editionIds: [hd.id]), 2)
        XCTAssertEqual(bb.seasonsAscending.map(\.seasonNumber), [1, 2])

        var missing = Cover(); missing.total = 4; missing.owned = 1; missing.wanted = 3
        XCTAssertEqual(seriesVersionStatus(missing).text, "Missing 3")
        var unaired = Cover(); unaired.total = 2; unaired.unaired = 2
        XCTAssertEqual(seriesVersionStatus(unaired).text, "Unaired 2")
        var off = Cover(); off.untracked = 5
        XCTAssertEqual(seriesVersionStatus(off).key, .unmonitored)
        XCTAssertEqual(seriesVersionStatus(Cover()).key, .unaired)
    }

    func testMovieStatusAndAvailability() throws {
        let matrix = try item("detail_matrix")
        let hd = matrix.editions[0]
        XCTAssertEqual(matrix.movieVersionStatus(hd, base: .done), .done)
        XCTAssertEqual(matrix.movieVersionStatus(hd, base: .miss), .soon) // grabbable == false
        XCTAssertEqual(MovieVersionStatus.wanted.display.word, "Wanted")
        XCTAssertEqual(MovieVersionStatus.wanted.display.key, .missing)
        let avail = matrix.movieAvailability(minimum: "released", treatAnnouncedAsReleased: false)
        XCTAssertEqual(avail.state, .released)
        XCTAssertEqual(avail.date, "31 Mar 1999")
        XCTAssertEqual(matrix.movieAvailabilityNote(hd, status: .wanted).text, "Released 31 Mar 1999")
        XCTAssertEqual(matrix.movieAvailabilityNote(hd, status: .soon).text, "No HD·1080p file yet")
        let grabbed = matrix.versionGrabbed(2, now: DetailText.instant("2026-10-04T02:52:39")!)
        XCTAssertEqual(grabbed.label, "Imported")
        XCTAssertEqual(grabbed.value, "2 days ago")
    }

    func testReleaseDateFormat() {
        XCTAssertEqual(DetailText.releaseDate("2026-09-29"), "29 Sep 2026")
        XCTAssertEqual(DetailText.releaseDate("soon"), "soon")
    }
}
