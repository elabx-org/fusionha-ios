import Foundation

// Models for the Library page, the app shell (top bar, user menu, omni search,
// toasts, bulk bar), the Add flow and Login. Field names follow `openapi.json`
// and decode with `.convertFromSnakeCase`.

// MARK: - Library kind buckets (routes/library-filters.ts `matchesKind`)

/// The web's mutually exclusive kind buckets: anime owns every anime title,
/// animation every non-anime animated title, movie/series the live-action rest.
public enum LibraryKind: String, CaseIterable, Sendable {
    case movie, series, anime, animation

    public var plural: String {
        switch self {
        case .movie: return "Movies"
        case .series: return "Series"
        case .anime: return "Anime"
        case .animation: return "Animation"
        }
    }
}

/// The Library-Pulse title status (routes/library-pulse.ts `itemCardStatus`).
public enum CardStatus: String, CaseIterable, Sendable {
    case downloading, missing, upcoming, complete

    /// Group-by-status section labels (STATUS_SECTIONS).
    public var sectionLabel: String {
        switch self {
        case .downloading: return "Downloading"
        case .missing: return "Needs attention"
        case .upcoming: return "Upcoming"
        case .complete: return "Complete"
        }
    }
}

extension MediaItem {
    public var libraryKind: LibraryKind {
        if isAnime == true { return .anime }
        if isAnimation == true { return .animation }
        return kind == .movie ? .movie : .series
    }

    /// `itemUpcomingCue`: a monitored, fileless title the backend says is not
    /// yet available reads Upcoming.
    public var isUpcoming: Bool {
        (monitored ?? true) && editions.allSatisfy { ($0.have ?? 0) == 0 } && isAvailable == false
    }

    /// One rail per edition, with the item-level upcoming fallback applied.
    public var rails: [Rail] {
        let upcoming = isUpcoming
        return editions.map { $0.rail(isSeries: kind == .series, itemUpcoming: upcoming, itemUpcomingDate: nextRelease) }
    }

    /// First match wins: downloading, upcoming, missing, complete.
    public var cardStatus: CardStatus {
        let states = editions.map { $0.chipState(isSeries: kind == .series) }
        if states.contains(.downloading) { return .downloading }
        if isUpcoming { return .upcoming }
        if states.contains(where: { $0 == .wanted || $0 == .partial }) { return .missing }
        return .complete
    }

    /// Per-edition buckets for the health meter (`editionBuckets`).
    public var editionBuckets: [CardStatus] {
        let upcoming = isUpcoming
        return editions.map { edition in
            let state = edition.chipState(isSeries: kind == .series)
            if state == .downloading { return .downloading }
            if upcoming { return .upcoming }
            if state == .owned { return .complete }
            return .missing
        }
    }

    public var totalSize: Double { editions.reduce(0) { $0 + ($1.size ?? 0) } }
}

// MARK: - Bulk actions  (POST /api/v1/library/bulk/*)

public struct BulkMonitorRequest: Encodable, Sendable {
    public let itemIds: [Int]
    public let editionIds: [Int]
    public let monitored: Bool
    public init(itemIds: [Int], editionIds: [Int] = [], monitored: Bool) {
        self.itemIds = itemIds
        self.editionIds = editionIds
        self.monitored = monitored
    }
}

public struct BulkQualityProfileRequest: Encodable, Sendable {
    public let itemIds: [Int]
    public let qualityProfileId: Int
    public init(itemIds: [Int], qualityProfileId: Int) {
        self.itemIds = itemIds
        self.qualityProfileId = qualityProfileId
    }
}

/// Radarr wire values: `announced` / `inCinemas` / `released`.
public enum AvailabilityOption: String, CaseIterable, Sendable, Encodable {
    case announced
    case inCinemas
    case released

    public var label: String {
        switch self {
        case .announced: return "Announced"
        case .inCinemas: return "In Cinemas"
        case .released: return "Released"
        }
    }
}

