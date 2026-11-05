import Foundation

// Models for Settings › Indexers (moved out of SettingsFetchingModels.swift),
// decoded with the client's convertFromSnakeCase decoder.

// MARK: Indexers

public struct SearchIndexerInfo: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let `protocol`: String
    public let baseUrl: String
    public let apiPath: String?
    public let apiKeyConfigured: Bool?
    public let categories: [Int]?
    public let tvCategories: [Int]?
    public let movieCategories: [Int]?
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
    /// The search modes the indexer's caps advertise (`search_caps` keys).
    public let searchCaps: SearchCapKeys?
    /// When the last query failed (ISO date-time), for the failure state.
    public let lastFailureAt: String?

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
    public let `protocol`: String?
    public let priority: Int?
    public let health: Health
    public let caps: Caps?
    public let queriesToday: Int?
    public let grabsTotal: Int?
    /// `grabs_7d` arrives as `grabs7D` (see `grabs24H`).
    private let grabs7D: Int?
    public var grabs7d: Int? { grabs7D }
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

/// `search_caps` is a free-form object on the wire; v2 only needs which
/// modes it names. Decodes leniently: any value under any key.
public struct SearchCapKeys: Decodable, Sendable, Hashable {
    /// The keys, sorted (as the snake-case decoder delivers them).
    public let keys: [String]

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        // Not an object: no modes, rather than failing the whole indexer.
        guard let c = try? decoder.container(keyedBy: AnyKey.self) else {
            keys = []
            return
        }
        keys = c.allKeys.map(\.stringValue).sorted()
    }
}
