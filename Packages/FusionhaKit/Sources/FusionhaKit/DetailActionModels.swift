import Foundation

// MARK: - Interactive search

/// One release from `GET /api/v1/library/{id}/releases` (`ReleasePreviewRead`).
public struct ReleasePreview: Decodable, Sendable, Hashable, Identifiable {
    public let guid: String
    public let title: String
    public let quality: String?
    public let `protocol`: String?
    public let indexerId: Int?
    public let indexerName: String?
    public let size: Double?
    public let downloadUrl: String?
    public let cfScore: Int?
    public let action: String?
    public let reason: String?
    public let publishedAt: String?
    public let ageSeconds: Double?
    public let seeders: Int?
    public let releaseGroup: String?
    /// Release attributes (freeleech / internal) when a feed exposes them.
    public let flags: [String]?
    public let blocklisted: Bool?
    /// Why it was blocklisted, when the server says (the web falls back to a stock line).
    public let blocklistReason: String?
    public let lowConfidence: Bool?

    public var id: String { guid }
    public var protocolName: String { self.protocol ?? "" }
    /// A rejected release can still be grabbed, but only as an override.
    public var rejected: Bool { action == "reject" }
}

/// `POST /api/v1/library/{id}/releases/grab` → `ReleaseGrabResponse`: only the
/// grab provenance is read (`interactive`, or `forced` for grab-anyway).
public struct ReleaseGrabResponse: Decodable, Sendable {
    public let grabTrigger: String?
}

/// `GET /api/v1/library/{id}/releases/scope-status` (`ReleaseScopeStatusRead`):
/// why this scope's automatic search is (or isn't) paused.
public struct ReleaseScopeStatus: Decodable, Sendable, Hashable {
    public let backoffActive: Bool?
    public let backoffNextEligibleAt: String?
    public let backoffConsecutiveEmpty: Int?
    public let failedDownloadCount: Int?
    public let failedGrabCooldownActive: Bool?
    public let failedGrabCooldownUntil: String?
    public let lastRunAt: String?
    public let lastRunReleases: Int?
    public let lastRunGrabbed: Int?
    public let lastRunRejected: Int?
}

/// `GET /api/v1/system/indexers/unavailable` (`IndexerUnavailableSummary`).
public struct IndexerUnavailableSummary: Decodable, Sendable, Hashable {
    public let count: Int?
    public let items: [IndexerUnavailable]?
}

public struct IndexerUnavailable: Decodable, Sendable, Hashable, Identifiable {
    public let indexerId: Int
    public let name: String
    public let disabledTill: String?
    public let reason: String?
    public var id: Int { indexerId }
}

/// `POST /api/v1/library/{id}/releases/grab`.
public struct ReleaseGrabRequest: Encodable, Sendable {
    /// Sent as `version_id` (the server still accepts the old `edition_id`).
    public let versionId: Int
    public let episodeId: Int?
    public let seasonNumber: Int?
    public let guid: String
    public let downloadUrl: String
    public let title: String
    public let `protocol`: String
    public let indexerId: Int
    public let size: Int64?
    public let cfScore: Int
    public let override: Bool

    public init(release: ReleasePreview, editionId: Int, episodeId: Int?, seasonNumber: Int?, override: Bool) {
        self.versionId = editionId
        self.episodeId = episodeId
        self.seasonNumber = seasonNumber
        guid = release.guid
        downloadUrl = release.downloadUrl ?? ""
        title = release.title
        self.protocol = release.protocolName
        indexerId = release.indexerId ?? 0
        size = release.size.map { Int64($0) }
        cfScore = release.cfScore ?? 0
        self.override = override
    }
}

// MARK: - Edits

/// `PATCH /api/v1/library/{id}`: only the keys that changed are sent.
public struct ItemUpdate: Encodable, Sendable {
    public var monitored: Bool?
    public var seriesType: String?
    public var tagIds: [Int]?
    public init(monitored: Bool? = nil, seriesType: String? = nil, tagIds: [Int]? = nil) {
        self.monitored = monitored
        self.seriesType = seriesType
        self.tagIds = tagIds
    }
    public var isEmpty: Bool { monitored == nil && seriesType == nil && tagIds == nil }
}

/// `PATCH /api/v1/library/{id}/versions/{vid}` (`VersionUpdate`): only the keys that changed are sent.
public struct EditionUpdate: Encodable, Sendable {
    public var monitored: Bool?
    public var monitor: String?
    public var qualityProfileId: Int?
    public var rootFolderId: Int?
    public var folderName: String?
    public var rootFolderDisposition: String?
    public var minimumAvailability: String?
    public init(monitored: Bool? = nil, monitor: String? = nil, qualityProfileId: Int? = nil,
                rootFolderId: Int? = nil, folderName: String? = nil,
                rootFolderDisposition: String? = nil, minimumAvailability: String? = nil) {
        self.monitored = monitored
        self.monitor = monitor
        self.qualityProfileId = qualityProfileId
        self.rootFolderId = rootFolderId
        self.folderName = folderName
        self.rootFolderDisposition = rootFolderDisposition
        self.minimumAvailability = minimumAvailability
    }
    public var isEmpty: Bool {
        monitored == nil && monitor == nil && qualityProfileId == nil && rootFolderId == nil
            && folderName == nil && rootFolderDisposition == nil && minimumAvailability == nil
    }
}

/// `POST /api/v1/library/{id}/versions` (`VersionAddRequest`). The edition goes
/// out as `edition` (the server still accepts the old `movie_edition`).
public struct EditionAdd: Encodable, Sendable {
    public let tier: QualityTier
    public let edition: String?
    public let rootFolderId: Int
    public let qualityProfileId: Int
    public let monitored: Bool
    public let folderName: String?
    public let monitor: String?
    public let minimumAvailability: String?
    public let searchNow: Bool
    public init(tier: QualityTier, movieEdition: String?, rootFolderId: Int, qualityProfileId: Int,
                monitored: Bool, folderName: String?, monitor: String?, minimumAvailability: String?,
                searchNow: Bool) {
        self.tier = tier
        self.edition = movieEdition
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = monitored
        self.folderName = folderName
        self.monitor = monitor
        self.minimumAvailability = minimumAvailability
        self.searchNow = searchNow
    }
}

public struct MonitorToggle: Encodable, Sendable {
    public let monitored: Bool
    public init(monitored: Bool) { self.monitored = monitored }
}

public struct TagCreate: Encodable, Sendable {
    public let label: String
    public init(label: String) { self.label = label }
}

/// `GET /api/v1/library/{id}/numbering/preview`: the season-by-season diff the
/// rail's check and the "Fix episode numbering" sheet read.
public struct NumberingPreview: Decodable, Sendable {
    public let source: String?
    public let agrees: Bool?
    public let diffHash: String?
    public let activeQueueBlocked: Bool?
    public let rows: [NumberingDiffRow]?
    public let renumbered: [NumberingRenumbered]?
    public let added: [NumberingEpisodeRef]?
    public let relinked: [NumberingFileRef]?
    public let removedPhantoms: [NumberingEpisodeRef]?
    public let unparseable: [NumberingFileRef]?
}
