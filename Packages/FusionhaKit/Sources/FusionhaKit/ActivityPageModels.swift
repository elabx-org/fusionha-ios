import Foundation

// MARK: - Wanted  (GET /api/v1/wanted?state=)

public enum WantedState: String, CaseIterable, Sendable {
    case missing
    case cutoffUnmet = "cutoff_unmet"
    case upcoming
}

public struct WantedPage: Decodable, Sendable {
    public let items: [WantedItem]
    public let total: Int
    public let missingCount: Int?
    public let cutoffUnmetCount: Int?
    public let upcomingCount: Int?
    public let missingTitles: Int?
    public let cutoffUnmetTitles: Int?
    public let upcomingTitles: Int?
}

public struct WantedItem: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let kind: MediaKind
    public let isAnime: Bool
    public let posterUrl: String?
    public let editions: [WantedEdition]
}

public struct WantedEdition: Decodable, Sendable, Identifiable, Hashable {
    public let editionId: Int
    public let tier: QualityTier
    public let state: String
    public let currentQuality: String?
    public let lastSearch: String?
    public let neverSearched: Bool?
    public let releasedAt: String?
    public let missingEpisodes: [WantedEpisode]?
    public let missingEpisodeCount: Int?
    public let latestAired: String?
    public let upcomingUntil: String?
    public var id: Int { editionId }
}

public struct WantedEpisode: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let title: String?
    public let airDate: String?

    public var code: String { EpisodeCode.episode(season: seasonNumber, episode: episodeNumber, separator: "") }
}

// MARK: - History  (GET /api/v1/history)

public struct HistoryPage: Decodable, Sendable {
    public let items: [HistoryEntry]
    public let total: Int
}

public struct HistoryEntry: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let eventType: String
    public let sourceTitle: String?
    public let indexer: String?
    public let quality: String?
    public let size: Double?
    public let createdAt: String
    public let mediaItemId: Int?
    public let itemTitle: String?
    public let tier: QualityTier?
    public let posterUrl: String?
    public let chips: [HistoryChip]?
    public let downloadClient: String?
    public let cfScore: Int?
    public let data: [String: LooseValue]?
    public let editionId: Int?
    public let episodeId: Int?
    public let downloadId: String?
    public let grabTrigger: String?
    public let `protocol`: String?
    public let blocklistable: Bool?
    /// The version's cut; nil for Standard (0.4.192).
    public let edition: String?
    /// HELD rows (0.4.203+): the hold's shared display copy.
    public var held: HeldDisplay? = nil

    public var eventLabel: String {
        eventType.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

public struct HistoryChip: Decodable, Sendable, Hashable {
    public let kind: String
    public let label: String
}

// MARK: - Blocklist  (GET /api/v1/blocklist)

public struct BlocklistPage: Decodable, Sendable {
    public let items: [BlocklistEntry]
    public let total: Int
}

public struct BlocklistEntry: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let reason: String?
    public let createdAt: String
    public let indexer: String?
    public let itemTitle: String?
    public let episodeLabel: String?
    public let posterUrl: String?
    public let guid: String?
    public let source: String?
    public let `protocol`: String?
    public let mediaItemId: Int?
    public let editionId: Int?
    public let episodeId: Int?
    public let sourceTitle: String?
    public let quality: String?
    public let formats: [String]?
    public let size: Double?
    public let tier: QualityTier?
}
