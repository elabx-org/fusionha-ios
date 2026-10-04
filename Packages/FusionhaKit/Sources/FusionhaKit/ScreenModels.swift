import Foundation

// MARK: - Coverage rail (the web's PosterCard / CoverageRail logic)

/// One edition's lifecycle on a poster card, derived exactly like the web's
/// `editionChipState` + `toChipEdition` (routes/library-mapping.ts).
public enum RailState: String, Sendable {
    case owned, partial, wanted, downloading, upgrading, upcoming
}

public struct Rail: Sendable, Hashable {
    public let state: RailState
    /// 0...100, the fill width.
    public let progress: Int
    /// `have/total` for series, nil for a single-file movie.
    public let fraction: String?
    /// The edition has not-found or dead-link files (amber/orange warning).
    public let attention: Bool
    public let deadLinkOnly: Bool
}

extension Edition {
    public func rail(isSeries: Bool) -> Rail {
        let have = self.have ?? 0
        let total = self.total ?? 0
        let state: RailState
        if status == .upgrading {
            state = .upgrading
        } else if status == .downloading {
            state = .downloading
        } else if isSeries, total > 0 {
            state = have >= total ? .owned : (have > 0 ? .partial : .wanted)
        } else {
            state = have > 0 ? .owned : (availableFrom != nil ? .upcoming : .wanted)
        }
        let progress: Int
        switch state {
        case .owned: progress = 100
        case .upcoming: progress = 0
        default: progress = total > 0 ? Int((Double(have) / Double(total) * 100).rounded()) : (have > 0 ? 100 : 0)
        }
        let unresolved = unresolvedFileCount ?? 0
        let dead = deadLinkCount ?? 0
        let attention = (self.attention ?? false) || unresolved > 0
        return Rail(
            state: state,
            progress: progress,
            fraction: isSeries ? "\(have)/\(total)" : nil,
            attention: attention,
            deadLinkOnly: attention && dead > 0 && dead == unresolved)
    }
}

extension MediaItem {
    /// The web's kind buckets: anime wins over movie/series.
    public var kindBucket: KindBucket {
        if isAnime == true { return .anime }
        return kind == .movie ? .movie : .series
    }
}

public enum KindBucket: String, CaseIterable, Sendable {
    case movie, series, anime
    public var plural: String {
        switch self {
        case .movie: return "Movies"
        case .series: return "Series"
        case .anime: return "Anime"
        }
    }
}

// MARK: - Current user  (GET /api/v1/auth/me)

public struct Me: Decodable, Sendable {
    public let id: Int
    public let username: String
    public let isAdmin: Bool
    public let roleName: String?
    public let permissions: [String]?
    public let capabilities: [String]?
    /// Requester accounts get the web's reduced nav (Discover, My requests, You).
    public let requestScoped: Bool?
    public let thumb: String?

    public var initials: String {
        let parts = username.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" })
        let letters = parts.count >= 2 ? parts.prefix(2).compactMap(\.first) : Array(username.prefix(2))
        return String(letters).uppercased()
    }

    public var roleLabel: String {
        isAdmin ? "Administrator" : (roleName ?? "User")
    }

    public func can(_ capability: String) -> Bool {
        isAdmin || (capabilities ?? []).contains(capability)
    }
}

// MARK: - Item detail  (GET /api/v1/library/{id})

public struct ItemDetail: Decodable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let isAnime: Bool?
    public let overview: String?
    public let runtime: Int?
    public let status: String?
    public let tagline: String?
    public let voteAverage: Double?
    public let certification: String?
    public let genres: [String]?
    public let posterUrl: String?
    public let backdropUrl: String?
    public let monitored: Bool?
    public let editions: [DetailEdition]
    public let seasons: [Season]?
    public let history: [HistoryEntry]?
}

public struct DetailEdition: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let tier: QualityTier
    public let movieEdition: String?
    public let monitored: Bool
    public let rootFolderId: Int?
    public let fullPath: String?
    public let qualityProfileId: Int?
    public let downloadState: String?
    public let movieFile: MovieFile?
    public let progress: Double?
}

public struct MovieFile: Decodable, Sendable, Hashable {
    public let id: Int
    public let relativePath: String?
    public let size: Double?
    public let quality: String?
    public let releaseGroup: String?
    public let cfScore: Int?
}

public struct Season: Decodable, Sendable, Hashable, Identifiable {
    public let seasonNumber: Int
    public let monitored: Bool?
    public let episodes: [Episode]
    public var id: Int { seasonNumber }
}

public struct Episode: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let episodeNumber: Int
    public let absoluteNumber: Int?
    public let title: String?
    public let airDate: String?
    public let monitored: Bool?
    public let files: [EpisodeFile]?
    public let downloadStates: [EpisodeDownload]?
}

public struct EpisodeDownload: Decodable, Sendable, Hashable {
    public let editionId: Int?
    public let state: String?
    public let progress: Double?
}

public struct EpisodeFile: Decodable, Sendable, Hashable {
    public let editionId: Int?
    public let tier: QualityTier?
    public let file: MovieFile?
}

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

    public var code: String { String(format: "S%02dE%02d", seasonNumber, episodeNumber) }
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
    public let downloadId: Int?
    public let grabTrigger: String?
    public let `protocol`: String?
    public let blocklistable: Bool?

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

// MARK: - Adding titles  (POST /api/v1/library)

public struct RootFolder: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let path: String
}

public struct QualityProfile: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let mediaKind: String?
}

public struct AddDefaultSlot: Decodable, Sendable, Hashable {
    public let profileKind: String
    public let tier: QualityTier
    public let qualityProfileId: Int?
    public let rootFolderId: Int?
}

public struct EditionCreate: Encodable, Sendable {
    public let tier: QualityTier
    public let rootFolderId: Int
    public let qualityProfileId: Int
    public let monitored: Bool
    public init(tier: QualityTier, rootFolderId: Int, qualityProfileId: Int, monitored: Bool = true) {
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = monitored
    }
}

public struct LibraryAddRequest: Encodable, Sendable {
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let tmdbId: Int
    public let isAnime: Bool
    public let editions: [EditionCreate]
    public let searchNow: Bool
    public init(result: MediaSearchResult, editions: [EditionCreate], searchNow: Bool) {
        title = result.title
        kind = result.kind
        year = result.year
        tmdbId = result.tmdbId
        isAnime = result.isAnime
        self.editions = editions
        self.searchNow = searchNow
    }
}

public struct AddedItem: Decodable, Sendable {
    public let id: Int
}

// MARK: - TMDB preview  (GET /api/v1/preview/{kind}/{tmdb_id})

public struct MediaPreview: Decodable, Sendable, Hashable {
    public let tmdbId: Int
    public let title: String
    public let year: Int?
    public let kind: MediaKind
    public let isAnime: Bool?
    public let inLibrary: Bool?
    public let libraryItemId: Int?
    public let posterUrl: String?
    public let overview: String?
}
