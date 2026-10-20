import Foundation

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
public struct ActivityGradualStart: Decodable, Sendable {
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
