import XCTest
@testable import FusionhaKit

/// The decoding v2 needs later (plan S1): health checks, a typed About,
/// indexer stats counts and the indexer's caps, categories and last failure.
final class V2DecodingTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testHealthDecodesChecks() throws {
        let health = try decoder.decode(HealthResponse.self, from: Data(#"""
            {"status":"ok","tmdb":"ok","version":"0.4.240",
             "checks":[{"source":"IndexerCheck","type":"warning","message":"1 indexer is failing","wiki_url":null}]}
            """#.utf8))
        XCTAssertEqual(health.version, "0.4.240")
        XCTAssertEqual(health.tmdb, "ok")
        XCTAssertEqual(health.checks?.first?.type, "warning")
        XCTAssertEqual(health.checks?.first?.message, "1 indexer is failing")
    }

    func testHealthStillDecodesFromAnOlderOrOddServer() throws {
        let bare = try decoder.decode(HealthResponse.self, from: Data(#"{"status":"ok","version":"0.4.1"}"#.utf8))
        XCTAssertNil(bare.checks)
        let odd = try decoder.decode(HealthResponse.self, from: Data(#"{"status":"ok","version":"1","checks":[{"type":3}]}"#.utf8))
        XCTAssertNil(odd.checks, "an odd check drops the list, never the probe")
    }

    func testSystemAbout() throws {
        let about = try decoder.decode(SystemAbout.self, from: Data(#"""
            {"app":"fusionha","version":"0.4.240","commit":"abc123","build_date":null,"python":"3.12",
             "db_schema_rev":"0042","uptime_seconds":93784}
            """#.utf8))
        XCTAssertEqual(about.uptimeSeconds, 93784)
        XCTAssertEqual(about.dbSchemaRev, "0042")
        XCTAssertNil(about.buildDate)
    }

    func testIndexerStatRowCounts() throws {
        let stats = try decoder.decode(IndexerStatsResponse.self, from: Data(#"""
            {"indexers":[{"id":1,"name":"Geek","protocol":"USENET","priority":25,"enabled_search":true,
              "enabled_rss":true,"health":{"state":"healthy"},"caps":{"tv":true},
              "grabs_total":120,"grabs_7d":14,"queries_today":31}]}
            """#.utf8))
        let row = try XCTUnwrap(stats.indexers.first)
        XCTAssertEqual(row.`protocol`, "USENET")
        XCTAssertEqual(row.priority, 25)
        XCTAssertEqual(row.grabsTotal, 120)
        XCTAssertEqual(row.grabs7d, 14)
        XCTAssertEqual(row.queriesToday, 31)
    }

    func testSearchIndexerCapsCategoriesAndFailure() throws {
        let rows = try decoder.decode([SearchIndexerInfo].self, from: Data(#"""
            [{"id":3,"name":"Nyaa","protocol":"TORRENT","base_url":"https://x","api_path":"/api",
              "enabled_search":true,"enabled_rss":false,"priority":10,"tv_categories":[5000,5040],
              "movie_categories":[2000],"search_caps":{"search":true,"tv-search":["q","season"]},
              "last_failure_at":"2026-11-05T10:00:00Z"},
             {"id":4,"name":"Old","protocol":"USENET","base_url":"https://y","enabled_search":true,
              "enabled_rss":true,"priority":1,"search_caps":[]}]
            """#.utf8))
        XCTAssertEqual(rows[0].tvCategories, [5000, 5040])
        XCTAssertEqual(rows[0].movieCategories, [2000])
        XCTAssertEqual(rows[0].searchCaps?.keys, ["search", "tv-search"])
        XCTAssertEqual(rows[0].lastFailureAt, "2026-11-05T10:00:00Z")
        XCTAssertEqual(rows[1].searchCaps?.keys, [], "a non-object never fails the indexer")
        XCTAssertNil(rows[1].lastFailureAt)
    }
}
