import XCTest
@testable import FusionhaKit

/// fusionha 0.4.205: queue pause / resume and Live Activity token shapes.
final class LiveActivityPushTests: XCTestCase {
    func testPauseResultSummaryNamesTheClientThatFailed() throws {
        let json = """
        {"paused": true, "paused_at": "2026-10-16T20:00:00Z", "pending_resume": [],
         "clients": [{"client_id": 1, "name": "SAB", "protocol": "usenet", "ok": true, "detail": "paused 3"},
                     {"client_id": 2, "name": "qBit", "protocol": "torrent", "ok": false, "detail": "unreachable"}]}
        """
        let result = try APIClient.decoder.decode(QueuePauseResult.self, from: Data(json.utf8))
        XCTAssertTrue(result.paused)
        XCTAssertEqual(result.summary, "Paused 1 of 2. qBit: unreachable")
    }

    func testPauseResultWithEveryClientOk() throws {
        let json = #"{"paused": false, "paused_at": null, "clients": [{"client_id": 1, "name": "SAB", "protocol": "usenet", "ok": true, "detail": null}]}"#
        let result = try APIClient.decoder.decode(QueuePauseResult.self, from: Data(json.utf8))
        XCTAssertEqual(result.summary, "Resumed 1 download client.")
    }

    func testTokenDecodes() throws {
        let json = #"{"id": 4, "device_id": 9, "kind": "update", "activity_id": "abc", "last_sent_at": null, "last_event": null, "last_priority": null, "last_error": "BadDeviceToken", "ended_at": null}"#
        let token = try APIClient.decoder.decode(LiveActivityToken.self, from: Data(json.utf8))
        XCTAssertEqual(token.deviceId, 9)
        XCTAssertEqual(token.lastError, "BadDeviceToken")
    }
}
