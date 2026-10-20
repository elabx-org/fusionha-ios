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
    /// `version_id` since 0.4.122, `edition_id` before: either decodes.
    public var editionId: Int? { versionId ?? legacyEditionId }
    private let versionId: Int?
    private let legacyEditionId: Int?
    public let episodeId: Int?
    public let cooldownUntil: String?
    public let failedDownloadCount: Int?

    private enum CodingKeys: String, CodingKey {
        case versionId
        case legacyEditionId = "editionId"
        case episodeId, cooldownUntil, failedDownloadCount
    }
}

public struct SeasonPause: Decodable, Sendable, Hashable {
    /// `version_id` since 0.4.122, `edition_id` before: either decodes.
    public var editionId: Int? { versionId ?? legacyEditionId }
    private let versionId: Int?
    private let legacyEditionId: Int?
    public let seasonNumber: Int?
    public let backoffUntil: String?
    public let consecutiveEmpty: Int?

    private enum CodingKeys: String, CodingKey {
        case versionId
        case legacyEditionId = "editionId"
        case seasonNumber, backoffUntil, consecutiveEmpty
    }
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
    /// `version_id` since 0.4.122, `edition_id` before: either decodes.
    public var editionId: Int? { versionId ?? legacyEditionId }
    private let versionId: Int?
    private let legacyEditionId: Int?
    public let reason: String?
    public let score: Int?
    public let releaseTitle: String?

    public var grabbed: Bool { action == "grab" || action == "upgrade" }

    private enum CodingKeys: String, CodingKey {
        case action, versionId
        case legacyEditionId = "editionId"
        case reason, score, releaseTitle
    }
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
    /// Set on a completed numbering-apply run.
    public let numberingSummary: NumberingApplyResult?

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
