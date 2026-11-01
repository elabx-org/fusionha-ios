import XCTest
@testable import FusionhaKit

/// `bulk-languages-seed.test.tsx`: bulk Set languages seeds from the selected rows.
final class ManualImportBulkLanguagesTests: XCTestCase {
    private func rows(_ languages: [[String]?]) throws -> [ManualImportRow] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manual-import-rescue", withExtension: "json", subdirectory: "Fixtures"))
        var scan = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let base = try XCTUnwrap((scan["rows"] as? [[String: Any]])?.first)
        scan["rows"] = languages.enumerated().map { i, langs in
            var r = base
            r["row_id"] = i + 1
            r["languages"] = langs.map { $0 as Any } ?? NSNull()
            return r
        }
        let data = try JSONSerialization.data(withJSONObject: scan)
        return try APIClient.decoder.decode(ManualImportScan.self, from: data).rows
    }

    func testSharedSetIgnoresOrder() throws {
        let r = try rows([["English", "French"], ["French", "English"]])
        XCTAssertEqual(ManualImportBatch.sharedLanguages(r), ["English", "French"])
    }

    func testMixedStartsEmpty() throws {
        let r = try rows([["English", "French"], ["Japanese"]])
        XCTAssertNil(ManualImportBatch.sharedLanguages(r))
    }

    func testUnknownCountsAsEmpty() throws {
        XCTAssertEqual(ManualImportBatch.sharedLanguages(try rows([nil, []])), [])
        XCTAssertNil(ManualImportBatch.sharedLanguages(try rows([nil, ["English"]])))
        XCTAssertEqual(ManualImportBatch.sharedLanguages([]), [])
    }
}
