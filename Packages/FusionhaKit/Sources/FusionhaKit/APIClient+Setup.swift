import Foundation

extension APIClient {
    /// `GET /api/v1/library/setups`: the caller's active and recently finished setups.
    public func setups() async throws -> TitleSetupList {
        try await get("/api/v1/library/setups")
    }
}

// MARK: - First-run setup (`routes/Setup.tsx`)

extension APIClient {
    /// `POST /api/v1/setup`: creates the first admin on a fresh server and signs
    /// it in (the session cookie lands on this client's URLSession).
    public func createFirstAdmin(username: String, password: String) async throws {
        let _: IgnoredJSON = try await sendJSON("POST", "/api/v1/setup", .object([
            "username": .string(username), "password": .string(password),
        ]))
    }

    /// The wizard's TMDB step: the same `PUT /api/v1/settings` Settings › Metadata uses.
    public func saveTmdbKey(_ key: String) async throws {
        try await sendJSON("PUT", "/api/v1/settings", .object(["tmdb_api_key": .string(key)]))
    }
}

/// The wizard's root layout: one root per kind and tier.
public enum SetupTierPaths {
    public static let all = ["/movies", "/movies-4k", "/tv", "/tv-4k", "/anime", "/anime-4k"]
}
