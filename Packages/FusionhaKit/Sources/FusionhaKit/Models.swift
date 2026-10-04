import Foundation

// Hand-written models for the endpoints the app uses so far. Field names follow
// `openapi.json` (decoded with `.convertFromSnakeCase`); nullable fields are optional.
// These move to Swift OpenAPI Generator output once the spec is trimmed to what we use.

public enum QualityTier: String, Codable, Sendable, Hashable {
    case hd = "HD-1080p"
    case uhd = "UHD-2160p"

    /// Chip label, matching the web's `HD·1080p` / `UHD·4K`.
    public var chipLabel: String {
        switch self {
        case .hd: return "HD·1080p"
        case .uhd: return "UHD·4K"
        }
    }

    public var shortLabel: String { self == .hd ? "1080p" : "4K" }
}

public enum MediaKind: String, Codable, Sendable {
    case movie
    case series
}

/// The web's status vocabulary (`frontend/src/lib/status.ts`). The library and
/// calendar endpoints send `done` / `grabbing` / `wanted` / `upgrading`; the other
/// arr states are accepted too. Unknown values decode to `.other` so a newer server
/// never breaks an older app.
public enum EditionStatus: Decodable, Sendable, Hashable {
    case downloaded, downloading, upgrading, missing, unaired, upcoming
    case unmonitored, onair, premiere, stuck, deadlink, available
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "done", "downloaded": self = .downloaded
        case "grabbing", "downloading": self = .downloading
        case "upgrading": self = .upgrading
        case "missing", "wanted": self = .missing
        case "unaired": self = .unaired
        case "upcoming": self = .upcoming
        case "unmonitored": self = .unmonitored
        case "onair": self = .onair
        case "premiere": self = .premiere
        case "stuck": self = .stuck
        case "deadlink": self = .deadlink
        case "available": self = .available
        default: self = .other(rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public var label: String {
        switch self {
        case .downloaded: return "Downloaded"
        case .downloading: return "Downloading"
        case .upgrading: return "Upgrading"
        case .missing: return "Missing"
        case .unaired: return "Unaired"
        case .upcoming: return "Upcoming"
        case .unmonitored: return "Unmonitored"
        case .onair: return "On Air"
        case .premiere: return "Premiere"
        case .stuck: return "Stuck"
        case .deadlink: return "Dead link"
        case .available: return "Available"
        case .other(let raw): return raw.capitalized
        }
    }
}

// MARK: - Auth

public struct LoginRequest: Encodable, Sendable {
    public let username: String
    public let password: String
}

public struct TokenCreate: Encodable, Sendable {
    public let name: String
}

public struct TokenMint: Decodable, Sendable {
    public let id: Int
    public let name: String
    public let tokenPrefix: String
    public let token: String
}

/// `GET /api/v1/setup-status` (unauthenticated): which sign-in methods the server offers.
public struct SetupStatus: Decodable, Sendable {
    public let needsSetup: Bool
    public let plexSsoEnabled: Bool?
    public let localLoginEnabled: Bool?
    // The admin's login-page appearance (Settings → General → Login page).
    public let loginLayout: String?
    public let loginBackground: String?
    public let loginShowLogo: Bool?
    public let loginShowWordmark: Bool?
    public let loginShowTagline: Bool?

    public var offersPlex: Bool { plexSsoEnabled == true }
    /// Older servers don't send the flag; username/password was always available there.
    public var offersPassword: Bool { localLoginEnabled ?? true }
}

/// `POST /api/v1/auth/plex/pin`. Note `authUrl` is camelCase on the wire.
public struct PlexPin: Decodable, Sendable {
    public let id: Int
    public let code: String
    public let authUrl: String
}

public enum PlexPinState: Sendable {
    case pending
    case signedIn
}

public struct HealthResponse: Decodable, Sendable {
    public let status: String
    public let version: String
}

// MARK: - Queue  (GET /api/v1/queue)

public struct QueuePage: Decodable, Sendable {
    public let items: [QueueItem]
    public let total: Int
    public let justFinished: [QueueItem]?
}

public struct QueueItem: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let episodeLabel: String?
    public let releaseTitle: String?
    public let status: String
    public let size: Double
    public let sizeleft: Double
    /// Percent, 0–100.
    public let progress: Double
    public let stalled: Bool
    public let needsAttention: Bool?
    public let mediaItemId: Int
    public let editionId: Int
    public let tier: QualityTier
    public let posterUrl: String?
    public let phase: String?
    public let step: String?
    public let phasePercent: Int?
    // Extra queue fields the Activity screen reads (all optional, so older
    // servers and the widgets keep decoding).
    public let `protocol`: String?
    public let downloadClient: String?
    public let indexer: String?
    public let grabTrigger: String?
    public let heldReason: String?
    public let heldDetail: HeldDetail?
    public let warning: String?
    public let nextStep: String?
    public let hasDownloadedFile: Bool?
    public let grabbedAt: String?
    public let ageSeconds: Double?
    public let episodeId: Int?
    public let phaseTerminal: Bool?
    public let outcome: String?
    public let terminalReason: String?
    public let finishedAt: String?

    public var fraction: Double { min(max(progress / 100, 0), 1) }
}

// MARK: - Library  (GET /api/v1/library)

public struct MediaItem: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let isAnime: Bool?
    public let posterUrl: String?
    public let backdropUrl: String?
    public let monitored: Bool?
    public let hasAttention: Bool?
    public let releaseDate: String?
    public let addedAt: String?
    public let editions: [Edition]
}

public struct Edition: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let tier: QualityTier
    public let movieEdition: String?
    public let monitored: Bool
    public let status: EditionStatus
    public let have: Int?
    public let total: Int?
    public let size: Double?
    public let attention: Bool?
    public let unresolvedFileCount: Int?
    public let deadLinkCount: Int?
    public let availableFrom: String?
}

// MARK: - Wanted  (GET /api/v1/wanted)

public struct WantedCounts: Decodable, Sendable {
    public let total: Int
    public let missingCount: Int?
    public let cutoffUnmetCount: Int?
    public let upcomingCount: Int?
}

// MARK: - Calendar  (GET /api/v1/calendar)

public struct CalendarEntry: Decodable, Sendable, Hashable {
    public let type: String
    public let date: String
    public let itemId: Int
    public let title: String
    public let mediaKind: MediaKind
    public let isAnime: Bool
    public let posterUrl: String?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let absoluteNumber: Int?
    public let episodeTitle: String?
    public let editions: [CalendarEdition]
}

public struct CalendarEdition: Decodable, Sendable, Hashable {
    public let editionId: Int
    public let tier: QualityTier
    public let monitored: Bool
    public let status: EditionStatus
}

// MARK: - Images

public enum TMDBImage {
    /// Swap the size segment of a TMDB URL (`/w500/` → `/w185/`) for smaller surfaces.
    public static func resized(_ url: String?, to size: String) -> URL? {
        guard let url else { return nil }
        let swapped = url.replacingOccurrences(
            of: #"/t/p/[a-z0-9]+/"#, with: "/t/p/\(size)/", options: .regularExpression)
        return URL(string: swapped)
    }
}
