import Foundation

// Request and issue models (field names follow the backend schemas,
// `api/schemas.py`, decoded with `.convertFromSnakeCase`).

// MARK: - Requests

public struct EpisodeRef: Codable, Sendable, Hashable {
    public let season: Int
    public let episode: Int
    public init(season: Int, episode: Int) {
        self.season = season
        self.episode = episode
    }
}

/// `GET /api/v1/requests/offerable`.
public struct OfferableEditions: Decodable, Sendable {
    public let editions: [QualityTier]
    public let mode: String
    public let autoEditions: [QualityTier]
    public var isAuto: Bool { mode == "auto" }
}

/// `POST /api/v1/requests` with the multi-edition body the web sends.
public struct RequestCreateBody: Encodable, Sendable {
    public let tmdbId: Int
    public let kind: MediaKind
    public let editions: [QualityTier]
    public let seasons: [Int]
    public let episodes: [EpisodeRef]
    public let note: String?
    /// Only join someone else's request (a join is never charged). Sent only when set, like the web.
    public let join: Bool?
    /// Over quota: keep it as WAITING, requested when the quota resets. Sent only when set.
    public let wishlist: Bool?
    public init(tmdbId: Int, kind: MediaKind, editions: [QualityTier], seasons: [Int] = [],
                episodes: [EpisodeRef] = [], note: String? = nil, join: Bool = false, wishlist: Bool = false) {
        self.tmdbId = tmdbId
        self.kind = kind
        self.editions = editions
        self.seasons = seasons
        self.episodes = episodes
        self.note = note
        self.join = join ? true : nil
        self.wishlist = wishlist ? true : nil
    }
}

public struct ApproveEdition: Encodable, Sendable {
    public let tier: QualityTier
    public let rootFolderId: Int?
    public let qualityProfileId: Int?
    public let monitored: Bool
    public init(tier: QualityTier, rootFolderId: Int?, qualityProfileId: Int?, monitored: Bool = true) {
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = monitored
    }
}

public struct ApproveBody: Encodable, Sendable {
    public let editions: [ApproveEdition]
    public let search: Bool
    public init(editions: [ApproveEdition], search: Bool) {
        self.editions = editions
        self.search = search
    }
}

public enum RequestReason: String, CaseIterable, Sendable {
    case notAvailableYet = "not_available_yet"
    case overQuota = "over_quota"
    case notForThisLibrary = "not_for_this_library"
    case other

    public var title: String {
        switch self {
        case .notAvailableYet: return "Not available yet"
        case .overQuota: return "Over quota"
        case .notForThisLibrary: return "Not for this library"
        case .other: return "Other"
        }
    }
}

public struct RejectBody: Encodable, Sendable {
    public let reason: String
    public let defer_: Bool
    public let note: String?
    public init(reason: RequestReason, defer: Bool, note: String?) {
        self.reason = reason.rawValue
        self.defer_ = `defer`
        self.note = note
    }
    enum CodingKeys: String, CodingKey {
        case reason, note
        case defer_ = "defer"
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reason, forKey: .reason)
        try c.encode(defer_, forKey: .defer_)
        try c.encodeIfPresent(note, forKey: .note)
    }
}

// MARK: - Issues  (GET/POST /api/v1/issues)

public enum IssueType: String, CaseIterable, Sendable {
    case playback, video, audio, subtitle, other
    public var title: String {
        switch self {
        case .playback: return "Won't play"
        case .video: return "Video quality"
        case .audio: return "Audio"
        case .subtitle: return "Subtitles"
        case .other: return "Other"
        }
    }
}

public struct MediaIssue: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let mediaItemId: Int
    public let reporterUserId: Int?
    public let issueType: String
    public let scope: String
    public let season: Int?
    public let episode: Int?
    public let description: String?
    public let status: String
    public let resolved: Bool?
    public let createdAt: String?
    public let resolvedAt: String?
    public let comment: String?
    // The issues revamp (fusionha phase 6, `IssueModels.swift`); optional so
    // an older server still decodes.
    public let reporter: RequestPerson?
    public let state: String?
    public let reopenCount: Int?
    public let participantsCount: Int?
    public let thread: RequestThreadSummary?
    public let reports: [IssueReport]?
    public let mediaTitle: String?
    public let mediaYear: Int?
    public let poster: String?
    public let deduped: Bool?

    public var typeLabel: String { IssueType(rawValue: issueType)?.title ?? issueType.capitalized }

    public var scopeLabel: String {
        switch scope {
        case "season":
            return season == 0 ? "Specials" : "Season \(season ?? 0)"
        case "episode":
            return String(format: "S%02dE%02d", season ?? 0, episode ?? 0)
        default:
            return "Whole title"
        }
    }
}

public struct IssueCreateBody: Encodable, Sendable {
    public let mediaItemId: Int
    public let issueType: String
    public let scope: String
    public let season: Int?
    public let episode: Int?
    public let description: String?
    public init(mediaItemId: Int, issueType: IssueType, scope: String, season: Int?, episode: Int?, description: String?) {
        self.mediaItemId = mediaItemId
        self.issueType = issueType.rawValue
        self.scope = scope
        self.season = season
        self.episode = episode
        self.description = description
    }
}

public struct IssueResolveBody: Encodable, Sendable {
    public let comment: String
    public init(comment: String) { self.comment = comment }
}

// MARK: - Request status helpers

extension MediaRequest {
    /// The web's card-chip priority when a title has several requests.
    public static func priority(_ status: String) -> Int {
        switch status {
        case "pending": return 5
        case "approved": return 4
        case "fulfilled": return 3
        case "deferred": return 2
        case "rejected": return 1
        default: return 0
        }
    }

    /// The requested tiers (`editions`, else the primary `tier`).
    public var tiers: [QualityTier] {
        if let editions, !editions.isEmpty { return editions }
        return [tier]
    }

    public var previewKind: PreviewKind { kind == .movie ? .movie : .series }
}
