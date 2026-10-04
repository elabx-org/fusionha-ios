import Foundation

// Models for Discover, Preview, Requests, Issues and the requester "You" page.
// Field names follow the backend schemas (`api/schemas.py`), decoded with
// `.convertFromSnakeCase`; optional fields are the nullable/defaulted ones.

// MARK: - Discover rails

/// `GET /api/v1/discover/trailers`: a discover row plus its YouTube key.
public struct TrailerResult: Decodable, Sendable, Identifiable, Hashable {
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
    public let date: String?
    public let voteAverage: Double?
    public let trailerKey: String
    public var id: String { "\(kind.rawValue)-\(tmdbId)-\(trailerKey)" }

    /// The year, else the first four characters of `date`.
    public var displayYear: Int? { year ?? date.flatMap { Int($0.prefix(4)) } }

    public var asSearchResult: MediaSearchResult {
        MediaSearchResult(tmdbId: tmdbId, title: title, year: year, kind: kind, isAnime: isAnime,
                          overview: overview, inLibrary: inLibrary, libraryItemId: libraryItemId,
                          posterUrl: posterUrl, backdropUrl: backdropUrl, date: date, voteAverage: voteAverage)
    }
}

/// The "What's Popular" monetization toggle.
public enum DiscoverMonetization: String, CaseIterable, Sendable {
    case streaming
    case onTv = "on_tv"
    case rent
    case theatres

    public var title: String {
        switch self {
        case .streaming: return "Streaming"
        case .onTv: return "On TV"
        case .rent: return "For Rent"
        case .theatres: return "In Theatres"
        }
    }
}

/// `GET /api/v1/collections`: a partially-owned franchise.
public struct CollectionSummary: Decodable, Sendable, Identifiable, Hashable {
    public let collectionTmdbId: Int
    public let name: String
    public let posterUrl: String?
    public let backdropUrl: String?
    public let ownedCount: Int
    public let totalCount: Int
    public var id: Int { collectionTmdbId }
}

/// `GET /api/v1/collections/{id}`.
public struct CollectionDetail: Decodable, Sendable {
    public let collectionTmdbId: Int
    public let name: String
    public let ownedCount: Int
    public let totalCount: Int
    public let parts: [CollectionPart]
}

public struct CollectionPart: Decodable, Sendable, Hashable {
    public let tmdbId: Int
    public let title: String?
    public let year: Int?
    public let inLibrary: Bool?
}

public struct CollectionAddBody: Encodable, Sendable {
    public let tmdbIds: [Int]
    public let editions: [EditionCreate]
    public let monitor: String
    public let minimumAvailability: String?
    public let searchOnAdd: Bool?
    public init(tmdbIds: [Int], editions: [EditionCreate], monitor: String = "all",
                minimumAvailability: String? = nil, searchOnAdd: Bool? = true) {
        self.tmdbIds = tmdbIds
        self.editions = editions
        self.monitor = monitor
        self.minimumAvailability = minimumAvailability
        self.searchOnAdd = searchOnAdd
    }
}

public struct DiscoverIgnoreCreate: Encodable, Sendable {
    public let scope: String
    public let collectionTmdbId: Int
    public let name: String
    public init(collectionTmdbId: Int, name: String) {
        scope = "collection"
        self.collectionTmdbId = collectionTmdbId
        self.name = name
    }
}

public struct DiscoverGenre: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
}

public struct WatchProvider: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let logoUrl: String?
}

public enum DiscoverSort: String, CaseIterable, Sendable {
    case popularity, rating, release, title
    public var title: String {
        switch self {
        case .popularity: return "Most popular"
        case .rating: return "Top rated"
        case .release: return "Newest"
        case .title: return "Title A–Z"
        }
    }
}

public struct DiscoverFilter: Sendable, Hashable {
    public var genre: Int?
    public var year: Int?
    public var minRating: Int?
    public var provider: Int?
    public var sort: DiscoverSort = .popularity
    public init() {}
}

// MARK: - 4K checks

public struct FormatTag: Decodable, Sendable, Hashable {
    public let label: String
    public let kind: String
}

/// `POST /api/v1/discover/check-4k` and `POST /api/v1/library/{id}/check-4k`.
public struct FourKCheckResult: Decodable, Sendable {
    public let dispatched: Bool?
    public let queriedIndexers: Int?
    public let foundUhd: Bool
    public let seasonsSeen: [Int?]?
    public let bestReleaseName: String?
    public let formatTags: [FormatTag]?
    public let message: String?
}

