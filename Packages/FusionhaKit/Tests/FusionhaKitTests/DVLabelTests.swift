import XCTest
@testable import FusionhaKit

/// Dolby Vision profile wording (web `dv-label.ts` and `dv-label.test.ts`).
final class DVLabelTests: XCTestCase {
    func testProfile5HasNoHDRFallback() {
        XCTAssertEqual(DVLabel.profileLabel(profile: 5, compat: 0, hdrFormat: "dv"), "Profile 5 · no HDR fallback")
    }

    func testAnyCompat0ProfileHasNoHDRFallback() {
        XCTAssertEqual(DVLabel.profileLabel(profile: 8, compat: 0, hdrFormat: "dv hdr10"), "Profile 8.0 · no HDR fallback")
    }

    func testHDR10BaseAndPlainProfiles() {
        XCTAssertEqual(DVLabel.profileLabel(profile: 8, compat: 1, hdrFormat: "dv hdr10"), "Profile 8.1 · HDR10 base")
        XCTAssertEqual(DVLabel.profileLabel(profile: 8, compat: 4, hdrFormat: "dv"), "Profile 8.4")
    }

    func testChipSubLabelDropsTheZeroOnProfile5() {
        XCTAssertEqual(DVLabel.subLabel(profile: 5, compat: 0), "P5")
        XCTAssertEqual(DVLabel.subLabel(profile: 8, compat: 1), "P8.1")
        XCTAssertNil(DVLabel.subLabel(profile: nil, compat: nil))
        XCTAssertEqual(DVLabel.chipTitle(profile: 5, compat: 0), "Dolby Vision profile 5 · no HDR fallback")
        XCTAssertEqual(DVLabel.chipTitle(profile: 8, compat: 1), "Dolby Vision profile 8.1")
    }

    /// The fixture's first row with a profile 5 probe.
    private func p5Row() throws -> ManualImportRow {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        var scan = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var row = try XCTUnwrap((scan["rows"] as? [[String: Any]])?.first)
        var probe = try XCTUnwrap(row["probe"] as? [String: Any])
        probe.merge(["dv_profile": 5, "dv_compat_id": 0, "hdr_format": "dv"]) { _, new in new }
        row["probe"] = probe
        row["name_vs_file"] = []
        scan["rows"] = [row]
        return try XCTUnwrap(APIClient.decoder.decode(ManualImportScan.self, from: JSONSerialization.data(withJSONObject: scan)).rows.first)
    }

    func testProfile5OnTheManualImportSurfaces() throws {
        let row = try p5Row()
        let dv = ManualImportCompare.nameFileRows(row).first { $0.label == "Dolby Vision" }
        XCTAssertEqual(dv?.file, "Profile 5 · no HDR fallback")
        XCTAssertTrue(ManualImportTableCells.video(row).contains("DV P5"))
        XCTAssertTrue(ManualImportCompare.summaryLine(row).contains("DV P5"))
        let probe = try XCTUnwrap(row.probe)
        XCTAssertEqual(probe.dvSubLabel, "P5")
        XCTAssertEqual(probe.dvChipTitle, "Dolby Vision profile 5 · no HDR fallback")
    }
}
