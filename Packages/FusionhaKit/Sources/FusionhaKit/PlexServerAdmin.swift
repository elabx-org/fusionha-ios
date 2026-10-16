import Foundation

// Settings › Access › Plex server, native (web `components/settings/plex-server/*`,
// `lib/api/plex-server.ts`, `lib/api/plex-connections.ts`; backend
// `api/plex_server_routes.py`, `plex_server_probe_routes.py`,
// `plex_library_routes.py`, `plex_access_routes.py`). Admin-only. The server
// URL, Verify TLS and the derive switch are plain `/api/v1/settings` keys
// (`plex_server_url`, `plex_server_verify_tls`, `plex_derive_uhd_access`).

/// How the backend classifies one Plex-reported address.
public enum PlexConnectionKind: String, Sendable, Hashable, CaseIterable {
    case lan, `private`, docker, `public`, domain, relay
}

/// One connection Plex reports for the owner's server (`PlexConnectionRead`).
public struct PlexConnection: Decodable, Sendable, Hashable, Identifiable {
    public let uri: String
    public let local: Bool
    public let relay: Bool
    /// Host without the port, plex.direct decoded.
    public let label: String
    public let kindRaw: String
    public let secure: Bool
    public let plexDirect: Bool
    public var id: String { uri }
    public var kind: PlexConnectionKind { PlexConnectionKind(rawValue: kindRaw) ?? .domain }

    enum CodingKeys: String, CodingKey { case uri, local, relay, label, kindRaw = "kind", secure, plexDirect }

    public init(uri: String, label: String, kind: PlexConnectionKind, secure: Bool = true,
                local: Bool = false, relay: Bool = false, plexDirect: Bool = false) {
        self.uri = uri; self.label = label; self.kindRaw = kind.rawValue; self.secure = secure
        self.local = local; self.relay = relay; self.plexDirect = plexDirect
    }
}

/// `GET /api/v1/settings/plex/server`: the saved connection and its last stored probe.
public struct PlexServerInfo: Decodable, Sendable {
    public let url: String
    public let verifyTls: Bool
    public let machineId: String?
    public let suggestedConnections: [PlexConnection]?
    public let ok: Bool?
    public let reachable: Bool?
    public let version: String?
    public let checkedAt: String?
    public let message: String?
    public let librariesLostWithoutUrl: Int?
}

/// `POST /api/v1/settings/plex/server/test`.
public struct PlexServerTestResult: Decodable, Sendable, Hashable {
    public let ok: Bool
    public let reachable: Bool
    public let machineId: String?
    public let version: String?
    public let message: String
}

/// One address of the reachability probe (`PlexConnectionProbeRead`).
public struct PlexConnectionProbe: Decodable, Sendable, Hashable, Identifiable {
    public let uri: String
    public let label: String
    public let kindRaw: String
    public let secure: Bool
    public let plexDirect: Bool
    public let reachable: Bool
    public let latencyMs: Int?
    public let isOwnerServer: Bool
    /// timeout · refused · tls · http_error · wrong_server
    public let error: String?
    public var id: String { uri }
    public var kind: PlexConnectionKind { PlexConnectionKind(rawValue: kindRaw) ?? .domain }
    /// The probe row as a plain connection (for grouping and labels).
    public var connection: PlexConnection {
        PlexConnection(uri: uri, label: label, kind: kind, secure: secure, plexDirect: plexDirect)
    }

    enum CodingKeys: String, CodingKey {
        case uri, label, kindRaw = "kind", secure, plexDirect, reachable, latencyMs, isOwnerServer, error
    }
}

/// `POST /api/v1/settings/plex/server/connections/probe`.
public struct PlexConnectionsProbe: Decodable, Sendable {
    public let results: [PlexConnectionProbe]
    public let recommendedUri: String?
    public let tested: Int?
    public let reachable: Int?
    public let checkedAt: String?
}

/// A library's 4K detection evidence (`detection`, a free-form object).
public struct PlexLibraryDetection: Decodable, Sendable, Hashable {
    /// `path` or `name`.
    public let method: String?
    public let matchedSuffix: String?
    public let unique: Bool?
    public let sampled: Int?
    public let matched: Int?
    public let plexPath: String?
    public let rootPath: String?
    public let matchedTitle: String?

    enum CodingKeys: String, CodingKey {
        case method, matchedSuffix, unique, sampled, matched, plexPath, rootPath, matchedTitle
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        method = try? c.decodeIfPresent(String.self, forKey: .method)
        matchedSuffix = try? c.decodeIfPresent(String.self, forKey: .matchedSuffix)
        unique = try? c.decodeIfPresent(Bool.self, forKey: .unique)
        sampled = (try? c.decodeIfPresent(Int.self, forKey: .sampled)) ?? nil
        matched = (try? c.decodeIfPresent(Int.self, forKey: .matched)) ?? nil
        plexPath = try? c.decodeIfPresent(String.self, forKey: .plexPath)
        rootPath = try? c.decodeIfPresent(String.self, forKey: .rootPath)
        matchedTitle = try? c.decodeIfPresent(String.self, forKey: .matchedTitle)
    }
}

