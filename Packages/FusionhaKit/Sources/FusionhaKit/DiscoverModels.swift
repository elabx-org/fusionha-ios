import Foundation

// Models for Discover (Preview, Requests and Issues live in DiscoverPreviewModels.swift
// and RequestIssueModels.swift).
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

    public init(collectionTmdbId: Int, name: String, posterUrl: String? = nil, backdropUrl: String? = nil,
                ownedCount: Int = 0, totalCount: Int = 0) {
        self.collectionTmdbId = collectionTmdbId
        self.name = name
        self.posterUrl = posterUrl
        self.backdropUrl = backdropUrl
        self.ownedCount = ownedCount
        self.totalCount = totalCount
    }
}

/// `GET /api/v1/collections/{id}`.
public struct CollectionDetail: Decodable, Sendable {
    public let collectionTmdbId: Int
    public let name: String
    public let posterUrl: String?
    public let ownedCount: Int
    /// Owned parts that also have a file on disk (the green-check subset).
    public let presentCount: Int?
    public let totalCount: Int
    public let parts: [CollectionPart]

    public init(collectionTmdbId: Int, name: String, posterUrl: String? = nil, ownedCount: Int,
                presentCount: Int? = nil, totalCount: Int, parts: [CollectionPart]) {
        self.collectionTmdbId = collectionTmdbId
        self.name = name
        self.posterUrl = posterUrl
        self.ownedCount = ownedCount
        self.presentCount = presentCount
        self.totalCount = totalCount
        self.parts = parts
    }
}

/// One film of a collection (`CollectionPartRead`). Three-state ownership:
/// not `owned` → not in fusionha; `owned` without `hasFile` → tracked, no file
/// yet; `owned` with `hasFile` → on disk.
public struct CollectionPart: Decodable, Sendable, Hashable {
    public let tmdbId: Int
    public let title: String?
    public let year: Int?
    public let posterUrl: String?
    public let owned: Bool?
    public let hasFile: Bool?
    public let libraryItemId: Int?
    public let tiers: [QualityTier]?
    public let ignored: Bool?

    public init(tmdbId: Int, title: String? = nil, year: Int? = nil, posterUrl: String? = nil, owned: Bool? = nil,
                hasFile: Bool? = nil, libraryItemId: Int? = nil, tiers: [QualityTier]? = nil, ignored: Bool? = nil) {
        self.tmdbId = tmdbId
        self.title = title
        self.year = year
        self.posterUrl = posterUrl
        self.owned = owned
        self.hasFile = hasFile
        self.libraryItemId = libraryItemId
        self.tiers = tiers
        self.ignored = ignored
    }

    /// The film is in the library (with or without a file).
    public var inLibrary: Bool? { owned }
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
