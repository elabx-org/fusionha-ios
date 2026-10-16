import Foundation

// Settings › Security, native: encryption at rest for every stored secret
// (`/api/v1/system/secrets/*`, all `system.admin`) and visitor IP recording
// (`/api/v1/settings/visitor-ips`). Web `security/*`, `lib/api/secrets.ts`,
// `lib/api/visitor-ips.ts`.

public struct SecretsUnreadable: Decodable, Sendable, Hashable, Identifiable {
    /// Stable id: `setting:<key>` or `<table>:<id>.<column>`.
    public let name: String
    public let kind: String
    public let label: String
    public var id: String { name }

    public init(name: String, kind: String, label: String) {
        self.name = name
        self.kind = kind
        self.label = label
    }
}

public struct SecretsProgress: Decodable, Sendable, Hashable {
    public let running: Bool
    public let done: Int
    public let total: Int
}

public struct SecretsRotation: Decodable, Sendable, Hashable {
    public let running: Bool
    public let done: Int
    public let total: Int
    public let startedAt: String?
    public let error: String?
}

public struct SecretsRetiredKey: Decodable, Sendable, Hashable, Identifiable {
    public let fingerprint: String
    public let retiredAt: String
    public var id: String { fingerprint }
}

/// Display names of the configured rows that hold a secret (never a value).
public struct SecretsIntegrations: Decodable, Sendable, Hashable {
    public let indexers: [String]
    public let downloadClients: [String]
    public let virtualInstances: [String]
    public let notificationAgents: [String]
    public let connectWebhooks: [String]
    public let arrConnections: [String]

    public init(indexers: [String] = [], downloadClients: [String] = [], virtualInstances: [String] = [],
                notificationAgents: [String] = [], connectWebhooks: [String] = [], arrConnections: [String] = []) {
        self.indexers = indexers
        self.downloadClients = downloadClients
        self.virtualInstances = virtualInstances
        self.notificationAgents = notificationAgents
        self.connectWebhooks = connectWebhooks
        self.arrConnections = arrConnections
    }
}

/// `GET /api/v1/system/secrets/status`.
public struct SecretsStatus: Decodable, Sendable, Hashable {
    public let encrypted: Bool
    public let plaintextRemaining: Int
    public let unreadable: [SecretsUnreadable]
    public let keyFingerprint: String?
    /// `file` · `env` · `none`
    public let keySource: String
    /// `ok` · `rotating` · `locked_missing` · `locked_mismatch`
    public let state: String
    public let reason: String?
    public let encryptedCount: Int
    public let encryptPass: SecretsProgress
    public let rotation: SecretsRotation?
    public let keyPath: String?
    public let retiredKeys: [SecretsRetiredKey]
    public let backupIncludeSecretKey: Bool
    public let legacyBackups: Int
    public let firstRun: Bool
    public let keyCreatedAt: String?
    public let foundFingerprint: String?
    public let integrations: SecretsIntegrations?
    public let recoveryKeyStale: Bool?
}

/// `POST /recovery-key`: shown once.
public struct SecretsRecoveryKey: Decodable, Sendable, Hashable {
    public let key: String
    public let fingerprint: String
    public let filename: String
}

public struct SecretsRotationStarted: Decodable, Sendable {
    public let fingerprint: String
    public let state: String
}

public struct SecretsResetResult: Decodable, Sendable {
    public let reset: [String]
    public let status: SecretsStatus
}

/// How a key action proves it is you: the password, or a Plex re-auth grant.
public enum SecretsProof: Sendable, Hashable {
    case password(String)
    case grant(String)

    public var fields: [String: SettingsJSON] {
        switch self {
        case .password(let p): return ["password": .string(p)]
        case .grant(let g): return ["reauth_grant": .string(g)]
        }
    }
}

/// `GET/PUT /api/v1/settings/visitor-ips`.
public struct VisitorIpSettings: Decodable, Sendable, Hashable {
    public let recordingEnabled: Bool
    /// 0 keeps the address forever.
    public let retentionDays: Int

    /// The retention choices (web `RETENTION_OPTIONS`).
    public static let retentionOptions: [(Int, String)] = [
        (30, "30 days"), (90, "90 days (default)"), (365, "1 year"), (0, "Forever"),
    ]

    /// The sentence under the controls (web `keepText`).
    public static func keepText(on: Bool, days: Int) -> String {
        if !on {
            return "Off: new audit rows and sessions store no address. Existing ones keep theirs until retention clears them."
        }
        if days == 0 { return "Audit rows keep their address forever." }
        return "Rows older than \(days) days lose their address. The row itself stays: the audit trail is append-only and nothing is deleted."
    }
}

extension APIClient {
    private static let secretsBase = "/api/v1/system/secrets"

    public func secretsStatus() async throws -> SecretsStatus {
        try await get("\(Self.secretsBase)/status")
    }

    public func rotateSecretsKey(_ proof: SecretsProof) async throws -> SecretsRotationStarted {
        try await sendJSON("POST", "\(Self.secretsBase)/rotate", .object(proof.fields))
    }

    public func resumeSecretsRotation() async throws -> SecretsRotationStarted {
        try await sendJSON("POST", "\(Self.secretsBase)/rotate/resume")
    }

    public func secretsRecoveryKey(_ proof: SecretsProof) async throws -> SecretsRecoveryKey {
        try await sendJSON("POST", "\(Self.secretsBase)/recovery-key", .object(proof.fields))
    }

    /// Only while locked: paste the recovery key or the whole key file.
    public func unlockSecrets(key: String) async throws -> SecretsStatus {
        try await sendJSON("POST", "\(Self.secretsBase)/unlock", .object(["key": .string(key)]))
    }

    /// Only while locked: start over with a new key (`confirm` must be `START OVER`).
    public func startOverSecrets(_ proof: SecretsProof, confirm: String) async throws -> SecretsStatus {
        var body = proof.fields
        body["confirm"] = .string(confirm)
        return try await sendJSON("POST", "\(Self.secretsBase)/new-key", .object(body))
    }

    /// Resets exactly the named unreadable secrets (all or nothing).
    public func resetUnreadableSecrets(names: [String]) async throws -> SecretsResetResult {
        try await sendJSON("POST", "\(Self.secretsBase)/reset-unreadable",
                           .object(["names": .array(names.map { .string($0) })]))
    }

    /// "Include the key in backups": turning it on needs a proof, off does not.
    public func setBackupIncludesKey(_ on: Bool, proof: SecretsProof?) async throws {
        var body: [String: SettingsJSON] = proof?.fields ?? [:]
        body["include_secret_key"] = .bool(on)
        try await sendJSON("PUT", "/api/v1/system/backups/config", .object(body))
    }

    public func visitorIpSettings() async throws -> VisitorIpSettings {
        try await get("/api/v1/settings/visitor-ips")
    }

    public func updateVisitorIpSettings(_ fields: [String: SettingsJSON]) async throws -> VisitorIpSettings {
        try await sendJSON("PUT", "/api/v1/settings/visitor-ips", .object(fields))
    }
}
