import Foundation

// Models for the native Settings panels under "Fetching" and "System":
// Root Folders, Download Clients, Indexers, Connect, Notifications,
// Connections, Public access, System, Database, Backup and Logs.
// Read shapes decode with the client's convertFromSnakeCase decoder;
// write bodies are built as `SettingsJSON` objects so explicit `null`s
// (clear a field) and snake_case keys go over the wire exactly as the web sends them.

// MARK: JSON write bodies

/// A JSON value for request bodies. Keys are sent verbatim (snake_case, as the web does).
public enum SettingsJSON: Sendable, Hashable, Encodable,
    ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
    ExpressibleByDictionaryLiteral {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([SettingsJSON])
    case object([String: SettingsJSON])

    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: SettingsJSON...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, SettingsJSON)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }

    /// `null` when nil, else the value.
    public static func optional(_ value: Int?) -> SettingsJSON { value.map(SettingsJSON.int) ?? .null }
    public static func optional(_ value: String?) -> SettingsJSON { value.map(SettingsJSON.string) ?? .null }
    public static func ints(_ values: [Int]) -> SettingsJSON { .array(values.map(SettingsJSON.int)) }
    public static func optionalInts(_ values: [Int]?) -> SettingsJSON { values.map(ints) ?? .null }

    public typealias Key = String
    public typealias Value = SettingsJSON
    public typealias ArrayLiteralElement = SettingsJSON

    private struct FieldKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .null:
            var c = encoder.singleValueContainer(); try c.encodeNil()
        case .bool(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .int(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .double(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .string(let v):
            var c = encoder.singleValueContainer(); try c.encode(v)
        case .array(let values):
            var c = encoder.unkeyedContainer()
            for value in values { try c.encode(value) }
        case .object(let fields):
            var c = encoder.container(keyedBy: FieldKey.self)
            for (key, value) in fields { try c.encode(value, forKey: FieldKey(stringValue: key)) }
        }
    }
}

/// `{ok, message}` from a `POST …/test` connection probe.
public struct ConnectionTestResult: Decodable, Sendable, Hashable {
    public let ok: Bool
    public let message: String
    /// Download clients only: the detected client version and its categories.
    public let version: String?
    public let categories: [String]?

    public init(ok: Bool, message: String, version: String? = nil, categories: [String]? = nil) {
        self.ok = ok
        self.message = message
        self.version = version
        self.categories = categories
    }
}

// MARK: Root folders

public enum ImportMode: String, CaseIterable, Sendable, Identifiable {
    case hardlink = "HARDLINK", symlink = "SYMLINK", copy = "COPY", move = "MOVE"
    public var id: String { rawValue }
    /// `Hardlink` / `Symlink` / `Copy` / `Move`.
    public var label: String { String(rawValue.prefix(1)) + rawValue.dropFirst().lowercased() }
}

/// `GET /api/v1/rootfolders` with free space and the tracked footprint.
public struct RootFolderInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let path: String
    public let defaultImportMode: String
    public let freeSpace: Int?
    public let totalSpace: Int?
    public let usedSpace: Int?
    public let accessible: Bool?
    public let trackedEditions: Int?
    public let trackedSize: Int?
    public let defaultFor: [AddDefaultSlot]?

    public var online: Bool { accessible != false }
    public var importMode: ImportMode { ImportMode(rawValue: defaultImportMode.uppercased()) ?? .hardlink }

    /// The tier a root holds, inferred from its path like the web (`/movies-4k` → 4K).
    public var inferredTier: QualityTier {
        path.range(of: "4k|2160|uhd", options: [.regularExpression, .caseInsensitive]) != nil ? .uhd : .hd
    }

    /// `anime` / `series` / `movie`, inferred from the path like the web.
    public var inferredKind: String {
        if path.range(of: "anime", options: .caseInsensitive) != nil { return "anime" }
        return path.range(of: "tv|series|anime|show", options: [.regularExpression, .caseInsensitive]) != nil
            ? "series" : "movie"
    }
}

// MARK: Download clients

public struct DownloadClientInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let `protocol`: String
    public let host: String
    public let port: Int
    public let useSsl: Bool?
    public let urlBase: String?
    public let username: String?
    public let passwordConfigured: Bool?
    public let enable: Bool?
    public let priority: Int?
    public let recentPriority: Int?
    public let olderPriority: Int?
    public let removeCompleted: Bool?
    public let removeFailed: Bool?
    public let postImportCategory: String?
    public let categoryMap: [String: String]?

    public var isTorrent: Bool { `protocol` == "TORRENT" }
}

// MARK: Indexers

public struct SearchIndexerInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let `protocol`: String
    public let baseUrl: String
    public let apiPath: String?
    public let apiKeyConfigured: Bool?
    public let categories: [Int]?
    public let animeCategories: [Int]?
    public let animeStandardFormatSearch: Bool?
    public let enabledSearch: Bool
    public let enabledRss: Bool
    public let priority: Int
    public let minQueryIntervalSeconds: Int?
    public let minimumAgeMinutes: Int?
    public let source: String?
    public let apiDailyLimit: Int?
    public let discoveryProbeUnlimited: Bool?
    public let discoveryDailyQueryCap: Int?
    public let kindScope: String?
    public let kindScopeOverride: String?

    /// An indexer is "enabled" when either search or RSS is on.
    public var isEnabled: Bool { enabledSearch || enabledRss }
    public var isTorrent: Bool { `protocol` == "TORRENT" }
    /// Prowlarr appends " (Prowlarr)"; the web strips it and shows a badge instead.
    public var displayName: String {
        name.replacingOccurrences(of: #"\s*\(prowlarr\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
    }
    public var effectiveKindScope: String {
        if let o = kindScopeOverride, !o.isEmpty { return o }
        return kindScope ?? "all"
    }
}

