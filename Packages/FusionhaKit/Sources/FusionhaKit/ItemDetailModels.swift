import Foundation

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
    /// The title's versions. fusionha 0.4.122 renamed `editions` to `versions`
    /// (the old key is deprecated, removed no earlier than 0.5.0): either decodes.
    public var editions: [DetailEdition] { versions ?? legacyEditions ?? [] }
    private let versions: [DetailEdition]?
    private let legacyEditions: [DetailEdition]?
    public let seasons: [Season]?
    public let history: [HistoryEntry]?
    // Detail page extras (all optional so an older server still decodes).
    public let tmdbId: Int?
    public let seriesType: String?
    public let metadataProvider: String?
    public let resolvedMetadataProvider: String?
    public let episodeNumberingSource: String?
    public let numberingMismatch: Bool?
    public let releaseDate: String?
    public let inCinemas: String?
    public let digitalRelease: String?
    public let physicalRelease: String?
    public let releaseWindows: [ReleaseWindow]?
    public let cast: [CastMember]?
    public let similar: [SimilarTitle]?
    public let trailerKey: String?
    public let collection: CollectionRef?
    public let tags: [ItemTag]?

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, year, isAnime, overview, runtime, status, tagline, voteAverage
        case certification, genres, posterUrl, backdropUrl, monitored
        case versions
        case legacyEditions = "editions"
        case seasons, history, tmdbId, seriesType, metadataProvider, resolvedMetadataProvider
        case episodeNumberingSource, numberingMismatch, releaseDate, inCinemas, digitalRelease
        case physicalRelease, releaseWindows, cast, similar, trailerKey, collection, tags
    }
}

public struct DetailEdition: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let tier: QualityTier
    /// The edition (cut) name; nil or empty = Standard. Sent as `edition` since
    /// 0.4.122 and as the deprecated `movie_edition` before: either decodes.
    public var movieEdition: String? { edition ?? legacyMovieEdition }
    private let edition: String?
    private let legacyMovieEdition: String?
    public let monitored: Bool
    public let rootFolderId: Int?
    public let fullPath: String?
    public let qualityProfileId: Int?
    public let downloadState: String?
    public let movieFile: MovieFile?
    public let progress: Double?
    public let monitor: String?
    public let folderName: String?
    public let needsEditionFolder: Bool?
    public let minimumAvailability: String?
    public let releaseTitle: String?
    public let client: String?
    public let indexer: String?
    public let grabbable: Bool?
    public let availableFrom: String?
    public let availableStage: String?
    public let unresolvedFileCount: Int?
    public let missingFileCount: Int?
    public let hasUnresolvedLinks: Bool?
    public let attentionKind: String?
    public let attentionMessage: String?

    private enum CodingKeys: String, CodingKey {
        case id, tier, edition
        case legacyMovieEdition = "movieEdition"
        case monitored, rootFolderId, fullPath, qualityProfileId, downloadState, movieFile, progress
        case monitor, folderName, needsEditionFolder, minimumAvailability, releaseTitle, client, indexer
        case grabbable, availableFrom, availableStage, unresolvedFileCount, missingFileCount
        case hasUnresolvedLinks, attentionKind, attentionMessage
    }
}

public struct MovieFile: Decodable, Sendable, Hashable {
    public let id: Int
    public let relativePath: String?
    public let size: Double?
    public let quality: String?
    public let releaseGroup: String?
    public let cfScore: Int?
    public let mediaInfo: MediaInfo?
    public let customFormats: [String]?
    public let languages: [String]?
    public let releaseType: String?
    public let sceneName: String?
    public let linkUnresolved: Bool?
    public let unresolved: Bool?
    public let analysis: String?
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
    public let overview: String?
    public let airDatetime: String?
    /// Minutes, from the metadata provider.
    public let runtime: Int?
}

public struct EpisodeDownload: Decodable, Sendable, Hashable {
    /// `version_id` since 0.4.122, `edition_id` before: either decodes.
    public var editionId: Int? { versionId ?? legacyEditionId }
    private let versionId: Int?
    private let legacyEditionId: Int?
    public let state: String?
    public let progress: Double?
    public let tier: QualityTier?
    public let releaseTitle: String?
    public let releaseQuality: String?
    public let client: String?
    public let indexer: String?

    private enum CodingKeys: String, CodingKey {
        case versionId
        case legacyEditionId = "editionId"
        case state, progress, tier, releaseTitle, releaseQuality, client, indexer
    }
}

public struct EpisodeFile: Decodable, Sendable, Hashable {
    /// `version_id` since 0.4.122, `edition_id` before: either decodes.
    public var editionId: Int? { versionId ?? legacyEditionId }
    private let versionId: Int?
    private let legacyEditionId: Int?
    public let tier: QualityTier?
    public let file: MovieFile?

    private enum CodingKeys: String, CodingKey {
        case versionId
        case legacyEditionId = "editionId"
        case tier, file
    }
}
