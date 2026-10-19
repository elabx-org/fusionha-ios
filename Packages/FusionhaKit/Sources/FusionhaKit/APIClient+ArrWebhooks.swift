import Foundation

/// `/api/v1/arr-webhooks` writes: the native add/edit sheet (S4).
extension APIClient {
    public func createArrWebhook(_ body: SettingsJSON) async throws {
        try await sendJSON("POST", "/api/v1/arr-webhooks", body)
    }

    public func updateArrWebhook(id: Int, _ body: SettingsJSON) async throws {
        try await sendJSON("PUT", "/api/v1/arr-webhooks/\(id)", body)
    }

    /// Probes the saved row; there is no unsaved test for arr webhooks.
    public func testArrWebhook(id: Int) async throws -> ConnectionTestResult {
        try await sendJSON("POST", "/api/v1/arr-webhooks/\(id)/test")
    }

    /// `POST /api/v1/instances`: a new virtual arr connection (`InstanceCreate`).
    public func createInstance(_ body: SettingsJSON) async throws {
        try await sendJSON("POST", "/api/v1/instances", body)
    }
}
