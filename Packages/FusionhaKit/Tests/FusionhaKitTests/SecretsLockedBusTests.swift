import XCTest
@testable import FusionhaKit

final class SecretsLockedBusTests: XCTestCase {
    private let locked = APIError.http(status: 409, body: #"{"detail":{"code":"secrets_locked"}}"#)

    func testOnlyRefusedWritesCount() {
        XCTAssertTrue(SecretsLockedBus.isLocked(method: "PUT", error: locked))
        XCTAssertTrue(SecretsLockedBus.isLocked(method: "post", error: locked))
        XCTAssertFalse(SecretsLockedBus.isLocked(method: "GET", error: locked))
        XCTAssertFalse(SecretsLockedBus.isLocked(method: nil, error: locked))
        let other = APIError.http(status: 409, body: #"{"detail":{"code":"quota"}}"#)
        XCTAssertFalse(SecretsLockedBus.isLocked(method: "PUT", error: other))
        let forbidden = APIError.http(status: 403, body: #"{"detail":{"code":"secrets_locked"}}"#)
        XCTAssertFalse(SecretsLockedBus.isLocked(method: "PUT", error: forbidden))
    }

    func testReportPostsOnce() {
        let posted = expectation(forNotification: SecretsLockedBus.notification, object: nil)
        SecretsLockedBus.report(method: "PATCH", error: locked)
        wait(for: [posted], timeout: 1)
    }

    func testGateQuietWindowAndSecurityPanel() {
        var gate = SecretsLockedBus.Gate()
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(gate.admit(at: start, onSecurityPanel: true))
        XCTAssertTrue(gate.admit(at: start, onSecurityPanel: false))
        XCTAssertFalse(gate.admit(at: start.addingTimeInterval(3.9), onSecurityPanel: false))
        XCTAssertTrue(gate.admit(at: start.addingTimeInterval(4), onSecurityPanel: false))
    }

    func testCopyMatchesTheWeb() {
        XCTAssertEqual(SecretsLockedBus.message,
                       "Secrets are locked, so this can’t be done yet. Unlock them in Settings → Security first.")
        XCTAssertEqual(SecretsLockedBus.actionLabel, "Open Settings → Security")
    }

    func testCountdownPausesWhileHeld() {
        var clock = ToastCountdown(duration: 1)
        XCTAssertEqual(clock.fraction, 1)
        clock.advance(0.25, held: false)
        XCTAssertEqual(clock.fraction, 0.75, accuracy: 0.0001)
        clock.advance(5, held: true)
        XCTAssertEqual(clock.fraction, 0.75, accuracy: 0.0001)
        XCTAssertFalse(clock.expired)
        clock.advance(5, held: false)
        XCTAssertTrue(clock.expired)
        XCTAssertEqual(clock.fraction, 0)
    }
}
