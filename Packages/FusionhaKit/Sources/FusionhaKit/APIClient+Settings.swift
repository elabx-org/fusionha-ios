import Foundation

/// Settings endpoints (`/api/v1/settings` and the panels' collections). These
/// read and write loose JSON so each control can save just the key it owns,
/// exactly like the web's minimal `PUT` diffs.
extension APIClient {
    /// Sends a request with an optional JSON body and returns the parsed reply
    /// (`.null` for an empty body). Keys are left untouched.
    @discardableResult
    public func json(_ method: String, _ path: String, query: [URLQueryItem] = [], body: JSONValue? = nil) async throws -> JSONValue {
        var req = request(method: method, path: path, query: query)
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body.any, options: [.fragmentsAllowed])
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let error = APIError.http(status: status, body: String(decoding: data.prefix(500), as: UTF8.self))
            reportUnauthorized(req, error: error)
            throw error
        }
        guard !data.isEmpty else { return .null }
        return JSONValue(any: try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]))
    }

    /// A collection endpoint's rows.
    public func records(_ path: String, query: [URLQueryItem] = []) async throws -> [JSONRecord] {
        let value = try await json("GET", path, query: query)
        let rows = value.array ?? value["items"]?.array ?? []
        return rows.compactMap { $0.object.map(JSONRecord.init) }
    }

    // MARK: App settings

    public func settings() async throws -> [String: JSONValue] {
        try await json("GET", "/api/v1/settings").object ?? [:]
    }

    /// `PUT /api/v1/settings` with only the changed keys; returns the full settings.
    public func updateSettings(_ diff: [String: JSONValue]) async throws -> [String: JSONValue] {
        try await json("PUT", "/api/v1/settings", body: .object(diff)).object ?? [:]
    }

    /// The Trakt app id (0.4.237, admin): write-only. Reads show only
    /// `trakt_client_id_set`; the value is never sent back.
    public func setTraktClientId(_ id: String) async throws -> [String: JSONValue] {
        try await updateSettings(["trakt_client_id": .string(id)])
    }

    /// Forgets the Trakt app id (204). Followed Trakt lists then wait as Unavailable.
    public func clearTraktClientId() async throws {
        try await sendJSON("DELETE", "/api/v1/settings/trakt-client-id")
    }

    /// The fusionha app API key (`GET /api/v1/settings/api-key`).
    public func revealAppApiKey() async throws -> String {
        try await json("GET", "/api/v1/settings/api-key")["api_key"]?.string ?? ""
    }

    /// Rotates the app API key and returns the new one.
    public func regenerateAppApiKey() async throws -> String {
        try await json("POST", "/api/v1/settings/regenerate-api-key")["api_key"]?.string ?? ""
    }
}
