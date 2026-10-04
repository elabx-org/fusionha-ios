import Foundation

// Models for the item detail page (`GET /api/v1/library/{id}` extras and the
// actions the page runs). Field names follow the backend schemas; everything a
// newer or older server might omit is optional.

// MARK: - Item detail extras

/// One release window on a movie (`cinema` / `digital` / `physical`).
public struct ReleaseWindow: Decodable, Sendable, Hashable {
    public let kind: String?
    public let date: String?
    public let estimated: Bool?
}

// `CastMember` is shared with Discover (DiscoverModels.swift).

/// A "More like this" card (TMDB `/similar`).
public struct SimilarTitle: Decodable, Sendable, Hashable {
    public let tmdbId: Int?
    public let title: String?
    public let year: Int?
    public let posterUrl: String?
    public let kind: String?
    public let inLibrary: Bool?
}

public struct CollectionRef: Decodable, Sendable, Hashable {
    public let collectionTmdbId: Int?
    public let name: String?
}

public struct ItemTag: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let label: String
}

/// The probed media facts of a file (`media_info.probe`). Decoding never fails:
/// a missing or oddly shaped probe just yields `nil` fields.
public struct FileProbe: Sendable, Hashable {
    public let videoCodec: String?
    public let hdrFormat: String?
    public let runtimeSeconds: Double?
    public let audioCodec: String?
    public let audioChannels: Double?
    public let audioLanguages: [String]?
}

public struct MediaInfo: Decodable, Sendable, Hashable {
    public let probe: FileProbe?
    public let finalMode: String?

    private enum CodingKeys: String, CodingKey { case probe, finalMode }
    private struct RawProbe: Decodable {
        let videoCodec: String?
        let hdrFormat: String?
        let runtimeSeconds: Double?
        let audio: RawAudio?
    }
    private struct RawAudio: Decodable {
        let codec: String?
        let channels: Double?
        let languages: [String]?
    }

    public init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        finalMode = (try? container?.decodeIfPresent(String.self, forKey: .finalMode)) ?? nil
        if let raw = (try? container?.decodeIfPresent(RawProbe.self, forKey: .probe)) ?? nil {
            probe = FileProbe(videoCodec: raw.videoCodec, hdrFormat: raw.hdrFormat,
                              runtimeSeconds: raw.runtimeSeconds, audioCodec: raw.audio?.codec,
                              audioChannels: raw.audio?.channels, audioLanguages: raw.audio?.languages)
        } else {
            probe = nil
        }
    }
}

// MARK: - Page data

/// `GET /api/v1/import/enrichment-status`: the "Analysing N files" pill.
public struct EnrichmentStatus: Decodable, Sendable, Hashable {
    public let totalFiles: Int?
    public let enrichedFiles: Int?
    public let pendingFiles: Int?
    public let issueFiles: Int?
}

/// `GET /api/v1/library/{id}/search-pauses`: failed-download cooldowns.
public struct SearchPauses: Decodable, Sendable, Hashable {
    public let episodes: [EpisodePause]?
    public let seasons: [SeasonPause]?
    public let now: String?
}

public struct EpisodePause: Decodable, Sendable, Hashable {
    public let editionId: Int?
    public let episodeId: Int?
    public let cooldownUntil: String?
    public let failedDownloadCount: Int?
}

public struct SeasonPause: Decodable, Sendable, Hashable {
    public let editionId: Int?
    public let seasonNumber: Int?
    public let backoffUntil: String?
    public let consecutiveEmpty: Int?
}

/// The few `GET /api/v1/settings` values the detail page reads.
public struct DetailSettings: Decodable, Sendable, Hashable {
    public let seasonSearchIntervalSeconds: Int?
    public let defaultMovieMinimumAvailability: String?
    /// The web's "Animations" switch; off forces reduced motion.
    public let animationsEnabled: Bool?
    /// Off → indexers aren't searched (the Manual search sheet explains the empty list).
    public let realIntegrations: Bool?
}

/// `GET /api/v1/config/editions`: the named edition/version vocabulary.
public struct EditionDefinition: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let enabled: Bool?
}

// MARK: - Searches and runs

/// One decision from `POST /library/{id}/search` (`DecisionRead`).
public struct SearchDecision: Decodable, Sendable, Hashable {
    public let action: String
    public let editionId: Int?
    public let reason: String?
    public let score: Int?
    public let releaseTitle: String?

    public var grabbed: Bool { action == "grab" || action == "upgrade" }
}

/// `POST …/search/gradual` and `…/search/season/{n}/gradual`.
public struct GradualSearchStart: Decodable, Sendable, Hashable {
    public let runId: Int?
    public let total: Int?
    public let alreadyRunning: Bool?
}

/// The outcome of a Refresh & Scan, carried on the finished run.
public struct RescanSummary: Decodable, Sendable, Hashable {
    public let attached: Int?
    public let flagged: Int?
    public let removed: Int?
    public let healed: Int?
    public let dangling: Int?
    public let probed: Int?
    public let standdown: [Int]?
}

/// One decision-making pass (`CommandRunRead` / `CommandRunDetailRead`).
public struct CommandRun: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String?
    public let trigger: String?
    public let status: String?
    public let itemId: Int?
    public let scope: String?
    public let targetTitle: String?
    public let targetSummary: String?
    public let startedAt: String?
    public let endedAt: String?
    public let durationMs: Int?
    public let releases: Int?
    public let evaluated: Int?
    public let grabbed: Int?
    public let upgraded: Int?
    public let rejected: Int?
    public let errors: Int?
    public let phase: String?
    public let progressCurrent: Int?
    public let progressTotal: Int?
    public let detail: String?
    public let rescanSummary: RescanSummary?

    public var isRunning: Bool { status == "running" }
}

public struct CommandRunPage: Decodable, Sendable {
    public let items: [CommandRun]
    public let total: Int
}

/// `POST /api/v1/library/{id}/check-4k`.
public struct FourKCheck: Decodable, Sendable, Hashable {
    public let dispatched: Bool?
    public let queriedIndexers: Int?
    public let foundUhd: Bool?
    public let bestReleaseName: String?
    public let message: String?
}

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
    public let editionId: Int
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
        self.editionId = editionId
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

/// `PATCH /api/v1/library/{id}/editions/{eid}`: only the keys that changed are sent.
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

/// `POST /api/v1/library/{id}/editions` (`EditionAddRequest`).
public struct EditionAdd: Encodable, Sendable {
    public let tier: QualityTier
    public let movieEdition: String?
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
        self.movieEdition = movieEdition
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

/// `GET /api/v1/library/{id}/numbering/preview` (only what the check needs).
public struct NumberingPreview: Decodable, Sendable {
    public let source: String?
    public let agrees: Bool?
}
