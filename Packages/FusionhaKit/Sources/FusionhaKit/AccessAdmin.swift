import Foundation

// Settings › Access, native: users, roles, the request policy per user and
// per role, and live sessions (web `UsersPanel`, `RolesPanel`,
// `RequestPolicyDialog`, `AccountSessionsDialog`; `api/schemas_users.py`,
// `schemas_instances.py`, `schemas_request_policy.py`, `session_routes.py`).

public struct UserAccount: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let username: String
    public let isAdmin: Bool
    public let roleId: Int?
    public let roleName: String?
    public let isActive: Bool?
    public let activeSessionCount: Int?
    public let plexUsername: String?
    public let thumb: String?
    public let authProvider: String?
    /// `UserRead.plex_linked` / `credentials`: the person's sign-in methods.
    public let plexLinked: Bool?
    public let credentials: [UserCredential]?

    /// Plex accounts show their Plex name (the stored username is a disambiguated key).
    public var displayName: String { authProvider == "plex" ? (plexUsername ?? username) : username }
}

public struct RoleDetail: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let isBuiltin: Bool
    public let permissions: [String]
    public let defaultCapabilities: [String]?
}

/// The keys the Roles editor may assign.
public struct RoleCatalog: Decodable, Sendable {
    public let permissions: [String]
    public let capabilities: [String]
}

public enum AccessLabels {
    public static let permissions: [String: String] = [
        "users.manage": "Manage users", "roles.manage": "Manage roles", "integrations.manage": "Manage integrations",
        "quality.manage": "Manage quality profiles & custom formats", "settings.manage": "Manage settings",
        "connections.manage": "Manage connections", "requests.approve": "Approve requests",
        "issues.manage": "Manage issues", "system.admin": "Full system admin", "tokens.manage.self": "Manage own API tokens",
    ]
    public static let capabilities: [String: String] = [
        "view": "View", "request": "Request titles", "add": "Add titles", "search": "Search & grab",
        "grab": "Grab releases", "edit": "Edit items", "manage_files": "Manage files", "delete": "Delete items",
        "delete_files": "Delete files",
    ]

    /// A known key's label, or the key title-cased.
    public static func label(_ key: String, _ table: [String: String]) -> String {
        table[key] ?? key.split(whereSeparator: { $0 == "." || $0 == "_" }).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// The resolved value of every policy field (nil tiers = unrestricted, nil limits = unlimited).
public struct EffectiveRequestPolicy: Decodable, Sendable, Hashable {
    public let allowedTiers: [QualityTier]?
    public let autoApproveTiers: [QualityTier]?
    public let quotaPerWeek: Int?
    public let autoRequestsPerWeek: Int?
    public let ssSearchMissing: Bool?
    public let ssPlexRescan: Bool?
    public let ssRequestVersion: Bool?
    /// 0.4.209: Plex watchlist & lists may create requests.
    public let autoRequestPlexWatchlist: Bool?
    /// 0.4.213: every automatic Letterboxd source, and how many lists or
    /// watchlists may be linked (1–20).
    public let canLinkLists: Bool?
    public let maxLinkedLists: Int?
}

/// A user's or a role's request policy: the stored overrides (nil = inherit)
/// and the effective values. The same shape serves both (roles have no
/// auto-approve grant or quality mode; users have no member counts).
public struct RequestPolicy: Decodable, Sendable, Hashable {
    public let userId: Int?
    public let roleId: Int?
    public let roleName: String?
    public let members: Int?
    public let tierFollowers: Int?
    public let allowedTiers: [QualityTier]?
    public let autoApproveTiers: [QualityTier]?
    /// nil = inherit, 0 = unlimited.
    public let quotaPerWeek: Int?
    public let autoRequestsPerWeek: Int?
    public let ssSearchMissing: Bool?
    public let ssPlexRescan: Bool?
    public let ssRequestVersion: Bool?
    public let requestQualityMode: String?
    public let autoRequestPlexWatchlist: Bool?
    public let canLinkLists: Bool?
    public let maxLinkedLists: Int?
    public let effective: EffectiveRequestPolicy?
    public let inheritedFrom: [String: String]?
    public let allowedTiersSource: String?

    /// The raw `inherited_from` layer for one field: user · role · plex ·
    /// default · admin (0.4.212), or anything newer as sent.
    public func inheritedLayer(_ field: String) -> String? {
        // `inherited_from` keys are camel-cased by the decoder.
        let key = field.split(separator: "_").enumerated().map { $0 == 0 ? String($1) : $1.prefix(1).uppercased() + $1.dropFirst() }.joined()
        return inheritedFrom?[key] ?? inheritedFrom?[field]
    }

    /// "Inherited from role" / "Set here" for one field.
    public func source(_ field: String) -> String? {
        guard let raw = inheritedLayer(field) else { return nil }
        switch raw {
        case "user": return "Set for this person"
        case "role": return "From their role"
        case "plex": return "From Plex access"
        case "default": return "Default"
        case "admin": return "Admin: always allowed"
        default: return raw.capitalized
        }
    }

    /// An inherited on/off grant (web `inheritedFlagLine`): "Admin: always on",
    /// "Role Trusted: on", "Default: off".
    public func flagLine(_ field: String, on: Bool) -> String {
        let word = on ? "on" : "off"
        switch inheritedLayer(field) {
        case "admin": return "Admin: always \(word)"
        case "role": return "Role \(roleName ?? "default"): \(word)"
        default: return "Default: \(word)"
        }
    }
}

/// One live sign-in session.
public struct AccountSession: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let device: String
    /// phone · tablet · desktop · api · unknown
    public let deviceKind: String
    public let userAgent: String?
    public let ip: String?
    public let createdAt: String?
    public let lastSeenAt: String?
    public let current: Bool?
    /// `device_token`: a web view the app opened with its token.
    public let via: String?

    public var symbol: String {
        switch deviceKind {
        case "phone": return "iphone"
        case "tablet": return "ipad"
        case "desktop": return "desktopcomputer"
        case "api": return "key"
        default: return "questionmark.circle"
        }
    }
}

private struct RevokeResult: Decodable { let revoked: Int }

extension APIClient {
    // MARK: Users

