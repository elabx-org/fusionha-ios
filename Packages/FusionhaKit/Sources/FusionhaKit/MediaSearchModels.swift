import Foundation

// MARK: - Discover / TMDB search  (GET /api/v1/discover, /api/v1/search)

public enum SearchKind: String, CaseIterable, Sendable {
    case all, movie, series, anime
    public var title: String {
        switch self {
        case .all: return "All"
        case .movie: return "Movies"
        case .series: return "Series"
        case .anime: return "Anime"
        }
    }
}

public enum DiscoverList: String, Sendable {
    case trending, popular
    case topRated = "top_rated"
    case upcoming
    case nowPlaying = "now_playing"
    case onTheAir = "on_the_air"
    case airingToday = "airing_today"
}

public struct MediaSearchResult: Decodable, Sendable, Identifiable, Hashable {
    public let tmdbId: Int
    public let title: String
    public let year: Int?
    public let kind: MediaKind
    public let isAnime: Bool
    public let overview: String?
    public let inLibrary: Bool
    public let libraryItemId: Int?
    public let posterUrl: String?
    public let backdropUrl: String?
    /// The full release/air date (`YYYY-MM-DD`); the year falls back to it.
    public let date: String?
    public let voteAverage: Double?
    public var id: String { "\(kind.rawValue)-\(tmdbId)" }
}

// MARK: - Requests  (GET/POST /api/v1/requests)

public struct MediaRequest: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let tmdbId: Int
    public let kind: MediaKind
    public let mediaItemId: Int?
    public let tier: QualityTier
    public let status: String
    public let note: String?
    public let requestedAt: String?
    public let userId: Int?
    public let editions: [QualityTier]?
    public let seasons: [Int]?
    public let episodes: [EpisodeRef]?
    public let reason: String?
    // Requests revamp (fusionha phases 1–7, `RequestRevampModels.swift`); all
    // optional so an older server still decodes.
    public let decidedAt: String?
    public let quotaExceeded: Bool?
    public let joined: Bool?
    public let joinedRequestId: Int?
    public let title: String?
    public let year: Int?
    public let poster: String?
    public let requester: RequestPerson?
    public let approvedBy: RequestApprovedBy?
    public let declinedBy: RequestPerson?
    public let source: RequestSource?
    public let lifecycle: [RequestLifecycleEntry]?
    public let decisionNote: String?
    public let availableAt: String?
    public let thread: RequestThreadSummary?
    public let demand: RequestDemand?
    public let quotaState: String?
    public let watch: Bool?
    public let joiners: [RequestPerson]?
    public let held: RequestHeld?
}

public struct MediaRequestCreate: Encodable, Sendable {
    public let tmdbId: Int
    public let kind: MediaKind
    public let tier: QualityTier?
    public init(tmdbId: Int, kind: MediaKind, tier: QualityTier?) {
        self.tmdbId = tmdbId
        self.kind = kind
        self.tier = tier
    }
}
