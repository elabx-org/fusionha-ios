import XCTest
@testable import FusionhaKit

final class IdleSummaryTests: XCTestCase {
    private func summary(_ mutate: (inout [String: Any]) -> Void = { _ in }) throws -> IdleSummary {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "idle-summary", withExtension: "json", subdirectory: "Fixtures"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        mutate(&json)
        return try APIClient.decoder.decode(IdleSummary.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func testDecodes() throws {
        let s = try summary()
        XCTAssertEqual(s.history.today.imported, 13)
        XCTAssertEqual(s.history.grabbed24h, 21)
        XCTAssertEqual(s.clients.items.map(\.name), ["qBittorrent", "decypharr"])
        XCTAssertEqual(s.disk?.roots, 2)
        XCTAssertNil(s.tasks.upgrade)
        XCTAssertNotNil(s.tasks.rss?.nextRunDate)   // naive UTC with microseconds
    }

    func testReadiness() throws {
        XCTAssertEqual(try summary().readinessLabel, "All systems ready")
        XCTAssertFalse(try summary { $0["clients"] = ["total": 1, "enabled": 0, "items": []] }.isReady)
        XCTAssertFalse(try summary { $0["indexers"] = ["total": 2, "healthy": 0, "backoff": 2, "off": 0] }.isReady)
        XCTAssertFalse(try summary { $0["disk"] = ["free_bytes": 100, "total_bytes": 10_000, "roots": 1, "volumes": 1] }.isReady)
        XCTAssertTrue(try summary { $0["disk"] = NSNull() }.isReady)   // unreadable disk doesn't block
    }

    func testLabels() {
        XCTAssertEqual(IdleSummary.everyLabel(seconds: 900), "every 15 min")
        XCTAssertEqual(IdleSummary.everyLabel(seconds: 43_200), "every 12 h")
        XCTAssertEqual(IdleSummary.protocolLabel("USENET"), "Usenet")
    }
}