    public func userAccounts() async throws -> [UserAccount] { try await get("/api/v1/users") }

    public func createUser(username: String, password: String, roleId: Int?) async throws -> UserAccount {
        try await sendJSON("POST", "/api/v1/users", .object([
            "username": .string(username), "password": .string(password), "role_id": roleId.map { .int($0) } ?? .null,
        ]))
    }

    /// Partial: rename, (re)assign the role, enable / disable the login.
    public func updateUser(id: Int, _ fields: [String: SettingsJSON]) async throws -> UserAccount {
        try await sendJSON("PATCH", "/api/v1/users/\(id)", .object(fields))
    }

    public func deleteUser(id: Int) async throws { try await sendJSON("DELETE", "/api/v1/users/\(id)") }

    /// Signs out every live session; the account stays enabled and its tokens keep working.
    public func revokeUserSessions(id: Int) async throws -> Int {
        let r: RevokeResult = try await sendJSON("POST", "/api/v1/users/\(id)/revoke-sessions")
        return r.revoked
    }

    // MARK: Roles

    public func roleDetails() async throws -> [RoleDetail] { try await get("/api/v1/roles") }
    public func roleCatalog() async throws -> RoleCatalog { try await get("/api/v1/roles/catalog") }

    public func saveRole(id: Int?, name: String, description: String?, permissions: [String], capabilities: [String]) async throws -> RoleDetail {
        let body: SettingsJSON = .object([
            "name": .string(name), "description": description.map { .string($0) } ?? .null,
            "permissions": .array(permissions.map { .string($0) }), "default_capabilities": .array(capabilities.map { .string($0) }),
        ])
        if let id { return try await sendJSON("PATCH", "/api/v1/roles/\(id)", body) }
        return try await sendJSON("POST", "/api/v1/roles", body)
    }

    public func deleteRole(id: Int) async throws { try await sendJSON("DELETE", "/api/v1/roles/\(id)") }

    // MARK: Request policy

    public func userRequestPolicy(id: Int) async throws -> RequestPolicy { try await get("/api/v1/users/\(id)/request-policy") }
    public func roleRequestPolicy(id: Int) async throws -> RequestPolicy { try await get("/api/v1/roles/\(id)/request-policy") }

    /// Partial PUT: absent = untouched, explicit null = inherit.
    public func putRequestPolicy(userId: Int? = nil, roleId: Int? = nil, _ fields: [String: SettingsJSON]) async throws -> RequestPolicy {
        let path = userId.map { "/api/v1/users/\($0)/request-policy" } ?? "/api/v1/roles/\(roleId ?? 0)/request-policy"
        return try await sendJSON("PUT", path, .object(fields))
    }

    // MARK: Sessions

    public func mySessions() async throws -> [AccountSession] { try await get("/api/v1/auth/sessions") }

    public func revokeMyOtherSessions() async throws -> Int {
        let r: RevokeResult = try await sendJSON("POST", "/api/v1/auth/sessions/revoke-others")
        return r.revoked
    }

    public func userSessions(userId: Int) async throws -> [AccountSession] { try await get("/api/v1/users/\(userId)/sessions") }

    public func revokeSession(userId: Int, sessionId: String) async throws {
        try await sendJSON("DELETE", "/api/v1/users/\(userId)/sessions/\(sessionId)")
    }
}

// MARK: - Download client capabilities (revamp §5.5)

/// What fusionha learned about a download client: can it check files (decypharr's verify API)?
public struct ClientCapabilities: Decodable, Sendable, Hashable {
    /// PRESENT · ABSENT · UNKNOWN
    public let verifyApi: String?
    public let verifyCheckedAt: String?
    public let fileChecks: Bool?
    public let lastProbeError: String?

    public enum State: Sendable { case available, absent, unknown }

    public var state: State {
        if fileChecks == true { return .available }
        return verifyApi == "ABSENT" ? .absent : .unknown
    }

    public var chip: String {
        switch state {
        case .available: return "Available"
        case .absent: return "Not available"
        case .unknown: return "Not checked yet"
        }
    }

    public var note: String {
        switch state {
        case .available: return "fusionha can check files with this client, so reports about it get a real answer."
        case .absent: return "This isn’t a decypharr build, so reports get the honest note and go to an admin."
        case .unknown: return "The next scheduled check fills this in, or press Re-check now."
        }
    }
}

extension APIClient {
    public func clientCapabilities(clientId: Int) async throws -> ClientCapabilities {
        try await get("/api/v1/downloadclients/\(clientId)/capabilities")
    }

    public func probeClientCapabilities(clientId: Int) async throws -> ClientCapabilities {
        try await sendJSON("POST", "/api/v1/downloadclients/\(clientId)/capabilities/probe")
    }
}
