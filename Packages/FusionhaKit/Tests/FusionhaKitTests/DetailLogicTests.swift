import XCTest
@testable import FusionhaKit

/// The detail page's scope, coverage and formatting logic, against real demo items.
final class DetailLogicTests: XCTestCase {
    private func item(_ name: String) throws -> ItemDetail {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(contentsOf: url))
    }

    func testDecodesDetailExtras() throws {
        let matrix = try item("detail_matrix")
        XCTAssertEqual(matrix.resolvedMetadataProvider, "tmdb")
        XCTAssertEqual(matrix.releaseWindows?.count, 3)
        XCTAssertEqual(matrix.editions.first?.movieFile?.analysis, "pending")
        XCTAssertEqual(matrix.editions.first?.minimumAvailability, "released")
        XCTAssertEqual(matrix.history?.first?.editionId, 2)

        let bb = try item("detail_breaking_bad")
        let grilled = try XCTUnwrap(bb.allEpisodes.first { $0.title == "Grilled" })
        XCTAssertEqual(grilled.downloadStates?.first?.releaseTitle, "Breaking.Bad.S02E02.1080p.BluRay.x264-DEMO")
        XCTAssertEqual(bb.numberingMismatch, false)
    }

    func testScopeCoercion() throws {
        let bb = try item("detail_breaking_bad")
        // A one-tier item resolves "all" to its sole tier.
        XCTAssertEqual(bb.effectiveScope(.all).tier, "HD-1080p")
        XCTAssertEqual(bb.scopeEditionId(.all), 11)
        XCTAssertEqual(bb.scopeLabel(.all, allText: "all editions"), "HD·1080p")

        let matrix = try item("detail_matrix")
        XCTAssertNil(matrix.scopeEditionId(.all))
        XCTAssertEqual(matrix.scopeEditionId(DetailScope(tier: "UHD-2160p", version: "all")), 2)
        // A version the item lacks falls back to all.
        XCTAssertEqual(matrix.effectiveScope(DetailScope(tier: "all", version: "IMAX")).version, "all")

        let got = try item("detail_got")
        XCTAssertTrue(got.hasVersions)
        XCTAssertEqual(got.versionKeys, ["", "Black & White"])
        // The canonical HD edition is the Standard one, not the B&W variant.
        XCTAssertEqual(got.scopeEditionId(DetailScope(tier: "HD-1080p", version: "all")), 12)
        XCTAssertEqual(got.scopeEditionIds(DetailScope(tier: "all", version: "Black & White")), [14])
    }

    func testScopePersistenceRoundTrip() {
        let scope = DetailScope(tier: "UHD-2160p", version: "Black & White")
        XCTAssertEqual(DetailScope.parse(scope.serialized), scope)
        XCTAssertEqual(DetailScope.parse("HD-1080p"), DetailScope(tier: "HD-1080p", version: "all"))
        XCTAssertEqual(DetailScope.parse("garbage"), .all)
    }

    func testSeriesCoverage() throws {
        let bb = try item("detail_breaking_bad")
        let hd = try XCTUnwrap(bb.editions.first)
        let cover = bb.cover(edition: hd)
        XCTAssertEqual(cover.owned, 4)
        XCTAssertEqual(cover.grabbing, 1)
        XCTAssertEqual(cover.wanted, 1)
        XCTAssertEqual(bb.coverageText(hd), "4/6")
        XCTAssertEqual(bb.seasonsNewestFirst.map(\.seasonNumber), [2, 1])
    }

    func testBytesAreBase1024() {
        XCTAssertEqual(DetailText.bytes(12_800_000_000), "11.9 GB")
        XCTAssertEqual(DetailText.bytes(61_000_000_000), "56.8 GB")
        XCTAssertEqual(DetailText.bytes(0), "0 B")
        XCTAssertEqual(DetailText.bytes(150 * 1024 * 1024), "150 MB")
    }

    func testLabels() {
        XCTAssertEqual(DetailText.quality("REMUX_2160P"), "Bluray-2160p Remux")
        XCTAssertEqual(DetailText.resolution("WEBDL_1080P"), "1080p")
        XCTAssertNotNil(DetailText.instant("2026-10-02T02:52:39.007478"))
        XCTAssertNotNil(DetailText.instant("2009-03-08"))
        XCTAssertEqual(DetailText.relative("2026-10-02T00:00:00", now: DetailText.instant("2026-10-04T00:00:00")!), "2 days ago")
    }
}
