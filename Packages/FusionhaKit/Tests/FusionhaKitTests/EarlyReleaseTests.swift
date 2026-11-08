import XCTest
@testable import FusionhaKit

/// The early-release read (fusionha 0.4.242–0.4.243) and its copy, ported
/// from the web's `early-release-model.ts` (strings must match).
final class EarlyReleaseTests: XCTestCase {
    private let gb = Locale(identifier: "en_GB")

    private let json = """
    {"id": 9, "title": "The Odyssey", "kind": "movie",
     "digital_release": "2026-11-17", "physical_release": "2026-11-17",
     "early_release": {"stage": "physical", "proven_at": "2026-11-07", "groups": 18, "indexers": 11,
       "releases": 25, "first_posted_at": null,
       "spotted": [{"title": "The.Odyssey.2026.2160p.UHD.Remux.HEVC.HDR.DTS-HD.MA.5.1-playBD", "indexers": 7, "size": 109190858777},
                   {"title": "The.Odyssey.2026.iNTERNAL.UHD.BluRay.2160p.DTS-HD.MA.5.1.HDR10.x265-SPx", "indexers": 4, "size": null}]},
     "versions": [{"id": 13, "tier": "UHD-2160p", "monitored": true,
       "early_release": {"stage": "physical", "proven_at": "2026-11-07", "groups": 18, "indexers": 11, "releases": 25,
         "spotted": [{"title": "The.Odyssey.2026.1080p.BluRay.HEVC.x265.5.1-BONE", "indexers": 8}]}}]}
    """

    private func detail() throws -> ItemDetail {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(json.utf8))
    }

    func testDecodesItemAndVersion() throws {
        let item = try detail()
        let early = try XCTUnwrap(item.earlyRelease)
        XCTAssertEqual(early.stage, "physical")
        XCTAssertEqual(early.provenAt, "2026-11-07")
        XCTAssertNil(early.firstPostedAt)
        XCTAssertEqual(early.spotted?.count, 2)
        XCTAssertNil(early.spotted?.last?.size)
        XCTAssertEqual(item.editions.first?.earlyRelease?.spotted?.first?.indexers, 8)
    }

    func testOlderServerDecodesWithoutIt() throws {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let item = try d.decode(ItemDetail.self, from: Data(#"{"id":1,"title":"X","kind":"movie"}"#.utf8))
        XCTAssertNil(item.earlyRelease)
    }

    func testCovers() {
        let physical = EarlyRelease(stage: "physical", provenAt: "2026-11-07")
        let digital = EarlyRelease(stage: "digital", provenAt: "2026-11-07")
        XCTAssertTrue(EarlyReleaseCopy.covers(physical, kind: "digital"))
        XCTAssertTrue(EarlyReleaseCopy.covers(physical, kind: "physical"))
        XCTAssertFalse(EarlyReleaseCopy.covers(physical, kind: "cinema"))
        XCTAssertTrue(EarlyReleaseCopy.covers(digital, kind: "digital"))
        XCTAssertFalse(EarlyReleaseCopy.covers(digital, kind: "physical"))
        XCTAssertFalse(EarlyReleaseCopy.covers(nil, kind: "digital"))
    }

    func testStrings() throws {
        let early = try XCTUnwrap(try detail().earlyRelease)
        XCTAssertEqual(EarlyReleaseCopy.chip(early, locale: gb), "Out early · 7 Nov")
        XCTAssertEqual(EarlyReleaseCopy.headline(early), "Out early · 25 releases")
        XCTAssertEqual(EarlyReleaseCopy.evidence(early, listed: "2026-11-17", locale: gb),
                       "Spotted on 11 indexers · 18 groups, confirmed 7 Nov. TMDB lists 17 Nov, but the movie is already out.")
        XCTAssertEqual(EarlyReleaseCopy.evidence(early, listed: nil, locale: gb),
                       "Spotted on 11 indexers · 18 groups, confirmed 7 Nov. The movie is already out.")
        XCTAssertEqual(EarlyReleaseCopy.versionSummary(early),
                       "UHD Blu-ray remux and UHD Blu-ray spotted on 11 indexers · 18 groups")
    }

    func testFirstPostedAndYears() {
        let early = EarlyRelease(stage: "digital", provenAt: "2026-01-03", groups: 1, indexers: 1,
                                 releases: 0, firstPostedAt: "2025-12-30")
        XCTAssertEqual(EarlyReleaseCopy.headline(early), "Out early")
        XCTAssertEqual(EarlyReleaseCopy.evidence(early, listed: "2026-01-20", locale: gb),
                       "Spotted on 1 indexer · 1 group, first posted 30 Dec 2025. TMDB lists 20 Jan, but the movie is already out.")
    }

    func testKindsFallBackToCount() {
        let early = EarlyRelease(stage: "digital", provenAt: "2026-11-07", groups: 2, indexers: 3, releases: 4,
                                 spotted: [EarlySpotted(title: "Some.Movie.2026.1080p.WEB-DL.DDP5.1-GRP", indexers: 3)])
        XCTAssertEqual(EarlyReleaseCopy.versionSummary(early), "WEB-DL spotted on 3 indexers · 2 groups")
        let bare = EarlyRelease(stage: "digital", provenAt: "2026-11-07", groups: 2, indexers: 3, releases: 4)
        XCTAssertEqual(EarlyReleaseCopy.versionSummary(bare), "4 releases spotted on 3 indexers · 2 groups")
    }
}