public struct IndexerTestAllResult: Decodable, Sendable {
    public struct Row: Decodable, Sendable, Hashable {
        public let id: Int
        public let name: String
        public let ok: Bool
        public let message: String
    }
    public let results: [Row]
}

/// `GET /api/v1/indexers/stats?range=`.
public struct IndexerStatsResponse: Decodable, Sendable {
    public let indexers: [IndexerStatRow]
    public let summary: IndexerStatsSummary?
}

public struct IndexerStatRow: Decodable, Sendable, Hashable {
    public struct Health: Decodable, Sendable, Hashable {
        public let state: String
        public let failureCount: Int?
        public let lastFailureReason: String?
        public let disabledTill: String?
    }
    public struct Caps: Decodable, Sendable, Hashable {
        public let tv: Bool?
        public let movie: Bool?
        public let anime: Bool?
        public let idSearch: Bool?
    }
    public struct ContentMix: Decodable, Sendable, Hashable {
        public let movie: Int?
        public let series: Int?
        public let anime: Int?
    }
    public struct TierMix: Decodable, Sendable, Hashable {
        public let hd: Int?
        public let uhd: Int?
    }
    public struct Exclusive: Decodable, Sendable, Hashable {
        public let total: Int?
        public let movie: Int?
        public let series: Int?
        public let anime: Int?
        public let hd: Int?
        public let uhd: Int?
        public let early: Int?
    }

    public let id: Int
    public let name: String
    public let health: Health
    public let caps: Caps?
    /// `grabs_24h`: convertFromSnakeCase capitalizes the "24h" component, so the
    /// key arrives as `grabs24H`.
    private let grabs24H: Int?
    public var grabs24h: Int? { grabs24H }
    public let grabsRange: Int?
    public let queriesRange: Int?
    public let successRateRange: Double?
    public let yieldRange: Double?
    public let activitySeries: [Int]?
    public let lastUsedAt: String?
    public let createdAt: String?
    public let contentMix: ContentMix?
    public let tierMix: TierMix?
    public let exclusive: Exclusive?
}

public struct IndexerStatsSummary: Decodable, Sendable, Hashable {
    public struct ProtocolMix: Decodable, Sendable, Hashable {
        public let usenetCount: Int?
        public let torrentCount: Int?
        public let usenetGrabShare: Double?
        public let torrentGrabShare: Double?
    }
    public struct EfficiencyEntry: Decodable, Sendable, Hashable {
        public let name: String
        public let yieldValue: Double
        enum CodingKeys: String, CodingKey { case name, yieldValue = "yield" }
    }
    public struct Efficiency: Decodable, Sendable, Hashable {
        public let leader: EfficiencyEntry?
        public let laggard: EfficiencyEntry?
    }
    public struct Coverage: Decodable, Sendable, Hashable {
        public let tv: Int?
        public let movie: Int?
        public let anime: Int?
        public let singleSource: [String]?
    }
    public struct NearLimit: Decodable, Sendable, Hashable {
        public let name: String
        public let queriesToday: Int
        public let cap: Int
    }
    public struct ApiBudget: Decodable, Sendable, Hashable {
        public let queriesToday: Int?
        public let totalKnownCap: Int?
        public let nearLimit: [NearLimit]?
    }
    public struct ExclusiveStat: Decodable, Sendable, Hashable {
        public let total: Int?
        public let grabs: Int?
        public let pct: Double?
    }
    public struct ExclusiveSummary: Decodable, Sendable, Hashable {
        public let all: ExclusiveStat?
        public let movie: ExclusiveStat?
        public let series: ExclusiveStat?
        public let anime: ExclusiveStat?
        public let hd: ExclusiveStat?
        public let uhd: ExclusiveStat?
    }

    public let indexers: Int?
    public let healthy: Int?
    public let backoff: Int?
    public let off: Int?
    public let grabsRange: Int?
    public let queriesRange: Int?
    public let avgSuccessRange: Double?
    public let protocolMix: ProtocolMix?
    public let efficiency: Efficiency?
    public let coverage: Coverage?
    public let apiBudget: ApiBudget?
    public let exclusive: ExclusiveSummary?
    public let activitySeries: [Int]?
}

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
}

public struct PushTestResult: Decodable, Sendable {
    public let sent: Int
    public let delivered: Int
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

// MARK: Backup

public struct BackupConfig: Decodable, Sendable, Hashable {
    public let enabled: Bool
    public let intervalHours: Int
    public let retention: Int
    public let folder: String
    public let available: Bool?
    public let backend: String?
}

public struct BackupRecord: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let sizeBytes: Int
    public let createdAt: String
    public let kind: String
    public let appVersion: String?
}

public struct BackupCreateResult: Decodable, Sendable {
    public let backup: BackupRecord
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
