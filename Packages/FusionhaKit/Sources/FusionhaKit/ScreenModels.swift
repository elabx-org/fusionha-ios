import Foundation

// MARK: - Coverage rail (the web's PosterCard / CoverageRail logic)

/// One edition's lifecycle on a poster card, derived exactly like the web's
/// `editionChipState` + `toChipEdition` (routes/library-mapping.ts).
public enum RailState: String, Sendable {
    case owned, partial, wanted, downloading, upgrading, upcoming
}

public struct Rail: Sendable, Hashable {
    public let state: RailState
    /// 0...100, the fill width.
    public let progress: Int
    /// `have/total` for series, nil for a single-file movie.
    public let fraction: String?
    /// The edition has not-found or dead-link files (amber/orange warning).
    public let attention: Bool
    public let deadLinkOnly: Bool
    /// Upcoming only: the date the edition becomes grabbable (ISO day), its
    /// release stage and whether the date is an estimate.
    public var upcomingDate: String? = nil
    public var upcomingStage: String? = nil
    public var upcomingEstimated: Bool = false

    /// A rail built outside the derivation (previews, the filters sheet's samples).
    public init(state: RailState, progress: Int, fraction: String?, attention: Bool, deadLinkOnly: Bool,
                upcomingDate: String? = nil, upcomingStage: String? = nil, upcomingEstimated: Bool = false) {
        self.state = state
        self.progress = progress
        self.fraction = fraction
        self.attention = attention
        self.deadLinkOnly = deadLinkOnly
        self.upcomingDate = upcomingDate
        self.upcomingStage = upcomingStage
        self.upcomingEstimated = upcomingEstimated
    }
}

extension Edition {
    /// The web's `editionChipState`: upgrading > downloading > have/total counts.
    public func chipState(isSeries: Bool) -> RailState {
        let have = self.have ?? 0
        let total = self.total ?? 0
        if status == .upgrading { return .upgrading }
        if status == .downloading { return .downloading }
        if isSeries, total > 0 {
            return have >= total ? .owned : (have > 0 ? .partial : .wanted)
        }
        return have > 0 ? .owned : .wanted
    }

    /// The coverage rail (CoverageRail.tsx). A wanted edition reads Upcoming when
    /// it carries its own `available_from` cue or the whole title is upcoming.
    public func rail(isSeries: Bool, itemUpcoming: Bool = false, itemUpcomingDate: String? = nil) -> Rail {
        let have = self.have ?? 0
        let total = self.total ?? 0
        var state = chipState(isSeries: isSeries)
        let ownCue = availableFrom != nil
        if state == .wanted && (ownCue || itemUpcoming) { state = .upcoming }
        let progress: Int
        switch state {
        case .owned: progress = 100
        case .upcoming: progress = 0
        default: progress = total > 0 ? Int((Double(have) / Double(total) * 100).rounded()) : (have > 0 ? 100 : 0)
        }
        let unresolved = unresolvedFileCount ?? 0
        let dead = deadLinkCount ?? 0
        let attention = (self.attention ?? false) || unresolved > 0
        return Rail(
            state: state,
            progress: progress,
            fraction: isSeries ? "\(have)/\(total)" : nil,
            attention: attention,
            deadLinkOnly: attention && dead > 0 && dead == unresolved,
            upcomingDate: state == .upcoming ? (availableFrom ?? itemUpcomingDate) : nil,
            upcomingStage: state == .upcoming && ownCue ? availableStage : nil,
            upcomingEstimated: state == .upcoming && ownCue && (availableEstimated ?? false))
    }
}

extension MediaItem {
    /// The web's kind buckets: anime wins over movie/series.
    public var kindBucket: KindBucket {
        if isAnime == true { return .anime }
        return kind == .movie ? .movie : .series
    }
}

public enum KindBucket: String, CaseIterable, Sendable {
    case movie, series, anime
    public var plural: String {
        switch self {
        case .movie: return "Movies"
        case .series: return "Series"
        case .anime: return "Anime"
        }
    }
}

// MARK: - Current user  (GET /api/v1/auth/me)

public struct Me: Decodable, Sendable {
    public let id: Int
    public let username: String
    public let isAdmin: Bool
    public let roleName: String?
    public let permissions: [String]?
    public let capabilities: [String]?
    /// Requester accounts get the web's reduced nav (Discover, My requests, You).
    public let requestScoped: Bool?
    public let thumb: String?
    // Account → Sign-in methods.
    public let plexUsername: String?
    public let plexLinked: Bool?
    public let credentials: [UserCredential]?

    public var initials: String { PersonInitials.of(username) }

    public var roleLabel: String {
        isAdmin ? "Administrator" : (roleName ?? "User")
    }

    /// True for an admin, or when the name is one of the user's capabilities
    /// (`add`, `request`, …) or permissions (`requests.approve`, `issues.manage`, …).
    /// The two vocabularies don't overlap, so one check serves both.
    public func can(_ name: String) -> Bool {
        hasCapability(name) || hasPermission(name)
    }

    /// The web's `can(p)`: admin, or `permissions` contains `p`.
    public func hasPermission(_ permission: String) -> Bool {
        isAdmin || (permissions ?? []).contains(permission)
    }

    /// The web's `hasCapability(c)`: admin, or `capabilities` contains `c`.
    public func hasCapability(_ capability: String) -> Bool {
        isAdmin || (capabilities ?? []).contains(capability)
    }
}

/// An avatar's letters (web `initials` in `access-shared.tsx`): the first
/// letters of two name parts ("sam.k" → "SK"), else the first two letters.
public enum PersonInitials {
    public static func of(_ name: String) -> String {
        let parts = name.split(whereSeparator: { $0 == " " || $0 == "." || $0 == "_" || $0 == "-" })
        let letters = parts.count >= 2 ? parts.prefix(2).compactMap(\.first) : Array(name.prefix(2))
        return String(letters).uppercased()
    }

    /// The web's per-person avatar hue (`hueForId`): golden-angle spacing so
    /// neighbouring ids differ; 220 for a missing id.
    public static func hue(_ id: Int?) -> Double {
        guard let id else { return 220 }
        return (Double(id) * 137.508).truncatingRemainder(dividingBy: 360).rounded()
    }
}
