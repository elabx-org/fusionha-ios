import XCTest
@testable import FusionhaKit

final class PushModelsTests: XCTestCase {
    func testApnsStatusAndDeviceDecode() throws {
        let status = try APIClient.decoder.decode(ApnsStatus.self, from: Data(#"""
            {"configured":false,"enabled":true,"topic":"org.elabx.fusionha","environment":"auto",
             "missing":["auth_key","key_id"],"message":"APNs is not configured on this server"}
            """#.utf8))
        XCTAssertFalse(status.configured)
        XCTAssertEqual(status.missing, ["auth_key", "key_id"])
        XCTAssertNotNil(status.message)

        let devices = try APIClient.decoder.decode([ApnsDevice].self, from: Data(#"""
            [{"id":3,"user_id":1,"device_token":"ab","environment":"sandbox","device_name":"iPhone",
              "app_version":"1.0","created_at":"2026-10-01T10:00:00","last_seen_at":null,
              "last_success_at":null,"failure_count":0,"last_error":null,"disabled":false}]
            """#.utf8))
        XCTAssertEqual(devices.first?.deviceToken, "ab")
        XCTAssertEqual(devices.first?.environment, "sandbox")
    }

    func testPushTestResultDecodesWithAndWithoutDevices() throws {
        let full = try APIClient.decoder.decode(PushTestResult.self, from: Data(#"""
            {"sent":1,"delivered":0,"devices":[{"id":3,"device_label":"iPhone","ok":false,"detail":"APNs 403"}]}
            """#.utf8))
        XCTAssertEqual(full.devices?.first?.detail, "APNs 403")
        let lean = try APIClient.decoder.decode(PushTestResult.self, from: Data(#"{"sent":0,"delivered":0}"#.utf8))
        XCTAssertNil(lean.devices)
    }

    func testRegistrationEncodesSnakeCase() throws {
        let body = ApnsDeviceRegistration(deviceToken: "ab", environment: "sandbox", deviceName: "iPhone", appVersion: "1.0")
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: APIClient.encoder.encode(body)) as? [String: Any])
        XCTAssertEqual(object["device_token"] as? String, "ab")
        XCTAssertEqual(object["environment"] as? String, "sandbox")
        XCTAssertEqual(object["device_name"] as? String, "iPhone")
        XCTAssertEqual(object["app_version"] as? String, "1.0")
    }

    private func profile(_ aps: String?) -> Data {
        let entitlement = aps.map { "<key>aps-environment</key><string>\($0)</string>" } ?? ""
        // A real profile wraps the plist in CMS bytes; the parser must skip them.
        return Data("\u{30}\u{82}junk<?xml version=\"1.0\" encoding=\"UTF-8\"?><plist version=\"1.0\"><dict><key>Entitlements</key><dict>\(entitlement)</dict></dict></plist>trailing".utf8)
    }

    func testEnvironmentFromProvisioningProfile() {
        XCTAssertEqual(ApnsEnvironment.fromProvisioningProfile(profile("development")), "sandbox")
        XCTAssertEqual(ApnsEnvironment.fromProvisioningProfile(profile("production")), "production")
        XCTAssertEqual(ApnsEnvironment.fromProvisioningProfile(profile(nil)), "sandbox")
        XCTAssertEqual(ApnsEnvironment.fromProvisioningProfile(Data("garbage".utf8)), "sandbox")
        XCTAssertEqual(ApnsEnvironment.fromProvisioningProfile(nil), "production")
    }
}
