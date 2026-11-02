import Foundation

// Admin import lists (fusionha 0.4.237, requests phase 10b slice 3): public
// MDBList / Trakt / Letterboxd lists whose titles are added straight to the
// library on a schedule. No requests, no quota. Same shapes as the web's
// `lib/api/import-lists.ts` and `import-list-ledger.ts`.

/// `media_kind`: anime adds both the movies and the series on the list.
public enum ImportListMediaKind: String, Sendable, Hashable, CaseIterable {
    case movie, series, anime
}

/// One version a list creates per title: its tier, and a root folder and
/// quality profile (nil = from Default Profiles).
public struct ImportListVersion: Decodable, Sendable, Hashable {
    public var tier: QualityTier
    public var rootFolderId: Int?
    public var qualityProfileId: Int?

    public init(tier: QualityTier, rootFolderId: Int? = nil, qualityProfileId: Int? = nil) {
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
    }

    enum CodingKeys: String, CodingKey { case tier, rootFolderId, qualityProfileId }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tier = ImportListVersion.tier(c.orDefault(.tier, "HD_1080P"))
        rootFolderId = c.lenient(.rootFolderId)
        qualityProfileId = c.lenient(.qualityProfileId)
    }

    /// The wire tier (`HD_1080P` / `UHD_2160P`).
    public var wireTier: String { tier == .uhd ? "UHD_2160P" : "HD_1080P" }

    static func tier(_ wire: String) -> QualityTier { wire == "UHD_2160P" ? .uhd : .hd }

    /// The request body entry (keys snake_case, nulls kept).
    public var body: SettingsJSON {
        .object(["tier": .string(wireTier),
                 "root_folder_id": rootFolderId.map { .int($0) } ?? .null,
                 "quality_profile_id": qualityProfileId.map { .int($0) } ?? .null])
    }
}

/// What one pass did (`ImportListRunCounts`).
public struct ImportListRunCounts: Decodable, Sendable, Hashable {
    public var added = 0, owned = 0, excluded = 0, unmatched = 0, skippedKind = 0, queued = 0

    public init() {}

    enum CodingKeys: String, CodingKey { case added, owned, excluded, unmatched, skippedKind, queued }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        added = c.orDefault(.added, 0)
        owned = c.orDefault(.owned, 0)
        excluded = c.orDefault(.excluded, 0)
        unmatched = c.orDefault(.unmatched, 0)
        skippedKind = c.orDefault(.skippedKind, 0)
        queued = c.orDefault(.queued, 0)
    }

    public var total: Int { added + owned + excluded + unmatched + skippedKind + queued }
}

/// `GET /import-lists/{id}/runs` rows (newest first, the last 30).
public struct ImportListRun: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let listId: Int
    public let startedAt: String
    public let finishedAt: String?
    public let counts: ImportListRunCounts
    public let error: String?

    enum CodingKeys: String, CodingKey { case id, listId, startedAt, finishedAt, counts, error }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        listId = c.orDefault(.listId, 0)
        startedAt = c.orDefault(.startedAt, "")
        finishedAt = c.lenient(.finishedAt)
        counts = c.orDefault(.counts, ImportListRunCounts())
        error = c.lenient(.error)
    }
}

