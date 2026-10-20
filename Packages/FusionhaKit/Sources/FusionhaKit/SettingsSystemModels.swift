import Foundation

// MARK: Connect

public enum NotificationAgentKind: String, CaseIterable, Sendable, Identifiable {
    case discord, telegram, webhook
    public var id: String { rawValue }
}

public struct NotificationAgentInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let kind: String
    public let enabled: Bool
    public let onGrab: Bool
    public let onImport: Bool
    public let onUpgrade: Bool
    public let onManualRequired: Bool
    public let onFailed: Bool
    public let onRequest: Bool?
    public let urlConfigured: Bool?
    public let tokenConfigured: Bool?
    public let chatId: String?

    public var agentKind: NotificationAgentKind { NotificationAgentKind(rawValue: kind) ?? .webhook }

    /// The subscribed events keyed by their wire names.
    public var events: [String: Bool] {
        ["on_grab": onGrab, "on_import": onImport, "on_upgrade": onUpgrade,
         "on_manual_required": onManualRequired, "on_failed": onFailed, "on_request": onRequest ?? false]
    }
}

/// `GET /api/v1/arr-webhooks`: connections external tools registered on a virtual instance.
public struct ArrWebhookGroup: Decodable, Sendable, Hashable, Identifiable {
    public struct Webhook: Decodable, Sendable, Hashable, Identifiable {
        public let id: Int
        public let name: String
        public let url: String?
        public let source: String?
        public let onGrab: Bool?
        public let onImport: Bool?
        public let onUpgrade: Bool?
        public let onRename: Bool?
        public let onDelete: Bool?
        // The full `ArrWebhookRead` the native edit sheet (S4) loads from.
        public var instanceId: Int?
        public var method: Int?
        public var username: String?
        public var headers: [String: String]?
        public var sendValidationResults: Bool?
        public var passwordConfigured: Bool?
        public var onDeleteForUpgrade: Bool?
        public var onManualInteractionRequired: Bool?
        public var onImportFailure: Bool?
        public var onDownloadFailure: Bool?
        public var onMediaAdded: Bool?
        public var onMediaRemoved: Bool?
        public var onHealthIssue: Bool?
        public var onHealthRestored: Bool?
        public var onApplicationUpdate: Bool?
        public var pathMappings: [ArrWebhookPathMapping]?
    }
    public let instanceSlug: String
    public let instanceLabel: String
    public let notifications: [Webhook]
    public var id: String { instanceSlug }
}

// MARK: Notifications (Web Push)

public struct NotificationPreferenceItem: Decodable, Sendable, Hashable {
    public let eventKind: String
    public let enabled: Bool
    /// IMMEDIATE · DIGEST · OFF (fusionha phase 3); nil on older servers.
    public let delivery: String?
    public let defaultDelivery: String?
    public let digestAllowed: Bool?
    public let retired: Bool?
    /// requester · admin · operational
    public let audience: String?
}

/// `GET /notifications/digest/preview`: the pending daily digest as it would be sent, or a sample.
public struct DigestPreview: Decodable, Sendable {
    public let pending: Int
    public let title: String
    public let body: String
    public let sample: Bool
    public let digestTime: String
    public let nextSendAt: String?
    public let heldByQuietHours: Bool?
}

public struct NotificationPreferences: Decodable, Sendable {
    public let preferences: [NotificationPreferenceItem]
}

public struct PushSubscriptionInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let deviceLabel: String?
    public let userAgent: String?
    public let createdAt: String?
    public let lastSeenAt: String?
    public let lastSuccessAt: String?
    public let failureCount: Int?
    public let disabled: Bool?
}

public struct WebPushSettings: Decodable, Sendable, Hashable {
    public let enabled: Bool
    public let grouping: String?
    public let quietHoursEnabled: Bool?
    public let quietHoursStart: String?
    public let quietHoursEnd: String?
    /// The daily digest's send time, `HH:MM` server time (fusionha A10); nil on older servers.
    public let digestTime: String?
}

public struct PushTestResult: Decodable, Sendable {
    public let sent: Int
    public let delivered: Int
    /// Per-device outcome (`PushDeviceTestResult`); absent on older servers.
    public let devices: [PushDeviceTestResult]?
}