/// One Plex section in the "4K Plex libraries" map (`PlexLibraryRead`).
public struct PlexLibrary: Decodable, Sendable, Hashable, Identifiable {
    public let sectionKey: String
    public let title: String
    public let type: String
    public let source: String?
    /// MATCHED · SUGGESTED · NONE
    public let uhdDetected: String
    public let detection: PlexLibraryDetection?
    /// ON · OFF, nil = follow detection.
    public let uhdOverride: String?
    public let effectiveUhd: Bool
    public let gone: Bool
    public let lostWithoutServerUrl: Bool
    public var id: String { sectionKey }
}

/// One person in the acknowledge preview's gain / lose lists.
public struct PlexPreviewUser: Decodable, Sendable, Hashable, Identifiable {
    public let userId: Int
    public let displayName: String
    public var id: Int { userId }
}

/// A static health warning (never a raw stored error).
public struct PlexAccessWarning: Decodable, Sendable, Hashable {
    public let code: String
    public let message: String
    public let attempts: Int?

    public init(code: String, message: String, attempts: Int? = nil) {
        self.code = code; self.message = message; self.attempts = attempts
    }
}

/// `GET /api/v1/plex/access/preview` (also the answer of acknowledge / withdraw).
public struct PlexAccessPreview: Decodable, Sendable {
    public let gain: [PlexPreviewUser]
    public let lose: [PlexPreviewUser]
    public let unchanged: Int
    public let active: Bool
    public let acknowledgedAt: String?
    public let deriveEnabled: Bool
    public let uhdLibraries: [String]
    public let synced: Bool
    public let lastSyncedAt: String?
    public let warnings: [PlexAccessWarning]
}

/// One user's resolved UHD·4K access (`GET /api/v1/plex/access/users`).
public struct UserTierAccess: Decodable, Sendable, Hashable, Identifiable {
    public let userId: Int
    public let uhd: Bool
    public let source: String
    public let isManaged: Bool
    public let frozen: Bool
    public let isOwner: Bool
    public let isHome: Bool
    public let isAdmin: Bool
    public let uhdWhenActive: Bool
    public let sourceWhenActive: String
    public var id: Int { userId }

    enum CodingKeys: String, CodingKey {
        case userId, uhd, source, isManaged, frozen, isOwner, isHome, isAdmin, uhdWhenActive, sourceWhenActive
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(Int.self, forKey: .userId)
        uhd = try c.decode(Bool.self, forKey: .uhd)
        source = try c.decode(String.self, forKey: .source)
        isManaged = try c.decodeIfPresent(Bool.self, forKey: .isManaged) ?? false
        frozen = try c.decodeIfPresent(Bool.self, forKey: .frozen) ?? false
        isOwner = try c.decodeIfPresent(Bool.self, forKey: .isOwner) ?? false
        isHome = try c.decodeIfPresent(Bool.self, forKey: .isHome) ?? false
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        uhdWhenActive = try c.decodeIfPresent(Bool.self, forKey: .uhdWhenActive) ?? true
        sourceWhenActive = try c.decodeIfPresent(String.self, forKey: .sourceWhenActive) ?? "default"
    }
}

/// `POST /api/v1/plex/libraries/detect` (202): the queued detect command.
public struct PlexDetectStarted: Decodable, Sendable {
    public let commandId: String?
}

public enum PlexErrorCode {
    public static let accessNotSynced = "access_not_synced"
    public static let noUhdLibrary = "no_uhd_library"
    /// A coded 503 from the probe: plex.tv couldn't be asked, not "nothing answered".
    public static let plexTvUnavailable = "plex_tv_unavailable"
    /// The scheduled task behind "Sync now".
    public static let accessSyncTask = "plex-access-sync"
}

extension APIClient {
    public func plexServer() async throws -> PlexServerInfo {
        try await get("/api/v1/settings/plex/server")
    }

    /// Tests the SAVED url. Can switch the stored machine id (resets libraries and access).
    public func testPlexServer() async throws -> PlexServerTestResult {
        try await sendJSON("POST", "/api/v1/settings/plex/server/test")
    }

    /// Tries every Plex-reported address from fusionha's network (no input).
    public func probePlexConnections() async throws -> PlexConnectionsProbe {
        var req = request(method: "POST", path: "/api/v1/settings/plex/server/connections/probe", query: [])
        req.timeoutInterval = 90
        return try await perform(req)
    }

    public func plexLibraries() async throws -> [PlexLibrary] {
        try await get("/api/v1/plex/libraries")
    }

    /// `PATCH /plex/libraries/{key}` with `uhd_override`: "ON", "OFF" or nil (back to detection).
    @discardableResult
    public func setPlexLibraryOverride(sectionKey: String, value: String?) async throws -> PlexLibrary {
        try await sendJSON("PATCH", "/api/v1/plex/libraries/\(sectionKey)", ["uhd_override": .optional(value)])
    }

    public func redetectPlexLibraries() async throws -> PlexDetectStarted {
        try await sendJSON("POST", "/api/v1/plex/libraries/detect")
    }

    public func plexAccessPreview() async throws -> PlexAccessPreview {
        try await get("/api/v1/plex/access/preview")
    }

    /// `POST` acknowledges the derivation, `DELETE` withdraws it; both answer the fresh preview.
    public func acknowledgePlexAccess(_ on: Bool) async throws -> PlexAccessPreview {
        try await sendJSON(on ? "POST" : "DELETE", "/api/v1/plex/access/acknowledge")
    }

    public func plexTierAccess() async throws -> [UserTierAccess] {
        try await get("/api/v1/plex/access/users")
    }
}
