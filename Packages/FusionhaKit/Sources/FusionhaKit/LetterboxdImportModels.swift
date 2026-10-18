import Foundation

// MARK: - Letterboxd one-time import (CSV or ZIP export) and the Discover rail

/// `POST /me/letterboxd/watchlist-csv/preview` (202): matching has started.
public struct CsvPreviewStarted: Decodable, Sendable, Hashable {
    public let previewToken: String
    public let status: String?
    public let total: Int?
    public let done: Int?
}

/// `GET /me/letterboxd/watchlist-csv/preview/{token}`: `MATCHING` with progress,
/// `READY` with counts and rows, or `FAILED` with `error` (`expired`, `no_tmdb`).
public struct CsvPreviewRead: Decodable, Sendable, Hashable {
    public let status: String
    public let total: Int
    public let done: Int
    public let counts: CsvCounts?
    public let rows: [CsvRow]
    public let lowConfidence: [CsvRow]
    public let error: String?

    enum CodingKeys: String, CodingKey { case status, total, done, counts, rows, lowConfidence, error }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.orDefault(.status, "MATCHING")
        total = c.orDefault(.total, 0)
        done = c.orDefault(.done, 0)
        counts = c.lenient(.counts)
        rows = c.orDefault(.rows, [CsvRow]())
        lowConfidence = c.orDefault(.lowConfidence, [CsvRow]())
        error = c.lenient(.error)
    }
}

public struct CsvCounts: Decodable, Sendable, Hashable {
    public let matched: Int
    public let lowConfidence: Int
    public let unmatched: Int
    public let alreadyHave: Int

    enum CodingKeys: String, CodingKey { case matched, lowConfidence, unmatched, alreadyHave }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        matched = c.orDefault(.matched, 0)
        lowConfidence = c.orDefault(.lowConfidence, 0)
        unmatched = c.orDefault(.unmatched, 0)
        alreadyHave = c.orDefault(.alreadyHave, 0)
    }
}

/// One CSV row and its TMDB match. `confidence` ∈ `HIGH`, `LOW`, `NONE`, `HAVE`.
public struct CsvRow: Decodable, Sendable, Hashable, Identifiable {
    public let key: String
    public let name: String
    public let year: Int?
    public let date: String?
    public let tmdbId: Int?
    public let matchedTitle: String?
    public let matchedYear: Int?
    public let confidence: String
    public let poster: String?

    public var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, name, year, date, tmdbId, matchedTitle, matchedYear, confidence, poster
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.orDefault(.key, UUID().uuidString)
        name = c.orDefault(.name, "")
        year = c.lenient(.year)
        date = c.lenient(.date)
        tmdbId = c.lenient(.tmdbId)
        matchedTitle = c.lenient(.matchedTitle)
        matchedYear = c.lenient(.matchedYear)
        confidence = c.orDefault(.confidence, "NONE")
        poster = c.lenient(.poster)
    }
}

/// `POST /me/letterboxd/watchlist-csv/commit`.
public struct CsvCommitResult: Decodable, Sendable, Hashable {
    public let requested: Int
    public let wishlisted: Int
    public let joined: Int
    public let skipped: Int

    enum CodingKeys: String, CodingKey { case requested, wishlisted, joined, skipped }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requested = c.orDefault(.requested, 0)
        wishlisted = c.orDefault(.wishlisted, 0)
        joined = c.orDefault(.joined, 0)
        skipped = c.orDefault(.skipped, 0)
    }
}

// MARK: Discover "From your Letterboxd"

/// `GET /api/v1/me/suggestions[?source_id=]`.
public struct SuggestionsRead: Decodable, Sendable, Hashable {
    public let items: [Suggestion]
    public let sources: [SuggestionSource]
    /// False for anyone without a connected profile or a linked source.
    public let visible: Bool

    enum CodingKeys: String, CodingKey { case items, sources, visible }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = c.orDefault(.items, [Suggestion]())
        sources = c.orDefault(.sources, [SuggestionSource]())
        visible = c.orDefault(.visible, false)
    }
}

public struct Suggestion: Decodable, Sendable, Hashable, Identifiable {
    public let tmdbId: Int
    /// `movie` or `series`.
    public let kind: String
    public let title: String
    public let year: Int?
    /// An image URL, or nil.
    public let poster: String?
    public let sourceId: Int?
    public let sourceLabel: String?
    public let owner: String?
    /// Other people's open requests for the title ("Me too").
    public let askedCount: Int
    /// From a source whose last check failed.
    public let stale: Bool

    public var id: String { "\(kind)-\(tmdbId)" }

    enum CodingKeys: String, CodingKey {
        case tmdbId, kind, title, year, poster, sourceId, sourceLabel, owner, askedCount, stale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try c.decode(Int.self, forKey: .tmdbId)
        kind = c.orDefault(.kind, "movie")
        title = c.orDefault(.title, "")
        year = c.lenient(.year)
        poster = c.lenient(.poster)
        sourceId = c.lenient(.sourceId)
        sourceLabel = c.lenient(.sourceLabel)
        owner = c.lenient(.owner)
        askedCount = c.orDefault(.askedCount, 0)
        stale = c.orDefault(.stale, false)
    }

    /// The Discover card's row (`toPick` on the web).
    public var searchResult: MediaSearchResult {
        MediaSearchResult.make(tmdbId: tmdbId, title: title, year: year, kind: kind == "series" ? .series : .movie,
                               isAnime: false, overview: nil, inLibrary: false, libraryItemId: nil,
                               posterUrl: poster, backdropUrl: nil, date: nil, voteAverage: nil)
    }
}

public struct SuggestionSource: Decodable, Sendable, Hashable, Identifiable {
    public let sourceId: Int
    public let label: String
    public let owner: String?
    public let count: Int

    public var id: Int { sourceId }

    enum CodingKeys: String, CodingKey { case sourceId, label, owner, count }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = try c.decode(Int.self, forKey: .sourceId)
        label = c.orDefault(.label, "")
        owner = c.lenient(.owner)
        count = c.orDefault(.count, 0)
    }
}
