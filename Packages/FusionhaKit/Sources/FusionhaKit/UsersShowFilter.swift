import Foundation

/// The Users list's "All · Plex · Watchlist · Letterboxd" filter (web
/// `UsersShowFilter` + `users-source-chips.ts`, fusionha 0.4.209 Q27 and
/// 0.4.213 Q31).
public enum UsersShowFilter: String, CaseIterable, Sendable, Hashable {
    case all, plex, watchlist, letterboxd

    public var label: String {
        switch self {
        case .all: return "All"
        case .plex: return "Plex"
        case .watchlist: return "Watchlist"
        case .letterboxd: return "Letterboxd"
        }
    }

    /// The Plex summary states the "Watchlist" filter keeps: granted Plex users.
    public static let watchlistStates: Set<String> = ["healthy", "checking", "needs_sign_in", "token_invalid",
                                                      "error", "paused", "allowed_off"]

    public func passes(_ u: UserAccount, plex: PlexWatchlistSummaryRow?, letterboxd: LetterboxdSummaryRow?) -> Bool {
        switch self {
        case .all: return true
        case .plex: return u.authProvider == "plex"
        case .watchlist: return plex.map { Self.watchlistStates.contains($0.state) } ?? false
        case .letterboxd: return letterboxd.map { $0.state != "not_connected" } ?? false
        }
    }
}

extension SourceAdminCopy {
    /// The Users-list Letterboxd chip's hint: "3 requested · 2 sources", or
    /// nil before anything was requested.
    public static func letterboxdHint(_ row: LetterboxdSummaryRow) -> String? {
        guard row.requestedCount > 0 else { return nil }
        let n = row.linkedCount + (row.diaryEnabled ? 1 : 0)
        return "\(row.requestedCount) requested · \(n) source\(n == 1 ? "" : "s")"
    }
}
