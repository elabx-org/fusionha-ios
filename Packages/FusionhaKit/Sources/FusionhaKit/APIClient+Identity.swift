import Foundation

/// `GET /api/v1/users/duplicates`: people who probably signed in two ways.
public struct DuplicatesRead: Decodable, Sendable {
    public let groups: [DuplicateGroup]

    enum CodingKeys: String, CodingKey { case groups }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groups = try c.decodeIfPresent([DuplicateGroup].self, forKey: .groups) ?? []
    }
}

public struct DuplicateGroup: Decodable, Sendable, Hashable, Identifiable {
    public let reason: String
    public let key: String
    public let members: [DuplicateMember]
    public var id: String { key }

    enum CodingKeys: String, CodingKey { case reason, key, members }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reason = try c.decode(String.self, forKey: .reason)
        key = try c.decode(String.self, forKey: .key)
        members = try c.decodeIfPresent([DuplicateMember].self, forKey: .members) ?? []
    }
}

public struct DuplicateMember: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let username: String
    public let authProvider: String
    public let isAdmin: Bool

    enum CodingKeys: String, CodingKey { case id, username, authProvider, isAdmin }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        authProvider = try c.decodeIfPresent(String.self, forKey: .authProvider) ?? "local"
        isAdmin = try c.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
    }
}

/// `POST /api/v1/users/{survivor}/merge`: the effective result (dry run) or the merge.
public struct MergePreview: Decodable, Sendable {
    public let resultingRoleName: String?
    public let resultingIsAdmin: Bool
    public let credentialsRepointed: Int
    public let requestsRepointed: Int
    public let requestsMerged: Int
    public let issuesRepointed: Int
    public let sessionsDeleted: Int
    public let refused: Bool
    public let blockers: [String]

    enum CodingKeys: String, CodingKey {
        case resultingRoleName, resultingIsAdmin, credentialsRepointed, requestsRepointed, requestsMerged
        case issuesRepointed, sessionsDeleted, refused, blockers
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ k: CodingKeys) throws -> Int { try c.decodeIfPresent(Int.self, forKey: k) ?? 0 }
        resultingRoleName = try c.decodeIfPresent(String.self, forKey: .resultingRoleName)
        resultingIsAdmin = try c.decodeIfPresent(Bool.self, forKey: .resultingIsAdmin) ?? false
        credentialsRepointed = try int(.credentialsRepointed)
        requestsRepointed = try int(.requestsRepointed)
        requestsMerged = try int(.requestsMerged)
        issuesRepointed = try int(.issuesRepointed)
        sessionsDeleted = try int(.sessionsDeleted)
        refused = try c.decodeIfPresent(Bool.self, forKey: .refused) ?? false
        blockers = try c.decodeIfPresent([String].self, forKey: .blockers) ?? []
    }

    /// "Resulting role": the role, else Admin / None.
    public var roleLine: String { resultingRoleName ?? (resultingIsAdmin ? "Admin" : "None") }
}

/// `POST /api/v1/users/credentials/disconnect`: who keeps a sign-in and who would be left without.
public struct DisconnectPreview: Decodable, Sendable {
    public struct Affected: Decodable, Sendable, Hashable {
        public let userId: Int
        public let username: String
        public let wouldBeZeroed: Bool
    }

    public let provider: String
    public let affected: [Affected]
    public let refused: Bool
    public let blockers: [String]

    enum CodingKeys: String, CodingKey { case provider, affected, refused, blockers }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decode(String.self, forKey: .provider)
        affected = try c.decodeIfPresent([Affected].self, forKey: .affected) ?? []
        refused = try c.decodeIfPresent(Bool.self, forKey: .refused) ?? false
        blockers = try c.decodeIfPresent([String].self, forKey: .blockers) ?? []
    }

    public var zeroed: Int { affected.filter(\.wouldBeZeroed).count }
    public var safe: Int { affected.count - zeroed }
}

/// What happens to the people a disconnect would leave without a sign-in.
public enum DisconnectFallback: String, CaseIterable, Sendable {
    case disable, password, delete

    public var label: String {
        switch self {
        case .disable: return "Disable sign-in (keep everything)"
        case .password: return "Refuse if it would leave anyone without a login"
        case .delete: return "Delete the accounts (removes them + their requests)"
        }
    }
}

extension APIClient {
    public func userDuplicates() async throws -> [DuplicateGroup] {
        let read: DuplicatesRead = try await get("/api/v1/users/duplicates")
        return read.groups
    }

    /// Dry run first (the default); only an explicit confirm passes `dryRun: false`.
    public func mergeUsers(survivor: Int, loser: Int, dryRun: Bool) async throws -> MergePreview {
        try await sendJSON("POST", "/api/v1/users/\(survivor)/merge", .object([
            "loser": .int(loser), "role_resolution": .string("keep_survivor"), "dry_run": .bool(dryRun),
        ]))
    }

    public func disconnectProvider(_ provider: String, fallback: DisconnectFallback, dryRun: Bool) async throws -> DisconnectPreview {
        try await sendJSON("POST", "/api/v1/users/credentials/disconnect", .object([
            "provider": .string(provider), "fallback": .string(fallback.rawValue), "dry_run": .bool(dryRun),
        ]))
    }

    /// The server always checks `current_password` against the target's own
    /// password (no admin bypass), like the web.
    public func changePassword(userId: Int, newPassword: String, currentPassword: String = "") async throws {
        try await sendJSON("POST", "/api/v1/users/\(userId)/change-password", .object([
            "current_password": .string(currentPassword), "new_password": .string(newPassword),
        ]))
    }
}
