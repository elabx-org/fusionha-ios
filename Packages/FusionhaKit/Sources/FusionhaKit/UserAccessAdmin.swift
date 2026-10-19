import Foundation

// Settings › Users, per user: the instance access grants (web `AccessDialog`)
// and the sign-in methods of any account (web `UserCredentialsDialog`);
// `api/grants_routes.py`, `user_routes.py`.

/// An `AccessGrant` (`GrantRead`): the user may reach one virtual instance.
/// `instance_id` is nil for a wildcard grant.
public struct AccessGrant: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let userId: Int
    public let instanceId: Int?
    public let capabilities: [String]

    /// The per-instance grants by instance id (wildcards skipped), like the
    /// web's `grantByInstance`.
    public static func byInstance(_ grants: [AccessGrant]) -> [Int: AccessGrant] {
        var out: [Int: AccessGrant] = [:]
        for g in grants { if let i = g.instanceId, out[i] == nil { out[i] = g } }
        return out
    }
}

/// `POST /api/v1/users/{id}/credentials/{cid}/move`.
public struct MoveCredentialResult: Decodable, Sendable, Hashable {
    public let credentialId: Int
    public let provider: String
    public let sourceUserId: Int
    public let targetUserId: Int
    public let sourceSessionsRevoked: Int?
    public let plexAdopted: Bool?
}

/// Whose sign-in methods the sheet shows: the signed-in person or any account.
public struct SignInSubject: Sendable, Hashable {
    public let id: Int
    public let name: String
    public let credentials: [UserCredential]
    public let plexLinked: Bool
    public let plexUsername: String?

    public init(id: Int, name: String, credentials: [UserCredential], plexLinked: Bool, plexUsername: String?) {
        self.id = id
        self.name = name
        self.credentials = credentials
        self.plexLinked = plexLinked
        self.plexUsername = plexUsername
    }

    public init(_ me: Me) {
        self.init(id: me.id, name: me.displayName, credentials: me.credentials ?? [],
                  plexLinked: me.plexLinked == true, plexUsername: me.plexUsername)
    }

    public init(_ user: UserAccount) {
        self.init(id: user.id, name: user.displayName, credentials: user.credentials ?? [],
                  plexLinked: user.plexLinked == true, plexUsername: user.plexUsername)
    }

    public var hasLocal: Bool { credentials.contains { $0.provider == "local" } }
    public var hasPlex: Bool { credentials.contains { $0.provider == "plex" } }
    public var activeCount: Int { credentials.filter(\.isActive).count }

    /// Detach / disable would lock the person out (the server refuses it too).
    public func isLastActive(_ credential: UserCredential) -> Bool {
        credential.isActive && activeCount <= 1
    }

    /// INV8: a Plex-origin identity may not add its own first password unless
    /// it is a full system admin. An admin adding one for someone else may.
    public func addPasswordBlocked(isSelf: Bool, canAdminSystem: Bool) -> Bool {
        isSelf && !hasLocal && hasPlex && !canAdminSystem
    }

    /// The admin-only "Move to another identity" (never for Plex).
    public static func canMove(_ credential: UserCredential, canAdminSystem: Bool) -> Bool {
        canAdminSystem && credential.provider != "plex"
    }
}

extension APIClient {
    // MARK: Access grants

    /// `GET /api/v1/users/{id}/access`.
    public func userAccess(userId: Int) async throws -> [AccessGrant] {
        try await get("/api/v1/users/\(userId)/access")
    }

    /// `POST /api/v1/instances/{id}/grants` with the web's default `["read"]`.
    @discardableResult
    public func grantAccess(instanceId: Int, userId: Int, capabilities: [String] = ["read"]) async throws -> AccessGrant {
        try await sendJSON("POST", "/api/v1/instances/\(instanceId)/grants", .object([
            "user_id": .int(userId), "capabilities": .array(capabilities.map { .string($0) }),
        ]))
    }

    /// `DELETE /api/v1/grants/{id}`.
    public func revokeGrant(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/grants/\(id)")
    }

    // MARK: Sign-in methods (admin)

    /// Re-points one credential onto another identity (system.admin only).
    @discardableResult
    public func moveCredential(userId: Int, credentialId: Int, targetUserId: Int) async throws -> MoveCredentialResult {
        try await sendJSON("POST", "/api/v1/users/\(userId)/credentials/\(credentialId)/move",
                           .object(["target_user_id": .int(targetUserId)]))
    }
}