/// `GET/POST /api/v1/import-lists` (`ImportListRead`).
public struct ImportList: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    /// `MDBLIST`, `TRAKT` or `LETTERBOXD`.
    public let provider: String
    public let url: String
    public let owner: String?
    public let listKind: String?
    public let mediaKind: ImportListMediaKind
    public let versions: [ImportListVersion]
    public let monitored: Bool
    public let searchOnAdd: Bool
    public let intervalHours: Int
    public let enabled: Bool
    /// `PENDING`, `OK`, `DEGRADED`, `PRIVATE`, `ERROR`, `UNAVAILABLE` (and `BLOCKED`).
    public let status: String
    public let lastError: String?
    public let itemCount: Int?
    public let addedCount: Int
    public let unmatchedCount: Int
    public let queuedCount: Int
    public let lastCheckedAt: String?
    public let nextCheckAt: String?
    /// Set while a Sync now waits for the job.
    public let syncRequestedAt: String?
    public let lastRun: ImportListRun?

    enum CodingKeys: String, CodingKey {
        case id, name, provider, url, owner, listKind, mediaKind, versions, monitored, searchOnAdd, intervalHours
        case enabled, status, lastError, itemCount, addedCount, unmatchedCount, queuedCount, lastCheckedAt
        case nextCheckAt, syncRequestedAt, lastRun
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.orDefault(.name, "Import list")
        provider = c.orDefault(.provider, "MDBLIST")
        url = c.orDefault(.url, "")
        owner = c.lenient(.owner)
        listKind = c.lenient(.listKind)
        mediaKind = ImportListMediaKind(rawValue: c.orDefault(.mediaKind, "movie")) ?? .movie
        versions = c.orDefault(.versions, [ImportListVersion]())
        monitored = c.orDefault(.monitored, true)
        searchOnAdd = c.orDefault(.searchOnAdd, false)
        intervalHours = c.orDefault(.intervalHours, 6)
        enabled = c.orDefault(.enabled, true)
        status = c.orDefault(.status, "PENDING")
        lastError = c.lenient(.lastError)
        itemCount = c.lenient(.itemCount)
        addedCount = c.orDefault(.addedCount, 0)
        unmatchedCount = c.orDefault(.unmatchedCount, 0)
        queuedCount = c.orDefault(.queuedCount, 0)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        nextCheckAt = c.lenient(.nextCheckAt)
        syncRequestedAt = c.lenient(.syncRequestedAt)
        lastRun = c.lenient(.lastRun)
    }

    public var site: SourceProvider { SourceProvider(feed: provider) }
    public func version(_ tier: QualityTier) -> ImportListVersion? { versions.first { $0.tier == tier } }
}

/// `POST /import-lists/preview`: what a save would do. Nothing is written.
public struct ImportListPreview: Decodable, Sendable, Hashable {
    public let provider: String
    public let kind: String?
    public let title: String?
    public let owner: String?
    public let itemCount: Int?
    public let mix: PreviewMix
    public let inLibraryCount: Int
    public let excludedCount: Int
    public let wouldAdd: Int
    public let firstSyncAdds: Int
    /// At most 25.
    public let items: [ImportListPreviewItem]

    enum CodingKeys: String, CodingKey {
        case provider, kind, title, owner, itemCount, mix, inLibraryCount, excludedCount, wouldAdd, firstSyncAdds, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = c.orDefault(.provider, "MDBLIST")
        kind = c.lenient(.kind)
        title = c.lenient(.title)
        owner = c.lenient(.owner)
        itemCount = c.lenient(.itemCount)
        mix = c.orDefault(.mix, PreviewMix(movies: 0, series: 0))
        inLibraryCount = c.orDefault(.inLibraryCount, 0)
        excludedCount = c.orDefault(.excludedCount, 0)
        wouldAdd = c.orDefault(.wouldAdd, 0)
        firstSyncAdds = c.orDefault(.firstSyncAdds, 0)
        items = c.orDefault(.items, [ImportListPreviewItem]())
    }

    public var site: SourceProvider { SourceProvider(feed: provider) }
}

public struct ImportListPreviewItem: Decodable, Sendable, Hashable {
    public let title: String
    public let year: Int?
    public let kind: String
    public let tmdbId: Int?
    public let inLibrary: Bool
    public let excluded: Bool
    public let posterUrl: String?

    enum CodingKeys: String, CodingKey { case title, year, kind, tmdbId, inLibrary, excluded, posterUrl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.orDefault(.title, "")
        year = c.lenient(.year)
        kind = c.orDefault(.kind, "movie")
        tmdbId = c.lenient(.tmdbId)
        inLibrary = c.orDefault(.inLibrary, false)
        excluded = c.orDefault(.excluded, false)
        posterUrl = c.lenient(.posterUrl)
    }
}
