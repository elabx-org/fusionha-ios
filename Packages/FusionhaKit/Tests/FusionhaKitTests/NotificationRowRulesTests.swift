import XCTest
@testable import FusionhaKit

final class NotificationRowRulesTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func rows() throws -> [NotificationPreferenceItem] {
        try decoder.decode(NotificationPreferences.self, from: Data(#"""
            {"preferences":[
             {"event_kind":"grab","enabled":true,"audience":"operational"},
             {"event_kind":"issue_needs_you","enabled":true,"delivery":"DIGEST","default_delivery":"IMMEDIATE","digest_allowed":true,"audience":"admin"},
             {"event_kind":"issue_reported","enabled":false,"retired":true,"digest_allowed":true,"audience":"admin"},
             {"event_kind":"issue_auto_fixed","enabled":true,"delivery":"IMMEDIATE","default_delivery":"DIGEST","digest_allowed":true,"audience":"admin"},
             {"event_kind":"request_made","enabled":true,"audience":"admin","digest_allowed":false},
             {"event_kind":"future_kind","enabled":true,"digest_allowed":true,"audience":"admin"}
            ]}
            """#.utf8)).preferences
    }

    func testAdminDeliveryRowsAreDigestibleAdminKindsInOrder() throws {
        XCTAssertEqual(NotificationRowRules.adminDelivery(try rows()).map(\.eventKind),
                       ["issue_auto_fixed", "issue_needs_you", "future_kind"])
    }

    func testEventRowsAreTheRestInServerOrder() throws {
        XCTAssertEqual(NotificationRowRules.events(try rows()).map(\.eventKind),
                       ["grab", "issue_reported", "request_made"])
    }

    func testDeliveryFallsBackToTheSwitch() throws {
        let all = try rows()
        XCTAssertEqual(NotificationRowRules.delivery(all[0]), "IMMEDIATE")
        XCTAssertEqual(NotificationRowRules.delivery(all[1]), "DIGEST")
        XCTAssertEqual(NotificationRowRules.delivery(all[2]), "OFF")
    }

    func testDefaultLabel() {
        XCTAssertEqual(NotificationRowRules.defaultLabel("DIGEST"), "Default: daily digest")
        XCTAssertEqual(NotificationRowRules.defaultLabel("IMMEDIATE"), "Default: immediate")
        XCTAssertEqual(NotificationRowRules.defaultLabel("OFF"), "Default: off")
        XCTAssertNil(NotificationRowRules.defaultLabel(nil))
    }

    func testTimeParsingAndFormatting() {
        XCTAssertEqual(NotificationRowRules.parseTime("18:05")?.hour, 18)
        XCTAssertEqual(NotificationRowRules.parseTime("07:30:00")?.minute, 30)
        XCTAssertNil(NotificationRowRules.parseTime("25:00"))
        XCTAssertNil(NotificationRowRules.parseTime(""))
        XCTAssertNil(NotificationRowRules.parseTime(nil))
        XCTAssertEqual(NotificationRowRules.formatTime(hour: 7, minute: 5), "07:05")
    }

    func testWebPushSettingsDecodesDigestTime() throws {
        let s = try decoder.decode(WebPushSettings.self, from: Data(#"{"enabled":true,"digest_time":"19:30"}"#.utf8))
        XCTAssertEqual(s.digestTime, "19:30")
    }
}
