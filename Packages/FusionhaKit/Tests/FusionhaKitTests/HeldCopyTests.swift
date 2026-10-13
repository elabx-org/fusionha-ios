import XCTest
@testable import FusionhaKit

final class HeldCopyTests: XCTestCase {
    private func detail(_ json: String) throws -> HeldDetail {
        try APIClient.decoder.decode(HeldDetail.self, from: Data(json.utf8))
    }

    func testProvenFake() throws {
        let d = try detail("""
        {"kind":"mislabeled_resolution","claimed_quality":"WEBDL-1080p","probed_quality":"WEBDL-480p",
         "probed_resolution":{"w":640,"h":480},"mislabeled":true,"release_group":"FAKEHD",
         "claimed_resolution":1080,"probed_resolution_bucket":480,"release_blocklisted":true}
        """)
        XCTAssertTrue(HeldCopy.isProvenMislabel(d))
        XCTAssertEqual(HeldCopy.headline(d, reason: "raw server reason"), "Not really 1080p: the file is 640×480. Release says 1080p.")
        XCTAssertEqual(d.releaseGroup, "FAKEHD")
        XCTAssertEqual(d.releaseBlocklisted, true)
    }

    func testFileBetterThanItsNameIsNotAFake() throws {
        let d = try detail("""
        {"kind":"mislabeled_resolution","probed_quality":"WEBDL-2160p","probed_resolution":{"w":3840,"h":2160},
         "mislabeled":true,"claimed_resolution":1080,"probed_resolution_bucket":2160}
        """)
        XCTAssertFalse(HeldCopy.isProvenMislabel(d))
    }

    func testLegacyHoldWithoutClaimIsNotAFake() throws {
        let d = try detail(#"{"kind":"mislabeled_resolution","probed_quality":"WEBDL-720p","mislabeled":true}"#)
        XCTAssertFalse(HeldCopy.isProvenMislabel(d))
        XCTAssertEqual(HeldCopy.headline(d, reason: "Held for review"), "Held for review")
    }

    func testHDRAndVerdicts() throws {
        let hdr = try detail(#"{"kind":"mislabeled_hdr","probed_quality":"WEBDL-2160p","mislabeled":false,"claimed_hdr":["DV"],"probed_hdr":"SDR"}"#)
        XCTAssertEqual(HeldCopy.headline(hdr, reason: nil), "Not an upgrade: name claimed DV, file is SDR.")
        XCTAssertEqual(HeldCopy.verdictLabel("equal_quality_no_cf_gain"), "same quality, no score gain")
        XCTAssertEqual(HeldCopy.verdictLabel("upgrades_disabled"), "upgrades are turned off")
    }

    func testBuckets() {
        XCTAssertEqual(HeldCopy.bucket(w: 3840, h: 2160), 2160)
        XCTAssertEqual(HeldCopy.bucket(w: 1920, h: 800), 1080)    // scope 2.40 still 1080
        XCTAssertEqual(HeldCopy.bucket(w: 640, h: 480), 480)
    }

    func testBlockCopy() {
        XCTAssertEqual(HeldCopy.scopeLabel(.item, group: "FAKEHD", title: "Dune"), "Skip FAKEHD for Dune")
        XCTAssertEqual(HeldCopy.scopeLabel(.global, group: "FAKEHD", title: "Dune"), "Skip FAKEHD everywhere")
        let global = HeldCopy.consequences(.global, group: "FAKEHD", title: "Dune", otherTitles: ["Silo"], withCustomFormat: true)
        XCTAssertEqual(global.first, "FAKEHD releases are no longer grabbed for any movie, series or anime.")
        XCTAssertTrue(global.contains("Also stops FAKEHD's Silo release."))
        XCTAssertEqual(global.last, "The release you are looking at stays blocklisted. Your existing file is untouched.")
        XCTAssertEqual(HeldCopy.consequences(.release, group: "X", title: "Y").count, 1)
    }

    func testReleaseGroupErrorsUseTheirOwnCopy() {
        let e = APIError.http(status: 422, body: #"{"detail":{"code":"item_required","detail":"x"}}"#)
        XCTAssertEqual(HeldCopy.errorMessage(e), "Choose which title this block applies to.")
    }
}
