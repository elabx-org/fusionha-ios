import Foundation

/// Native iOS push (APNs): this app's device registration, the server's APNs
/// status, the admin channel config and a test send.
extension APIClient {
    public func apnsStatus() async throws -> ApnsStatus {
        try await get("/api/v1/notifications/apns/status")
    }

    public func apnsSettings() async throws -> ApnsSettings {
        try await get("/api/v1/notifications/apns/settings")
    }

    /// `PUT …/apns/settings` with only the changed keys (`auth_key` is write-only).
    public func updateApnsSettings(_ body: SettingsJSON) async throws -> ApnsSettings {
        try await sendJSON("PUT", "/api/v1/notifications/apns/settings", body)
    }

    public func apnsDevices() async throws -> [ApnsDevice] {
        try await get("/api/v1/notifications/apns/devices")
    }

    @discardableResult
    public func registerApnsDevice(_ body: ApnsDeviceRegistration) async throws -> ApnsDevice {
        try await send("POST", "/api/v1/notifications/apns/devices", body: body)
    }

    public func deleteApnsDevice(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/notifications/apns/devices/\(id)")
    }

    /// Unregister by token (sign-out). Idempotent on the server.
    public func unregisterApnsDevice(token: String) async throws {
        try await sendJSON("DELETE", "/api/v1/notifications/apns/devices/token/\(token)")
    }

    /// Test alert to this user's iOS devices, or just `deviceId`. 409 = APNs not configured.
    public func testApns(deviceId: Int? = nil) async throws -> PushTestResult {
        let query = deviceId.map { [URLQueryItem(name: "device_id", value: "\($0)")] } ?? []
        return try await sendJSON("POST", "/api/v1/notifications/apns/test", query: query)
    }
}