public struct BulkMinimumAvailabilityRequest: Encodable, Sendable {
    public let itemIds: [Int]
    public let minimumAvailability: AvailabilityOption
    public init(itemIds: [Int], minimumAvailability: AvailabilityOption) {
        self.itemIds = itemIds
        self.minimumAvailability = minimumAvailability
    }
}

/// What happens to existing files when a root folder changes.
public enum RootFileDisposition: String, CaseIterable, Sendable, Encodable {
    case move, leave, delete
    public var label: String { rawValue.capitalized }
}

public struct BulkRootFolderRequest: Encodable, Sendable {
    public let itemIds: [Int]
    /// `HD-1080p`, `UHD-2160p` or `all`.
    public let tier: String
    public let rootFolderId: Int
    public let disposition: RootFileDisposition
    public init(itemIds: [Int], tier: String, rootFolderId: Int, disposition: RootFileDisposition) {
        self.itemIds = itemIds
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.disposition = disposition
    }
}

public struct BulkDeleteRequest: Encodable, Sendable {
    public let itemIds: [Int]
    public let deleteFiles: Bool
    public init(itemIds: [Int], deleteFiles: Bool) {
        self.itemIds = itemIds
        self.deleteFiles = deleteFiles
    }
}

public struct BulkRefreshRequest: Encodable, Sendable {
    public let itemIds: [Int]
    public let metadataOnly: Bool
    public init(itemIds: [Int], metadataOnly: Bool) {
        self.itemIds = itemIds
        self.metadataOnly = metadataOnly
    }
}

public struct BulkResult: Decodable, Sendable {
    public let affected: Int?
}

// MARK: - Runs  (POST /library/{id}/refresh → GET /system/runs/{id})

public struct RefreshDispatch: Decodable, Sendable {
    public let runId: Int
}

public struct CommandRunState: Decodable, Sendable {
    public let id: Int
    /// `running`, `completed`, `failed`, … (CommandStatus).
    public let status: String
    public let detail: String?

    public var isRunning: Bool { status == "running" || status == "queued" || status == "pending" }
    public var failed: Bool { status == "failed" || status == "error" || status == "cancelled" }
}

/// `GET /api/v1/system/commands`: the arr-style command list (nav pulse ring).
public struct ShellCommand: Decodable, Sendable {
    public let id: String
    public let name: String
    public let status: String
}

// MARK: - Attention  (avatar dot)

/// Decodes and throws away any JSON value, so lists can be counted cheaply.
public struct IgnoredJSON: Decodable, Sendable {
    public init(from decoder: Decoder) throws {}
}

public struct AttentionItems: Decodable, Sendable {
    public let items: [IgnoredJSON]?
    public var count: Int { items?.count ?? 0 }
}

// MARK: - Settings  (GET/PUT /api/v1/settings, the fields the shell reads)

public struct ShellSettings: Decodable, Sendable {
    /// `current` / `fill` / `dot`.
    public let libraryRailStyle: String?
    public let libraryRailConsolidate: Bool?
    public let metadataProvider: String?
    public let defaultMovieMinimumAvailability: String?
    /// The admin's global motion switch (Settings → Appearance).
    public let animationsEnabled: Bool?
}

public struct RailSettingsUpdate: Encodable, Sendable {
    public let libraryRailStyle: String?
    public let libraryRailConsolidate: Bool?
    public init(libraryRailStyle: String? = nil, libraryRailConsolidate: Bool? = nil) {
        self.libraryRailStyle = libraryRailStyle
        self.libraryRailConsolidate = libraryRailConsolidate
    }
}

// MARK: - Add flow

/// `GET /api/v1/search/tvdb?term=`.
public struct TvdbSearchResult: Decodable, Sendable, Identifiable, Hashable {
    public let tvdbId: Int
    public let title: String
    public let year: Int?
    public let overview: String?
    public let imageUrl: String?
    public let tmdbId: Int?
    public let imdbId: String?
    public let inLibrary: Bool?
    public let libraryItemId: Int?
    public var id: Int { tvdbId }
}

