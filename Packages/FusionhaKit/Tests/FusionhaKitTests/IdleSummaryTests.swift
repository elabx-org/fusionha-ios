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

    func testReadinessCopy() throws {
        let s = try summary()
        XCTAssertEqual(s.clientsToggleLabel, "2 clients")
        XCTAssertTrue(s.allClientsOn)
        XCTAssertEqual(s.rootsVolumesText, "2 roots, one volume")
        XCTAssertEqual(s.indexersSubText, "1 in backoff · 21 grabs 24h")
        XCTAssertEqual(s.rssSubText, "every 15 min · last took 3s")
        XCTAssertEqual(s.searchSubText(upgradeClock: "21:37"), "Missing")   // no upgrade task
        XCTAssertEqual(s.freeFraction, 0.33, accuracy: 0.001)
        XCTAssertFalse(s.diskLow)
        let rss = try XCTUnwrap(s.tasks.rss?.nextRunDate)
        // Due at 22:38:00.123, last took 3.2 s → refetch 8.2 s after it.
        XCTAssertEqual(try XCTUnwrap(IdleTime.refetchDelay(s.tasks, now: rss.addingTimeInterval(-60))), 68.2, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(IdleTime.refetchDelay(s.tasks, now: rss.addingTimeInterval(5))), 5, accuracy: 0.01)
    }

    func testLabels() {
        XCTAssertEqual(IdleSummary.everyLabel(seconds: 900), "every 15 min")
        XCTAssertEqual(IdleSummary.everyLabel(seconds: 43_200), "every 12 h")
        XCTAssertEqual(IdleSummary.protocolLabel("USENET"), "Usenet")
    }
}
