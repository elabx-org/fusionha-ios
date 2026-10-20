import Foundation

// MARK: - Adding titles  (POST /api/v1/library)

public struct RootFolder: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let path: String
    /// Bytes free; nil when unreported.
    public var freeSpace: Int64? = nil
    /// False when fusionha can't reach the folder.
    public var accessible: Bool? = nil
}

public struct QualityProfile: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let mediaKind: String?
    public let cutoff: String?
    public let allowedQualities: [String]?
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