public struct PushDeviceTestResult: Decodable, Sendable, Hashable {
    public let id: Int
    public let deviceLabel: String?
    public let ok: Bool
    public let detail: String
}

public struct VapidRotateResult: Decodable, Sendable {
    public let invalidated: Int
}

// MARK: Connections

/// A virtual arr instance (Radarr-HD, Sonarr-4K, …). The key is masked except its last 4.
public struct VirtualInstance: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let slug: String
    public let flavor: String
    public let kind: String
    public let tier: QualityTier
    public let instanceName: String
    public let defaultRootFolderId: Int?
    public let defaultQualityProfileId: Int?
    public let allowedQualityProfileIds: [Int]?
    public let allowedRootFolderIds: [Int]?
    public let enabled: Bool
    public let scope: String?
    public let apiKeyLast4: String?

    public var isRadarr: Bool { flavor.uppercased() == "RADARR" }
}

public struct InstanceKeyReveal: Decodable, Sendable {
    public let id: Int
    public let apiKey: String
}

/// A personal API token (`GET /api/v1/tokens`); the secret is only shown on mint.
public struct ApiTokenInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let tokenPrefix: String
    public let lastUsedAt: String?
    public let expiresAt: String?
    public let createdAt: String?
}

// MARK: Public access (demo mode)

public struct DemoStatus: Decodable, Sendable, Hashable {
    public struct Counts: Decodable, Sendable, Hashable {
        public let movies: Int?
        public let series: Int?
        public let anime: Int?
        public let editions: Int?
        public let files: Int?
        public let downloadsActive: Int?
        public let historyEvents: Int?
    }
    public let demoMode: Bool
    public let demoSeeded: Bool
    public let itemCount: Int?
    public let demoRequireCredentials: Bool
    public let demoUsername: String?
    public let demoPasswordSet: Bool?
    public let demoInstanceEnv: Bool?
    public let realLibraryPresent: Bool?
    public let demoAutoResetHours: Int?
    public let counts: Counts?
}

// MARK: System

public struct SystemTask: Decodable, Sendable, Identifiable, Hashable {
    public let name: String
    public let intervalSeconds: Int
    public let running: Bool
    public let lastRun: String?
    public let lastDuration: Double?
    public let lastResult: String?
    public let nextRun: String?
    public var id: String { name }
}

public struct SystemCommand: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let status: String
    public let message: String?
    public let progress: Double?
}

// MARK: Database

public struct DatabaseBackendInfo: Decodable, Sendable {
    public struct SQLiteFacts: Decodable, Sendable {
        public let location: String?
        public let sizeBytes: Int?
        public let journalMode: String?
        public let mediaFileCount: Int?
    }
    public struct TargetFacts: Decodable, Sendable {
        public let serverVersion: String?
        public let database: String?
    }
    public let backend: String
    public let applicable: Bool?
    public let sqlite: SQLiteFacts?
    public let target: TargetFacts?
}

// MARK: Logs

public struct LogRecord: Decodable, Sendable, Hashable {
    public let ts: Double
    public let level: String
    public let logger: String
    public let message: String
    public let traceback: String?
}

// MARK: Errors

extension APIError {
    /// FastAPI's `detail` (a string, `{message}` or a validation list), when the server sent one.
    public var serverDetail: String? {
        guard case .http(_, let body) = self,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let detail = json["detail"]
        if let text = detail as? String { return text }
        if let object = detail as? [String: Any], let message = object["message"] as? String { return message }
        if let list = detail as? [[String: Any]] {
            let parts = list.compactMap { $0["msg"] as? String }
            return parts.isEmpty ? nil : parts.joined(separator: "; ")
        }
        return nil
    }
}

extension Error {
    /// The server's own words when it gave any, else the localized description.
    public var settingsMessage: String {
        (self as? APIError)?.serverDetail ?? localizedDescription
    }
}

extension AddDefaultSlot {
    /// Public for the app target (the synthesized memberwise init is internal).
    public init(kind profileKind: String, tier: QualityTier, profileId qualityProfileId: Int?, rootId rootFolderId: Int?) {
        self.profileKind = profileKind
        self.tier = tier
        self.qualityProfileId = qualityProfileId
        self.rootFolderId = rootFolderId
    }
}