public struct DiscoverCheckFourKBody: Encodable, Sendable {
    public let tmdbId: Int
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let isAnime: Bool
    public init(tmdbId: Int, title: String, kind: MediaKind, year: Int?, isAnime: Bool) {
        self.tmdbId = tmdbId
        self.title = title
        self.kind = kind
        self.year = year
        self.isAnime = isAnime
    }
}

// MARK: - Settings subset (GET /api/v1/settings)

public struct DiscoverSettings: Decodable, Sendable {
    public let metadataProvider: String?
    public let defaultMovieMinimumAvailability: String?
    public let tmdbConfigured: Bool?
    /// The app-wide animations switch (Settings → Appearance).
    public let animationsEnabled: Bool?
}

// MARK: - Preview  (GET /api/v1/discover/preview, /api/v1/preview/{kind}/{id})

/// The preview route's kind: `anime` is its own value here.
public enum PreviewKind: String, Sendable, Hashable {
    case movie, series, anime

    public init(kind: MediaKind, isAnime: Bool) {
        self = isAnime ? .anime : (kind == .movie ? .movie : .series)
    }
}

public struct CastMember: Decodable, Sendable, Hashable {
    public let name: String
    public let character: String?
    public let profileUrl: String?
    public let order: Int?
}

public struct Studio: Decodable, Sendable, Hashable {
    public let name: String
    public let logoUrl: String?
}

public struct SimilarCard: Decodable, Sendable, Hashable, Identifiable {
    public let tmdbId: Int
    public let title: String
    public let year: Int?
    public let posterUrl: String?
    public let kind: MediaKind
    public let inLibrary: Bool
    public var id: String { "\(kind.rawValue)-\(tmdbId)" }
}

public struct PreviewSeason: Decodable, Sendable, Hashable, Identifiable {
    public let seasonNumber: Int
    public let episodeCount: Int
    public var id: Int { seasonNumber }
}

public struct PreviewEpisode: Decodable, Sendable, Hashable {
    public let episodeNumber: Int
    public let title: String?
    public let airDate: String?
    public let overview: String?
}

/// The full `MediaPreviewResult`.
public struct MediaPreviewDetail: Decodable, Sendable, Hashable {
    public let tmdbId: Int
    public let title: String
    public let year: Int?
    public let kind: MediaKind
    public let isAnime: Bool
    public let inLibrary: Bool
    public let libraryItemId: Int?
    public let tvdbId: Int?
    public let imdbId: String?
    public let posterUrl: String?
    public let backdropUrl: String?
    public let overview: String?
    public let runtime: Int?
    public let status: String?
    public let tagline: String?
    public let voteAverage: Double?
    public let voteCount: Int?
    public let certification: String?
    public let genres: [String]?
    public let cast: [CastMember]?
    public let studios: [Studio]?
    public let trailerKey: String?
    public let similar: [SimilarCard]?
    public let seasons: [PreviewSeason]?

    public var asSearchResult: MediaSearchResult {
        MediaSearchResult(tmdbId: tmdbId, title: title, year: year, kind: kind, isAnime: isAnime,
                          overview: overview, inLibrary: inLibrary, libraryItemId: libraryItemId,
                          posterUrl: posterUrl, backdropUrl: backdropUrl, date: nil, voteAverage: voteAverage)
    }
}

extension MediaSearchResult {
    /// Builds a row from another endpoint's shape (trailers, previews), so the
    /// Add sheet and the request modal can take it.
    public static func make(tmdbId: Int, title: String, year: Int?, kind: MediaKind, isAnime: Bool,
                            overview: String?, inLibrary: Bool, libraryItemId: Int?,
                            posterUrl: String?, backdropUrl: String?, date: String?, voteAverage: Double?) -> MediaSearchResult {
        MediaSearchResult(tmdbId: tmdbId, title: title, year: year, kind: kind, isAnime: isAnime,
                          overview: overview, inLibrary: inLibrary, libraryItemId: libraryItemId,
                          posterUrl: posterUrl, backdropUrl: backdropUrl, date: date, voteAverage: voteAverage)
    }

    /// The year, else the first four characters of `date` (web `displayYear`).
    public var displayYear: Int? { year ?? date.flatMap { Int($0.prefix(4)) } }

    public var previewKind: PreviewKind { PreviewKind(kind: kind, isAnime: isAnime) }
}

// MARK: - Requests

public struct EpisodeRef: Codable, Sendable, Hashable {
    public let season: Int
    public let episode: Int
    public init(season: Int, episode: Int) {
        self.season = season
        self.episode = episode
    }
}

/// `GET /api/v1/requests/offerable`.
public struct OfferableEditions: Decodable, Sendable {
    public let editions: [QualityTier]
    public let mode: String
    public let autoEditions: [QualityTier]
    public var isAuto: Bool { mode == "auto" }
}

