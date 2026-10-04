import Foundation

// Models for the Activity (Queue / History / Blocklist / Tasks / Audit / Indexers)
// and Wanted screens. Field names follow the server's snake_case JSON, decoded with
// `.convertFromSnakeCase`; anything the server may leave out is optional.

/// A JSON scalar of unknown type (history `data` values). Nested objects and arrays
/// decode as `.other` instead of failing the whole row.
public enum LooseValue: Decodable, Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case other

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else { self = .other }
    }

    public var text: String? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.rounded() == n ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null, .other: return nil
        }
    }
}

extension Dictionary where Key == String, Value == LooseValue {
    /// Looks a value up by its wire key (the decoder may have camel-cased it).
    public func text(_ snakeKey: String) -> String? {
        if let v = self[snakeKey]?.text { return v }
        let parts = snakeKey.split(separator: "_")
        let camel = parts.enumerated().map { $0.offset == 0 ? String($0.element) : $0.element.capitalized }.joined()
        return self[camel]?.text
    }
}

// MARK: - Queue

/// Why a HELD download was not auto-imported (the not-an-upgrade comparison).
public struct HeldDetail: Decodable, Sendable, Hashable {
    public let kind: String?
    public let claimedQuality: String?
    public let probedQuality: String?
    public let probedResolution: HeldResolution?
    public let mislabeled: Bool?
    public let candidateCf: Int?
    public let currentQuality: String?
    public let currentCf: Int?
    public let currentGroup: String?
    public let verdict: String?
}

public struct HeldResolution: Decodable, Sendable, Hashable {
    public let w: Int
    public let h: Int
}

/// `POST /api/v1/queue/process`.
public struct QueueProcessResult: Decodable, Sendable {
    public let inFlight: Int?
    public let imported: Int
    public let resolved: Int
    public let left: Int
    public let skipped: Bool
    public let skipReason: String?
}

// MARK: - History

public struct HistorySparklineDay: Decodable, Sendable, Hashable {
    public let date: String
    public let count: Int
}

/// `POST /api/v1/history/{id}/regrab`.
public struct RegrabResult: Decodable, Sendable {
    public let grabbed: Bool
    public let fromOriginalIndexer: Bool?
    public let indexerName: String?
    public let searchedCandidates: Int?
    public let reason: String?
}

struct RegrabRequest: Encodable {
    let override: Bool
}

// MARK: - Blocklist

/// `POST /api/v1/blocklist` body: a history event or a queue download.
public struct BlocklistCreate: Encodable, Sendable {
    public let historyId: Int?
    public let downloadId: Int?
    public let search: Bool
    public let deleteCurrentFile: Bool?

    public init(historyId: Int? = nil, downloadId: Int? = nil, search: Bool, deleteCurrentFile: Bool = false) {
        self.historyId = historyId
        self.downloadId = downloadId
        self.search = search
        // Only sent when opted in, like the web.
        self.deleteCurrentFile = deleteCurrentFile ? true : nil
    }
}

public struct BlocklistCreateResponse: Decodable, Sendable {
    public let entry: BlocklistEntry?
    public let created: Bool
    public let searchDispatched: Bool?
    public let fileDeleted: Bool?
}

struct BlocklistIds: Encodable {
    let ids: [Int]
}

public struct ClearedCount: Decodable, Sendable {
    public let deleted: Int
}

// MARK: - Tasks  (GET /api/v1/system/runs, /system/tasks)

public struct CommandRun: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let trigger: String
    public let status: String
    public let itemId: Int?
    public let mediaKind: String?
    public let scope: String?
    public let targetTitle: String?
    public let targetCount: Int?
    public let targetSummary: String?
    public let startedAt: String
    public let endedAt: String?
    public let durationMs: Int?
    public let releases: Int
    public let evaluated: Int
    public let grabbed: Int
    public let upgraded: Int
    public let rejected: Int
    public let errors: Int
    public let skippedInFlight: Bool?
    public let phase: String?
    public let progressCurrent: Int?
    public let progressTotal: Int?
    public let detail: String?
    public let search: SearchProgress?
}

public struct SearchProgress: Decodable, Sendable, Hashable {
    public let processed: Int
    public let total: Int
    public let current: String?
    public let grabbed: Int
    public let noRelease: Int
    public let queued: Int
    public let lastProgressAt: String?
    public let stopped: Bool
    public let stuck: Bool
    public let stalledSeconds: Double?
    public let targets: [SearchScopeTarget]
}

public struct SearchScopeTarget: Decodable, Sendable, Hashable {
    public let group: String
    public let tier: String?
    public let label: String
    public let state: String
}

public struct CommandRunPage: Decodable, Sendable {
    public let items: [CommandRun]
    public let total: Int
}

/// One release a run considered (`GET /api/v1/system/runs/{id}`).
public struct RunCandidate: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let releaseTitle: String
    public let releaseGroup: String?
    public let size: Double?
    public let `protocol`: String?
    public let indexer: String?
    public let quality: String?
    public let cfScore: Int?
    public let action: String
    public let reason: String
    public let blocklisted: Bool?
}

