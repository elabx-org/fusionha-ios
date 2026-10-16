import Foundation

// Pure helpers for the Plex access card and the panel's warning stack (web
// `plex-server/plex-sync-status.ts`, `who-gets-4k.ts`).

public enum PlexSyncStatus {
    /// "just now" · "2 min ago" · "2 h ago" · "3 d ago" (API stamps are naive UTC).
    public static func shortAgo(_ iso: String?, now: Date = Date()) -> String {
        guard let then = ServerTime.parse(iso) else { return "" }
        let secs = max(0, Int((now.timeIntervalSince(then)).rounded()))
        if secs < 60 { return "just now" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) min ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs) h ago" }
        return "\(hrs / 24) d ago"
    }

    public struct Summary: Sendable, Hashable {
        public let never: Bool
        public let ago: String
        /// No complete sync for more than twice the interval.
        public let overdue: Bool
        public let hours: Int
    }

    public static func summary(lastSyncedAt: String?, hours: Int, now: Date = Date()) -> Summary {
        guard let lastSyncedAt, !lastSyncedAt.isEmpty else { return Summary(never: true, ago: "", overdue: false, hours: hours) }
        var overdue = false
        if let then = ServerTime.parse(lastSyncedAt) {
            overdue = now.timeIntervalSince(then) > Double(2 * hours * 3600)
        }
        return Summary(never: false, ago: shortAgo(lastSyncedAt, now: now), overdue: overdue, hours: hours)
    }

    public struct Note: Sendable, Hashable, Identifiable {
        public let code: String
        /// Neutral notes (not yet synced) get the clock in grey, the rest amber.
        public let neutral: Bool
        public let title: String
        public let sub: String
        public var id: String { code }
    }

    static let order = ["PlexAccessNoUhdLibraryCheck", "PlexAccessSyncCheck", "PlexLibraryDetectCheck", "access_not_synced"]

    static func sub(_ w: PlexAccessWarning, lastSync: String) -> String {
        if w.code == "PlexAccessSyncCheck", let attempts = w.attempts, attempts > 0 {
            let n = "\(attempts) attempt\(attempts == 1 ? "" : "s")"
            return "fusionha hasn't been able to read your Plex shares from plex.tv (\(n)). Plex-derived UHD·4K stays off until a sync succeeds — nobody's access changes."
        }
        switch w.code {
        case "PlexAccessNoUhdLibraryCheck":
            return "Plex users who aren't the owner or in Plex Home can only request HD·1080p until a library counts as 4K. It never widens on its own."
        case "PlexAccessSyncCheck":
            return "3 or more attempts in a row failed. Everyone keeps the access they had at the last complete sync\(lastSync.isEmpty ? "" : " (\(lastSync))")."
        case "PlexLibraryDetectCheck":
            return "3 or more attempts in a row failed. Every library keeps the 4K status it had at the last complete detection."
        case "access_not_synced":
            return "Until one completes, owner and Home users count as HD in the preview, and Plex-derived access can't be turned on."
        default:
            return ""
        }
    }

    /// The backend's warning codes → the panel's notes, most urgent first.
    public static func warningNotes(_ warnings: [PlexAccessWarning], lastSync: String) -> [Note] {
        func rank(_ code: String) -> Int { order.firstIndex(of: code) ?? order.count }
        return warnings.enumerated()
            .sorted { a, b in
                let ra = rank(a.element.code), rb = rank(b.element.code)
                return ra != rb ? ra < rb : a.offset < b.offset
            }
            .map { w in
                Note(code: w.element.code, neutral: w.element.code == "access_not_synced",
                     title: w.element.message, sub: sub(w.element, lastSync: lastSync))
            }
    }

    /// Whether the automatic sync is in failure backoff (the health warning).
    public static func backingOff(_ warnings: [PlexAccessWarning]) -> Bool {
        warnings.contains { $0.code == "PlexAccessSyncCheck" }
    }

    /// Why "Acknowledge and turn on" is blocked, derived only from the preview.
    public enum AckBlock: Sendable { case sync, noLibrary }

    public static func ackBlock(_ p: PlexAccessPreview) -> AckBlock? {
        if !p.synced { return .sync }
        if p.uhdLibraries.isEmpty { return .noLibrary }
        return nil
    }
}

// MARK: Who gets UHD·4K

public enum PlexBucketID: String, Sendable, Hashable, CaseIterable {
    case owner, admin, home, friend4k, managed, hdonly, frozen, manual, none

    public var label: String {
        switch self {
        case .owner: return "Plex server owner"
        case .admin: return "Admins"
        case .home: return "Plex Home members"
        case .friend4k: return "Friends sharing a 4K library"
        case .managed: return "Managed Home profiles"
        case .hdonly: return "HD only"
        case .frozen: return "Not linked to Plex"
        case .manual: return "Set by hand"
        case .none: return "No Plex account"
        }
    }

    /// The bucket's tint: UHD tier, HD tier, the accent or grey.
    public enum Tone: Sendable { case uhd, hd, accent, dim }

    public var tone: Tone {
        switch self {
        case .owner, .admin, .home, .friend4k: return .uhd
        case .managed: return .hd
        case .manual: return .accent
        case .hdonly, .frozen, .none: return .dim
        }
    }

    func sub(synced: Bool) -> String {
        switch self {
        case .owner, .admin, .home: return "Always UHD·4K"
        case .friend4k: return "UHD·4K through a share"
        case .managed: return "HD unless a 4K library is shared with them"
        case .hdonly: return synced ? "Plex users with no 4K library shared" : "Not fetched from Plex yet: counted as HD"
        case .frozen: return "Last value kept"
        case .manual: return "A user or role grant always wins"
        case .none: return "Unrestricted: all versions"
        }
    }
}

public struct PlexBucket: Sendable, Hashable, Identifiable {
    public struct Person: Sendable, Hashable, Identifiable {
        public let id: Int
        public let name: String
        public let uhd: Bool
    }
    public let id: PlexBucketID
    public let sub: String
    public let people: [Person]
}

public enum PlexWhoGets4K {
    /// Reads the as-if-active fields, so one grouping serves the preview and the live state.
    public static func bucket(_ row: UserTierAccess) -> PlexBucketID {
        if row.sourceWhenActive == "user" { return .manual }
        if row.sourceWhenActive != "plex" { return .none }
        if row.frozen { return .frozen }
        if row.isOwner { return .owner }
        if row.isAdmin { return .admin }
        if row.isHome { return .home }
        if row.isManaged { return .managed }
        return row.uhdWhenActive ? .friend4k : .hdonly
    }

    public static func group(_ rows: [UserTierAccess], names: [Int: String], synced: Bool) -> [PlexBucket] {
        var people: [PlexBucketID: [PlexBucket.Person]] = [:]
        for row in rows {
            people[bucket(row), default: []].append(
                PlexBucket.Person(id: row.userId, name: names[row.userId] ?? "Unknown user", uhd: row.uhdWhenActive))
        }
        return PlexBucketID.allCases.compactMap { id in
            guard let list = people[id] else { return nil }
            return PlexBucket(id: id, sub: id.sub(synced: synced), people: list)
        }
    }
}