/// `POST /api/v1/requests` with the multi-edition body the web sends.
public struct RequestCreateBody: Encodable, Sendable {
    public let tmdbId: Int
    public let kind: MediaKind
    public let editions: [QualityTier]
    public let seasons: [Int]
    public let episodes: [EpisodeRef]
    public let note: String?
    public init(tmdbId: Int, kind: MediaKind, editions: [QualityTier], seasons: [Int] = [],
                episodes: [EpisodeRef] = [], note: String? = nil) {
        self.tmdbId = tmdbId
        self.kind = kind
        self.editions = editions
        self.seasons = seasons
        self.episodes = episodes
        self.note = note
    }
}

public struct ApproveEdition: Encodable, Sendable {
    public let tier: QualityTier
    public let rootFolderId: Int?
    public let qualityProfileId: Int?
    public let monitored: Bool
    public init(tier: QualityTier, rootFolderId: Int?, qualityProfileId: Int?, monitored: Bool = true) {
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = monitored
    }
}

public struct ApproveBody: Encodable, Sendable {
    public let editions: [ApproveEdition]
    public let search: Bool
    public init(editions: [ApproveEdition], search: Bool) {
        self.editions = editions
        self.search = search
    }
}

public enum RequestReason: String, CaseIterable, Sendable {
    case notAvailableYet = "not_available_yet"
    case overQuota = "over_quota"
    case notForThisLibrary = "not_for_this_library"
    case other

    public var title: String {
        switch self {
        case .notAvailableYet: return "Not available yet"
        case .overQuota: return "Over quota"
        case .notForThisLibrary: return "Not for this library"
        case .other: return "Other"
        }
    }
}

public struct RejectBody: Encodable, Sendable {
    public let reason: String
    public let defer_: Bool
    public let note: String?
    public init(reason: RequestReason, defer: Bool, note: String?) {
        self.reason = reason.rawValue
        self.defer_ = `defer`
        self.note = note
    }
    enum CodingKeys: String, CodingKey {
        case reason, note
        case defer_ = "defer"
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reason, forKey: .reason)
        try c.encode(defer_, forKey: .defer_)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

// MARK: - Issues  (GET/POST /api/v1/issues)

public enum IssueType: String, CaseIterable, Sendable {
    case playback, video, audio, subtitle, other
    public var title: String {
        switch self {
        case .playback: return "Won't play"
        case .video: return "Video quality"
        case .audio: return "Audio"
        case .subtitle: return "Subtitles"
        case .other: return "Other"
        }
    }
}

public struct MediaIssue: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let mediaItemId: Int
    public let reporterUserId: Int
    public let issueType: String
    public let scope: String
    public let season: Int?
    public let episode: Int?
    public let description: String?
    public let status: String
    public let resolved: Bool?
    public let createdAt: String?
    public let resolvedAt: String?
    public let comment: String?

    public var typeLabel: String { IssueType(rawValue: issueType)?.title ?? issueType.capitalized }

    public var scopeLabel: String {
        switch scope {
        case "season":
            return season == 0 ? "Specials" : "Season \(season ?? 0)"
        case "episode":
            return String(format: "S%02dE%02d", season ?? 0, episode ?? 0)
        default:
            return "Whole title"
        }
    }
}

public struct IssueCreateBody: Encodable, Sendable {
    public let mediaItemId: Int
    public let issueType: String
    public let scope: String
    public let season: Int?
    public let episode: Int?
    public let description: String?
    public init(mediaItemId: Int, issueType: IssueType, scope: String, season: Int?, episode: Int?, description: String?) {
        self.mediaItemId = mediaItemId
        self.issueType = issueType.rawValue
        self.scope = scope
        self.season = season
        self.episode = episode
        self.description = description
    }
}

public struct IssueResolveBody: Encodable, Sendable {
    public let comment: String
    public init(comment: String) { self.comment = comment }
}

// MARK: - Request status helpers

extension MediaRequest {
    /// The web's card-chip priority when a title has several requests.
    public static func priority(_ status: String) -> Int {
        switch status {
        case "pending": return 5
        case "approved": return 4
        case "fulfilled": return 3
        case "deferred": return 2
        case "rejected": return 1
        default: return 0
        }
    }

    /// The requested tiers (`editions`, else the primary `tier`).
    public var tiers: [QualityTier] {
        if let editions, !editions.isEmpty { return editions }
        return [tier]
    }

    public var previewKind: PreviewKind { kind == .movie ? .movie : .series }
}
