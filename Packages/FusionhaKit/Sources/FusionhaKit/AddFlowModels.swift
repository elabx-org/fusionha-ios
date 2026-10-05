import Foundation

// Add title v2 (fusionha 0.4.127–0.4.139): the wire shapes the configure step
// reads and sends. Every decoded field is optional so an older or newer server
// never breaks the sheet.

// MARK: - Preview  (GET /api/v1/discover/preview, GET /api/v1/preview/tvdb/{tvdb_id})

/// One `PreviewSeason` with the Add v2 air counts. `airedCount` is nil when the
/// server could not establish it (or predates 0.4.127): the date-driven monitor
/// modes then show "exact count after adding".
public struct AddPreviewSeason: Decodable, Sendable, Hashable {
    public let seasonNumber: Int
    public let episodeCount: Int
    public let airedCount: Int?
    public let recentCount: Int?

    public init(seasonNumber: Int, episodeCount: Int, airedCount: Int?, recentCount: Int?) {
        self.seasonNumber = seasonNumber
        self.episodeCount = episodeCount
        self.airedCount = airedCount
        self.recentCount = recentCount
    }
}

/// `PreviewReleaseEstimate`: when a movie counts as "Released" for the grab gate.
public struct AddReleaseEstimate: Decodable, Sendable, Hashable {
    public let date: String?
    public let stage: String?
    public let estimated: Bool?
}

/// `MediaPreviewResult` as the Add flow reads it. `tmdbId` is nil only on the
/// TVDB-only preview.
public struct AddPreview: Decodable, Sendable, Hashable {
    public let tmdbId: Int?
    public let title: String?
    public let year: Int?
    public let kind: String?
    public let isAnime: Bool?
    public let inLibrary: Bool?
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
    public let certification: String?
    public let genres: [String]?
    public let seasons: [AddPreviewSeason]?
    public let releaseDate: String?
    public let inCinemas: String?
    public let digitalRelease: String?
    public let physicalRelease: String?
    public let releaseEstimate: AddReleaseEstimate?
    public let nextAirDate: String?

    private enum CodingKeys: String, CodingKey {
        case tmdbId, title, year, kind, isAnime, inLibrary, libraryItemId, tvdbId, imdbId, posterUrl, backdropUrl
        case overview, runtime, status, tagline, voteAverage, certification, genres, seasons
        case releaseDate, inCinemas, digitalRelease, physicalRelease, releaseEstimate, nextAirDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tmdbId = try? c.decodeIfPresent(Int.self, forKey: .tmdbId)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        year = try? c.decodeIfPresent(Int.self, forKey: .year)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        isAnime = try? c.decodeIfPresent(Bool.self, forKey: .isAnime)
        inLibrary = try? c.decodeIfPresent(Bool.self, forKey: .inLibrary)
        libraryItemId = try? c.decodeIfPresent(Int.self, forKey: .libraryItemId)
        tvdbId = try? c.decodeIfPresent(Int.self, forKey: .tvdbId)
        imdbId = try? c.decodeIfPresent(String.self, forKey: .imdbId)
        posterUrl = try? c.decodeIfPresent(String.self, forKey: .posterUrl)
        backdropUrl = try? c.decodeIfPresent(String.self, forKey: .backdropUrl)
        overview = try? c.decodeIfPresent(String.self, forKey: .overview)
        if let minutes = try? c.decodeIfPresent(Int.self, forKey: .runtime) {
            runtime = minutes
        } else {
            runtime = (try? c.decodeIfPresent(Double.self, forKey: .runtime)).map { Int($0.rounded()) }
        }
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        tagline = try? c.decodeIfPresent(String.self, forKey: .tagline)
        voteAverage = try? c.decodeIfPresent(Double.self, forKey: .voteAverage)
        certification = try? c.decodeIfPresent(String.self, forKey: .certification)
        genres = try? c.decodeIfPresent([String].self, forKey: .genres)
        seasons = try? c.decodeIfPresent([AddPreviewSeason].self, forKey: .seasons)
        releaseDate = try? c.decodeIfPresent(String.self, forKey: .releaseDate)
        inCinemas = try? c.decodeIfPresent(String.self, forKey: .inCinemas)
        digitalRelease = try? c.decodeIfPresent(String.self, forKey: .digitalRelease)
        physicalRelease = try? c.decodeIfPresent(String.self, forKey: .physicalRelease)
        releaseEstimate = try? c.decodeIfPresent(AddReleaseEstimate.self, forKey: .releaseEstimate)
        nextAirDate = try? c.decodeIfPresent(String.self, forKey: .nextAirDate)
    }

    /// The fields the "When to grab it" rail reads.
    public var timelineDates: TimelineDates {
        TimelineDates(releaseDate: releaseDate, inCinemas: inCinemas, digitalRelease: digitalRelease,
                      physicalRelease: physicalRelease, estimateDate: releaseEstimate?.date,
                      estimateIsEstimated: releaseEstimate?.estimated ?? false)
    }
}

// MARK: - Use last settings  (GET /api/v1/library/last-added?kind&anime)