/// `POST /api/v1/discover/check-4k`.
public struct FourKAvailabilityRequest: Encodable, Sendable {
    public let tmdbId: Int
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let isAnime: Bool
    public init(tmdbId: Int, title: String, kind: MediaKind, year: Int?, isAnime: Bool) {
        self.tmdbId = tmdbId
        self.title = title
        self.kind = kind
        self.year = year
        self.isAnime = isAnime
    }
}

public struct FourKAvailabilityTag: Decodable, Sendable, Hashable {
    public let label: String
    public let kind: String?
}

public struct FourKAvailability: Decodable, Sendable {
    public let dispatched: Bool?
    public let queriedIndexers: Int?
    public let foundUhd: Bool?
    public let seasonsSeen: [Int?]?
    public let bestReleaseName: String?
    public let formatTags: [FourKAvailabilityTag]?
    public let message: String?
}

/// The full `POST /api/v1/library` body, matching AddItemModal's payload.
/// Optional fields are omitted when nil, as the web omits them.
public struct LibraryAddBody: Encodable, Sendable {
    public let title: String
    public let kind: MediaKind
    public let year: Int?
    public let tmdbId: Int?
    public let tvdbId: Int?
    public let isAnime: Bool
    public let editions: [EditionAddBody]
    public let searchNow: Bool
    public let monitor: String
    public let minimumAvailability: String?
    public let seriesType: String?
    public let metadataProvider: String?
    public init(title: String, kind: MediaKind, year: Int?, tmdbId: Int?, tvdbId: Int?, isAnime: Bool,
                editions: [EditionAddBody], searchNow: Bool, monitor: String, minimumAvailability: String?,
                seriesType: String?, metadataProvider: String?) {
        self.title = title
        self.kind = kind
        self.year = year
        self.tmdbId = tmdbId
        self.tvdbId = tvdbId
        self.isAnime = isAnime
        self.editions = editions
        self.searchNow = searchNow
        self.monitor = monitor
        self.minimumAvailability = minimumAvailability
        self.seriesType = seriesType
        self.metadataProvider = metadataProvider
    }
}

public struct EditionAddBody: Encodable, Sendable {
    public let tier: QualityTier
    public let rootFolderId: Int
    public let qualityProfileId: Int
    public let monitored: Bool
    public let monitor: String?
    public let folderName: String?
    public init(tier: QualityTier, rootFolderId: Int, qualityProfileId: Int, monitor: String?, folderName: String?) {
        self.tier = tier
        self.rootFolderId = rootFolderId
        self.qualityProfileId = qualityProfileId
        self.monitored = true
        self.monitor = monitor
        self.folderName = folderName
    }
}

/// Quality profiles with their allowed qualities, for the 4K/HD default guess.
public struct QualityProfileSummary: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let mediaKind: String?
    public let allowedQualities: [String]?
}

// MARK: - Login

public struct DemoLoginRequest: Encodable, Sendable {
    public let username: String?
    public let password: String?
    public init(username: String?, password: String?) {
        self.username = username
        self.password = password
    }
}

/// `GET /api/v1/auth/providers` (OIDC entries; not every server has it yet).
public struct SignInProvider: Decodable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let kind: String
    public let authorizeUrl: String?

    private enum CodingKeys: String, CodingKey { case id, name, kind, authorizeUrl }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let text = try? c.decode(String.self, forKey: .id) {
            id = text
        } else {
            id = String(try c.decode(Int.self, forKey: .id))
        }
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "SSO"
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "oidc"
        authorizeUrl = try c.decodeIfPresent(String.self, forKey: .authorizeUrl)
    }
}

extension MediaSearchResult {
    /// A copy with a different `in_library` flag (used by the Add flow's screenshot hook).
    public init(copying other: MediaSearchResult, inLibrary: Bool) {
        self.init(tmdbId: other.tmdbId, title: other.title, year: other.year, kind: other.kind, isAnime: other.isAnime,
                  overview: other.overview, inLibrary: inLibrary, libraryItemId: nil, posterUrl: other.posterUrl,
                  backdropUrl: other.backdropUrl, date: other.date, voteAverage: other.voteAverage)
    }
}
