import Foundation

/// Which state the Plex watchlist card is in (web `watchlist-copy.ts` `cardState`).
public enum PlexWatchlistState: String, Sendable, CaseIterable {
    case notPlexUser = "not_plex_user"
    case notGranted = "not_granted"
    case ineligible
    case needsSignIn = "needs_sign_in"
    case off, on, error
    case tokenInvalid = "token_invalid"
    case disabled

    public init(_ read: PlexWatchlistRead) {
        guard let reason = read.reason else {
            self = read.enabled ? .on : .off
            return
        }
        // An unknown future reason reads as an error (the iOS contract).
        if let known = PlexWatchlistState(rawValue: reason), known != .on, known != .off {
            self = known
        } else {
            self = .error
        }
    }

    /// The pill and the line under the title (web `META`).
    public var label: String {
        switch self {
        case .notPlexUser: return "Not available"
        case .notGranted, .ineligible: return "Not allowed"
        case .needsSignIn: return "Needs sign-in"
        case .off: return "Off"
        case .on: return "Active"
        case .tokenInvalid: return "Sign-in expired"
        case .error: return "Retrying"
        case .disabled: return "Paused by admin"
        }
    }

    public var sub: String {
        switch self {
        case .notPlexUser: return "Needs a Plex sign-in"
        case .notGranted, .ineligible: return "An admin has to allow this first"
        case .needsSignIn: return "One more Plex sign-in to connect"
        case .off: return "Auto-request what you add to your Plex watchlist or lists"
        case .on: return "Watching your watchlist and lists"
        case .tokenInvalid: return "Plex needs you to sign in again"
        case .error: return "fusionha will try again on its own"
        case .disabled: return "Your admin paused watchlist requests"
        }
    }

    /// The states with the master switch (web `SWITCHABLE`).
    public var switchable: Bool {
        [.off, .on, .needsSignIn, .tokenInvalid, .error].contains(self)
    }
}

/// Every sentence of the Plex card that depends on numbers (web `watchlist-copy.ts`).
public enum PlexWatchlistCopy {
    public static let visibility: [String: String] = [
        "PUBLIC": "Public",
        "PLEX_USERS": "Anyone signed into Plex",
        "FRIENDS_OF_FRIENDS": "Friends of Friends",
        "FRIENDS": "Friends only",
        "PRIVATE": "Private",
    ]

    static func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        "\(n) \(n == 1 ? one : (many ?? one + "s"))"
    }

    public static func firstCheck(_ fc: PlexWatchlistFirstCheck) -> String {
        if fc.baseline == "NEW" {
            let verb = fc.baselineCount == 1 ? "was" : "were"
            return "\(plural(fc.baselineCount, "title was", "titles were")) already on your watchlist and \(verb) left alone. From now on, new additions are requested."
        }
        let rest = fc.remaining > 0
            ? " \(fc.remaining) more will be requested over the next checks, a few at a time." : ""
        return "\(plural(fc.requestedCount, "title")) requested now.\(rest)"
    }

    public static func watchlistHint(_ read: PlexWatchlistRead) -> String? {
        guard let count = read.itemCount else { return nil }
        let base = read.baselineCount
        guard base > 0 else { return "\(plural(count, "title")) on your watchlist" }
        let was = base == 1 ? "was" : "were"
        let isAre = base == 1 ? "is" : "are"
        return "\(plural(count, "title")) on your watchlist · \(base) \(was) there before you turned this on and \(isAre) left alone"
    }

    public static func syncDone(lists: Int, added: Int) -> String {
        let place = lists > 0 ? "your watchlist and \(plural(lists, "list"))" : "your watchlist"
        return "Checked \(place) · \(added) new \(added == 1 ? "title" : "titles") requested"
    }

    public static func checkNowSub(lists: Int) -> String {
        let place = lists > 0 ? " and \(plural(lists, "list"))" : ""
        return "Checks your watchlist\(place) right away. Once a minute at most."
    }

    public static func listOnToast(_ name: String, existing: Bool) -> String {
        existing ? "\(name) on · requesting what’s on it, a few at a time" : "\(name) on · only new additions"
    }
}

/// The web's coarse server-time words (`lib/server-time.ts`).
public enum WatchlistTime {
    /// "just now", "5 min ago", "3 hr ago", "2 days ago"; `Never` without a time.
    public static func lastRun(_ iso: String?, now: Date = Date()) -> String {
        guard let iso else { return "Never" }
        guard let then = ServerTime.parse(iso) else { return "—" }
        let secs = max(0, Int(now.timeIntervalSince(then).rounded()))
        if secs < 45 { return "just now" }
        if secs < 3600 { return "\(Int((Double(secs) / 60).rounded())) min ago" }
        if secs < 86_400 { return "\(Int((Double(secs) / 3600).rounded())) hr ago" }
        let d = Int((Double(secs) / 86_400).rounded())
        return "\(d) day\(d == 1 ? "" : "s") ago"
    }

    /// "in 6 min", "in 2 hr", "soon" once due, `—` without a time.
    public static func until(_ iso: String?, now: Date = Date()) -> String {
        guard let iso, let then = ServerTime.parse(iso) else { return "—" }
        let secs = Int(then.timeIntervalSince(now).rounded())
        if secs < 45 { return "soon" }
        if secs < 3600 { return "in \(Int((Double(secs) / 60).rounded())) min" }
        if secs < 86_400 { return "in \(Int((Double(secs) / 3600).rounded())) hr" }
        let d = Int((Double(secs) / 86_400).rounded())
        return "in \(d) day\(d == 1 ? "" : "s")"
    }

    /// Whole seconds until `iso` (0 once passed or without a time): a cooldown.
    public static func secondsLeft(_ iso: String?, now: Date = Date()) -> Int {
        guard let iso, let then = ServerTime.parse(iso) else { return 0 }
        return max(0, Int(then.timeIntervalSince(now).rounded(.up)))
    }
}
