import Foundation

/// `POST /me/request-sources/preview`: the first page of a list or watchlist.
/// 0.4.237 adds the site, the kind, the movie / series mix and the
/// in-library count (MDBList, Trakt and Letterboxd previews alike).
public struct LbSourcePreview: Decodable, Sendable, Hashable {
    public let title: String?
    public let owner: String?
    public let itemCount: Int?
    /// At most 25.
    public let items: [LbPreviewItem]
    /// `MDBLIST`, `TRAKT` or `LETTERBOXD` (nil on an older server).
    public let provider: String?
    /// `list`, `watchlist` or `collection`.
    public let kind: String?
    public let mix: PreviewMix?
    public let inLibraryCount: Int?

    enum CodingKeys: String, CodingKey { case title, owner, itemCount, items, provider, kind, mix, inLibraryCount }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenient(.title)
        owner = c.lenient(.owner)
        itemCount = c.lenient(.itemCount)
        items = c.orDefault(.items, [LbPreviewItem]())
        provider = c.lenient(.provider)
        kind = c.lenient(.kind)
        mix = c.lenient(.mix)
        inLibraryCount = c.lenient(.inLibraryCount)
    }

    /// The site behind it (Letterboxd when unknown, as the web's `providerOf`).
    public var site: SourceProvider { SourceProvider(feed: provider) }
}

/// A preview's movie / series split.
public struct PreviewMix: Decodable, Sendable, Hashable {
    public let movies: Int
    public let series: Int

    public init(movies: Int, series: Int) {
        self.movies = movies
        self.series = series
    }

    enum CodingKeys: String, CodingKey { case movies, series }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        movies = c.orDefault(.movies, 0)
        series = c.orDefault(.series, 0)
    }

    public var total: Int { movies + series }

    /// The movies' share of the bar, 0…1 (0 when empty).
    public var movieShare: Double { total == 0 ? 0 : Double(movies) / Double(total) }
}

public struct LbPreviewItem: Decodable, Sendable, Hashable {
    public let title: String
    public let year: Int?
    public let inLibrary: Bool
    /// 0.4.237: `movie` or `series`, the TMDB id and a poster (nil when unmatched).
    public let kind: String?
    public let tmdbId: Int?
    public let posterUrl: String?

    enum CodingKeys: String, CodingKey { case title, year, inLibrary, kind, tmdbId, posterUrl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.orDefault(.title, "")
        year = c.lenient(.year)
        inLibrary = c.orDefault(.inLibrary, false)
        kind = c.lenient(.kind)
        tmdbId = c.lenient(.tmdbId)
        posterUrl = c.lenient(.posterUrl)
    }
}
