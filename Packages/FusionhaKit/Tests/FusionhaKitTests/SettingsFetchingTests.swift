import XCTest
@testable import FusionhaKit

final class SettingsFetchingTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testRootFolderDecodesAndInfersTierAndKind() throws {
        let roots = try decoder.decode([RootFolderInfo].self, from: Data(#"""
            [{"id":2,"path":"/movies-4k","default_import_mode":"HARDLINK","free_space":100,"total_space":400,
              "used_space":300,"accessible":true,"persistent":true,"tracked_editions":3,"tracked_size":9,
              "default_for":[{"profile_kind":"movie","tier":"UHD-2160p","quality_profile_id":null,"root_folder_id":2}]},
             {"id":9,"path":"/demo/anime","default_import_mode":"move","free_space":null,"total_space":null,
              "used_space":null,"accessible":false}]
            """#.utf8))
        XCTAssertEqual(roots[0].inferredTier, .uhd)
        XCTAssertEqual(roots[0].inferredKind, "movie")
        XCTAssertEqual(roots[0].defaultFor?.first?.rootFolderId, 2)
        XCTAssertEqual(roots[1].inferredKind, "anime")
        XCTAssertEqual(roots[1].importMode, .move)
        XCTAssertFalse(roots[1].online)
        XCTAssertEqual(ImportMode.hardlink.label, "Hardlink")
    }

    func testIndexerStatsDecodeSnakeCaseNumbers() throws {
        let stats = try decoder.decode(IndexerStatsResponse.self, from: Data(#"""
            {"indexers":[{"id":1,"name":"Geek","protocol":"USENET","priority":25,"enabled_search":true,
              "enabled_rss":true,"health":{"state":"healthy","failure_count":0},
              "caps":{"tv":true,"movie":true,"anime":false,"id_search":true},"grabs_24h":4,"grabs_range":40,
              "yield_range":12.5,"activity_series":[1,2,3],"exclusive":{"total":2,"early":1}}],
             "summary":{"range":"7d","indexers":1,"healthy":1,"backoff":0,"off":0,"grabs_range":40,
              "efficiency":{"leader":{"name":"Geek","yield":12.5},"laggard":null},
              "exclusive":{"all":{"total":2,"grabs":40,"pct":5.0}}}}
            """#.utf8))
        XCTAssertEqual(stats.indexers[0].grabs24h, 4)
        XCTAssertEqual(stats.indexers[0].caps?.idSearch, true)
        XCTAssertEqual(stats.summary?.efficiency?.leader?.yieldValue, 12.5)
        XCTAssertEqual(stats.summary?.exclusive?.all?.pct, 5.0)
    }

    func testSettingsJSONKeepsSnakeCaseKeysAndNulls() throws {
        let body: SettingsJSON = ["allowed_root_folder_ids": .optionalInts(nil), "enabled": true, "name": "x"]
        let data = try JSONEncoder().encode(body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(object["allowed_root_folder_ids"] is NSNull)
        XCTAssertEqual(object["enabled"] as? Bool, true)
        XCTAssertEqual(object["name"] as? String, "x")
    }

    func testServerDetailIsSurfaced() {
        let error = APIError.http(status: 400, body: #"{"detail":"connection refused"}"#)
        XCTAssertEqual(error.serverDetail, "connection refused")
        XCTAssertEqual((error as Error).settingsMessage, "connection refused")
    }
}
