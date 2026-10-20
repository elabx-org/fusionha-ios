import Foundation

// Preview models (field names follow the backend schemas, `api/schemas.py`,
// decoded with `.convertFromSnakeCase`).

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
