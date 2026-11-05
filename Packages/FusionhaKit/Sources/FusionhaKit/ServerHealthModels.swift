import Foundation

/// `GET /health` (unauthenticated): the server's status and version, plus its
/// health checks (the web's System › Health list) on servers that send them.
public struct HealthResponse: Decodable, Sendable {
    public let status: String
    public let version: String
    /// TMDB reachability (`ok`, or the reason it isn't).
    public let tmdb: String?
    public let checks: [HealthCheck]?

    private enum CodingKeys: String, CodingKey { case status, version, tmdb, checks }

    /// The probe behind sign-in: only `status` and `version` may fail it. The
    /// extras decode leniently (an odd check drops the list, never the call).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(String.self, forKey: .status)
        version = try c.decode(String.self, forKey: .version)
        tmdb = c.lenient(.tmdb)
        checks = c.lenient(.checks)
    }
}

/// One health check: where it comes from, its level and the message.
public struct HealthCheck: Decodable, Sendable, Hashable {
    public let source: String?
    /// `ok` / `notice` / `warning` / `error`.
    public let type: String?
    public let message: String
    public let wikiUrl: String?
}

/// `GET /api/v1/system/about` (Settings › About), typed.
public struct SystemAbout: Decodable, Sendable, Hashable {
    public let app: String?
    public let version: String
    public let commit: String?
    public let buildDate: String?
    public let python: String?
    public let dbSchemaRev: String?
    public let uptimeSeconds: Int?

    private enum CodingKeys: String, CodingKey { case app, version, commit, buildDate, python, dbSchemaRev, uptimeSeconds }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        app = c.lenient(.app)
        commit = c.lenient(.commit)
        buildDate = c.lenient(.buildDate)
        python = c.lenient(.python)
        dbSchemaRev = c.lenient(.dbSchemaRev)
        // An integer on the wire; a float is rounded down rather than dropped.
        let seconds: Double? = c.lenient(.uptimeSeconds)
        uptimeSeconds = seconds.map { Int($0) }
    }
}

extension APIClient {
    public func systemAbout() async throws -> SystemAbout {
        try await get("/api/v1/system/about")
    }
}