public struct CommandRunDetail: Decodable, Sendable {
    public let id: Int
    public let candidates: [RunCandidate]
    // The run's live state (the gradual-search strip polls this).
    public let status: String?
    public let phase: String?
    public let progressCurrent: Int?
    public let progressTotal: Int?
    public let detail: String?
}

public struct ActivitySystemTask: Decodable, Sendable, Hashable {
    public let name: String
    public let intervalSeconds: Int
    public let running: Bool
    public let lastRun: String?
    public let lastDuration: Double?
    public let lastResult: String?
    public let nextRun: String
}

public struct EnrichmentStatus: Decodable, Sendable {
    public let totalFiles: Int?
    public let enrichedFiles: Int?
    public let pendingFiles: Int?
    public let issueFiles: Int?
    public let subtasks: [EnrichmentSubtask]?
}

public struct EnrichmentSubtask: Decodable, Sendable, Hashable {
    public let importSessionId: Int?
}

/// The two settings the Activity / Wanted screens flip (`GET/PUT /api/v1/settings`).
public struct ActivitySettings: Decodable, Sendable {
    public let voicePlayful: Bool?
    /// The web's global motion switch (Settings → Appearance).
    public let animationsEnabled: Bool?
    public let uhdAvailableObserverEnabled: Bool?
    /// Spacing of the gradual (one-episode-at-a-time) search, in seconds.
    public let seasonSearchIntervalSeconds: Int?
}

public struct ActivitySettingsUpdate: Encodable, Sendable {
    public let voicePlayful: Bool?
    public let uhdAvailableObserverEnabled: Bool?
    public init(voicePlayful: Bool? = nil, uhdAvailableObserverEnabled: Bool? = nil) {
        self.voicePlayful = voicePlayful
        self.uhdAvailableObserverEnabled = uhdAvailableObserverEnabled
    }
}

// MARK: - Audit  (GET /api/v1/audit)

public struct AuditEntry: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let actor: String
    public let action: String
    public let target: String?
    public let at: String
}

// MARK: - Indexers  (GET /api/v1/indexers/stats)

public struct ActivityIndexerStats: Decodable, Sendable {
    public let indexers: [IndexerStat]
    public let summary: ActivityIndexerSummary
}

public struct IndexerStat: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let `protocol`: String?
    public let health: IndexerHealth?
    public let grabsRange: Int?
    public let queriesRange: Int?
    public let successRateRange: Double?
    public let queriesToday: Int?
    public let activitySeries: [Int]?
}

public struct IndexerHealth: Decodable, Sendable, Hashable {
    public let state: String
    public let failureCount: Int?
    public let lastFailureReason: String?
}

public struct ActivityIndexerSummary: Decodable, Sendable {
    public let range: String
    public let indexers: Int
    public let healthy: Int
    public let backoff: Int
    public let off: Int
    public let grabsRange: Int?
    public let queriesRange: Int?
    public let avgSuccessRange: Double?
    public let activitySeries: [Int]?
}

// MARK: - Wanted · 4K available  (GET /api/v1/wanted/4k-available)

public struct FourKAvailablePage: Decodable, Sendable {
    public let items: [FourKAvailableItem]
    public let total: Int
    public let fourkAvailableCount: Int?
}

public struct FourKAvailableItem: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let kind: MediaKind
    public let isAnime: Bool
    public let posterUrl: String?
    public let hdEditionId: Int?
    public let seenCount: Int
    public let bestReleaseName: String?
    public let bestQuality: String?
    public let bestSize: Double?
    public let lastSeenAt: String?
    public let source: String?
    public let sources: [String]?
    public let formatTags: [FormatTag]?
    public let totalSeasons: Int?
    public let hdOwnedSeasons: Int?
    public let uhdAvailableSeasons: Int?
    public let seasons: [FourKSeason]?
}

public struct FourKSeason: Decodable, Sendable, Hashable, Identifiable {
    public let seasonNumber: Int
    public let seenCount: Int
    public let bestReleaseName: String?
    public let bestQuality: String?
    public let source: String?
    public var id: Int { seasonNumber }
}

public struct CheckFourKResult: Decodable, Sendable {
    public let foundUhd: Bool
    public let message: String
}

/// `POST /api/v1/library/{id}/search/gradual`.
public struct GradualSearchStart: Decodable, Sendable {
    public let runId: Int?
    public let total: Int
    public let alreadyRunning: Bool?
}

/// `POST /api/v1/library/{id}/editions` (the 4K tab's "Add edition").
public struct EditionAddRequest: Encodable, Sendable {
    public let tier: QualityTier
    public let rootFolderId: Int
    public let qualityProfileId: Int
    public let monitored: Bool
    public let searchNow: Bool
    public init(tier: QualityTier, rootFolderId: Int, qualityProfileId: Int, monitored: Bool, searchNow: Bool) {
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = monitored
        self.searchNow = searchNow
    }
}

extension APIError {
    /// A 409 "already running" body's `detail.run_id` (gradual search).
    public var detailRunId: Int? {
        guard case .http(_, let body) = self,
              let obj = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let d = obj["detail"] as? [String: Any] else { return nil }
        return (d["run_id"] as? NSNumber)?.intValue
    }

    public var status: Int? {
        if case .http(let status, _) = self { return status }
        return nil
    }
}