public struct LastAddedVersion: Decodable, Sendable, Hashable {
    public let tier: QualityTier
    public let rootFolderId: Int?
    public let qualityProfileId: Int?
}

/// `LastAddedRead`: the settings the latest add of a kind was made with.
public struct LastAdded: Decodable, Sendable, Hashable {
    public let itemId: Int?
    public let title: String?
    public let versions: [LastAddedVersion]
    public let monitor: String?
    public let minimumAvailability: String?
    public let seriesType: String?

    private enum CodingKeys: String, CodingKey {
        case itemId, title, versions, monitor, minimumAvailability, seriesType
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try? c.decodeIfPresent(Int.self, forKey: .itemId)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        // A tier this client doesn't know is skipped rather than failing the row.
        let raw = (try? c.decodeIfPresent([LossyLastAddedVersion].self, forKey: .versions)) ?? []
        versions = raw.compactMap(\.value)
        monitor = try? c.decodeIfPresent(String.self, forKey: .monitor)
        minimumAvailability = try? c.decodeIfPresent(String.self, forKey: .minimumAvailability)
        seriesType = try? c.decodeIfPresent(String.self, forKey: .seriesType)
    }
}

private struct LossyLastAddedVersion: Decodable {
    let value: LastAddedVersion?
    init(from decoder: Decoder) throws {
        value = try? LastAddedVersion(from: decoder)
    }
}

// MARK: - Settings the Add sheet reads  (GET /api/v1/settings)

public struct AddSettings: Decodable, Sendable {
    public let metadataProvider: String?
    public let defaultMovieMinimumAvailability: String?
    public let tmdbConfigured: Bool?
    public let tvdbConfigured: Bool?
}

// MARK: - Add request  (POST /api/v1/library)

/// One season of the season-slider rule: monitor `seasonNumber` from episode
/// NUMBER `fromEpisode` on; nil monitors none of it (sent as `null`).
public struct SeasonStart: Encodable, Sendable, Hashable {
    public let seasonNumber: Int
    public let fromEpisode: Int?

    public init(seasonNumber: Int, fromEpisode: Int?) {
        self.seasonNumber = seasonNumber
        self.fromEpisode = fromEpisode
    }

    private enum CodingKeys: String, CodingKey { case seasonNumber, fromEpisode }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seasonNumber, forKey: .seasonNumber)
        if let fromEpisode {
            try c.encode(fromEpisode, forKey: .fromEpisode)
        } else {
            try c.encodeNil(forKey: .fromEpisode)
        }
    }
}

/// `VersionCreate`. `edition` is sent only when it is not Standard; `monitor`
/// only when it overrides the master; `folderName` only when edited.
public struct AddVersionBody: Encodable, Sendable, Hashable {
    public let tier: QualityTier
    public let edition: String?
    public let rootFolderId: Int
    public let qualityProfileId: Int
    public let monitored: Bool
    public let monitor: String?
    public let folderName: String?

    public init(tier: QualityTier, edition: String?, rootFolderId: Int, qualityProfileId: Int,
                monitor: String?, folderName: String?) {
        self.tier = tier
        self.edition = edition
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = true
        self.monitor = monitor
        self.folderName = folderName
    }
}

/// `LibraryAddRequest` (0.4.122+ speaks `versions`; nil fields are omitted).
public struct AddTitleBody: Encodable, Sendable {
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let tmdbId: Int?
    public let tvdbId: Int?
    public let isAnime: Bool
    public let versions: [AddVersionBody]
    public let searchNow: Bool
    public let monitor: String
    public let minimumAvailability: String?
    public let seriesType: String?
    public let metadataProvider: String?
    public let seasonMonitorFrom: [SeasonStart]?

    public init(title: String, kind: MediaKind, year: Int?, tmdbId: Int?, tvdbId: Int?, isAnime: Bool,
                versions: [AddVersionBody], searchNow: Bool, monitor: String, minimumAvailability: String?,
                seriesType: String?, metadataProvider: String?, seasonMonitorFrom: [SeasonStart]?) {
        self.title = title
        self.kind = kind
        self.year = year
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
        self.isAnime = isAnime
        self.versions = versions
        self.searchNow = searchNow
        self.monitor = monitor
        self.minimumAvailability = minimumAvailability
        self.seriesType = seriesType
        self.metadataProvider = metadataProvider
        self.seasonMonitorFrom = seasonMonitorFrom
    }
}

/// `POST /api/v1/library`'s reply as the Add flow reads it.
public struct AddedTitle: Decodable, Sendable {
    public let id: Int
    public let kind: String?
}

/// `DiscoverCheckFourKRequest`: a TMDB pick sends `tmdbId`, a TVDB-only pick
/// `tvdbId` (the server matches on either).
public struct AddFourKCheckBody: Encodable, Sendable {
    public let tmdbId: Int?
    public let tvdbId: Int?
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let isAnime: Bool

    public init(tmdbId: Int?, tvdbId: Int?, title: String, kind: MediaKind, year: Int?, isAnime: Bool) {
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
        self.title = title
        self.kind = kind
        self.year = year
        self.isAnime = isAnime
    }
}
