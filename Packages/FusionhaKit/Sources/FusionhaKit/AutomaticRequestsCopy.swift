import Foundation

// The words of Account › Automatic requests and the Watchlists & lists page
// (web `automatic-copy.ts`, `lists-copy.ts`, `status-words.ts`,
// `detail-copy.ts`, fusionha 0.4.226).

extension AutoSourceState {
    /// The one word after the dot (web `STATE_WORD`).
    public var word: String {
        switch self {
        case .healthy: return "Healthy"
        case .checking: return "Checking"
        case .syncing: return "Syncing"
        case .partlyWorking: return "Partly working"
        case .notPublic: return "Not public"
        case .blocked: return "Blocked"
        case .retrying: return "Retrying"
        case .needsSignIn: return "Sign in again"
        case .notAllowed: return "Not allowed"
        case .paused: return "Paused"
        case .off: return "Off"
        case .gone: return "Deleted on Plex"
        case .notConnected: return "Not connected"
        }
    }

    /// The dot's and wash's status (web `STATE_TOKEN`); nil = the quiet `dim`.
    public var tone: MonoToken? {
        switch self {
        case .healthy: return .done
        case .syncing, .checking: return .grab
        case .partlyWorking, .notPublic, .needsSignIn: return .miss
        case .retrying: return .stuck
        case .blocked: return .danger
        case .notAllowed, .paused, .off, .notConnected, .gone: return nil
        }
    }

    /// Not checking at all: the state line reads paused (web `IDLE_PAUSED`).
    public var idle: Bool {
        [.paused, .off, .notAllowed, .notConnected, .needsSignIn, .gone].contains(self)
    }

    /// The paused line's words for states that are not a sync (web `PAUSED_TEXT`).
    public var pausedText: String? {
        switch self {
        case .off: return "Turned off"
        case .notAllowed: return "An admin has to allow this first"
        case .notConnected: return "Not connected"
        case .needsSignIn: return "Sign in with Plex again"
        case .gone: return "Deleted on Plex"
        default: return nil
        }
    }

    /// Sync now does nothing for it (the server leaves paused and off sources out).
    public var skipsSync: Bool { [.paused, .off, .notAllowed, .notConnected, .gone].contains(self) }
}

public enum AutomaticRequestsCopy {
    public static let title = "Watchlists & lists"
    public static let rowTitle = "Automatic requests"
    public static let sub = "Requests made for you from your watchlists and the lists you follow."
    public static let syncNow = "Sync now"
    public static let syncSource = "Sync this source"
    public static let follow = "Follow a list"
    public static let badSource = "That source isn’t yours or is gone"
    public static let unavailable = "Automatic requests aren’t available for your account"
    public static let loadFailed = "Couldn’t load your lists. Try again in a moment."
    public static let rowFailed = "Couldn’t load your automatic requests."
    public static let loading = "Loading your lists"
    public static let syncFailed = "That didn’t work. Try again in a moment."
    public static let rateLimited = "You can check again in a moment."
    public static let followRow = "Follow someone’s watchlist or a list"
    public static let importRow = "One-time import"
    public static let setUp = "Set up"

    /// The Account row's line under "Automatic requests" (web `summaryLine`;
    /// iOS reads "Set up" where the web card says "Not set up · …").
    public struct RowLine: Equatable, Sendable {
        public enum Kind: Sendable { case active, syncing, fresh }
        public let kind: Kind
        /// The plain part ("9 requested this week", "Syncing 140 of 250… · 4 requested so far").
        public let text: String
        /// The amber part ("1 needs review"), shown after " · ".
        public let review: String?

        public var plain: String { [text, review].compactMap { $0 }.joined(separator: " · ") }
    }

    /// No source is on anywhere and nothing is syncing (web `isFresh`).
    public static func isFresh(_ s: AutoSummary) -> Bool {
        s.syncing == nil && s.sources.allSatisfy { $0.state == .off || $0.state == .notConnected }
    }

    public static func rowLine(_ s: AutoSummary) -> RowLine {
        if let sync = s.syncing {
            return RowLine(kind: .syncing, text: "Syncing \(sync.done) of \(sync.total)… · \(sync.requested) requested so far", review: nil)
        }
        if isFresh(s) { return RowLine(kind: .fresh, text: setUp, review: nil) }
        let review = s.needsReview > 0 ? "\(s.needsReview) \(s.needsReview == 1 ? "needs" : "need") review" : nil
        return RowLine(kind: .active, text: "\(s.requestedLast7d) requested this week", review: review)
    }

    /// The group headers, in page order (web `SourceList` TITLE).
    public static func groupTitle(_ g: AutoSourceGroup) -> String {
        switch g {
        case .letterboxd: return "Letterboxd"
        case .plex: return "Plex"
        case .lists: return "Followed lists"
        }
    }

    /// The web's `syncDoneToast(summary.sources.length, added)`, word for word.
    public static func syncDone(sources: Int, added: Int) -> String {
        PlexWatchlistCopy.syncDone(lists: sources, added: added)
    }

    /// A Sync now error: 429 waits, a paused source says so, else the fallback.
    public static func syncError(_ error: Error) -> String {
        let api = error as? APIError
        if case .http(429, _)? = api { return rateLimited }
        if api?.code == "source_paused" { return "This source is paused. Resume it to sync." }
        return syncFailed
    }
}

/// The source detail's sentences (web `DETAIL`).
public enum SourceDetailCopy {
    public static let review = "Review"
    public static let options = "Options"
    public static let manage = "Pause or remove"
    public static let neverCancels = "Pausing or removing never cancels a request."
    public static let pause = "Pause"
    public static let resume = "Resume"
    public static let removeDesc = "You’ll be asked to confirm."
    public static let pauseDesc = "Stops checking; counts are kept."
    public static let resumeDesc = "Checking is paused; counts are kept."
    public static let pausedByAdmin = "Paused by an admin"
    public static let pausedWithWatchlist = "Paused with your Plex watchlist"
    public static let turnedOff = "Turned off. Turn it on under Options to check it again."
    public static let remove = "Remove"
    public static let removeLabel = "Remove this source"
    public static let disconnectNote = "This disconnects your Letterboxd: diary and watchlist stop syncing. Requests already made stay."
    public static let removeRest = "fusionha stops following it and forgets what it has seen. Nothing already requested is cancelled."
    public static let keep = "Keep it"
    public static let removed = "Removed. Nothing already requested is affected."
    public static let failed = "That didn’t work. Try again in a moment."
    public static let privateLead = "This list isn’t public any more."
    public static let privateRest = "Set it to public on Letterboxd to keep it in sync. Counts are from the last check."
    public static let openOn = "Open on Letterboxd"
    public static let uhd = "Also request UHD·4K"
    public static let uhdInherits = "Also request UHD·4K: uses your diary setting"
    public static let uhdDesc = "Each tier is its own request."
    public static let uhdOff = "Not available: your account can request HD·1080p only"
    public static let startedOn = "What was on it when you started"
    public static let startedDiary = "When you started"
    public static let newOnly = "Only new additions"
    public static let newOnlyDiary = "Only new entries"
    public static let existing = "Also request what’s on it"
    public static let existingDiary = "Also request my recent entries"
    public static let diarySwitch = "Request films from my diary"
    public static let diaryDesc = "New entries are requested on their own."
    public static let rewatches = "Request rewatches"
    public static let rewatchesDesc = "Off: a rewatch is skipped."
    public static let followWatchlist = "Follow my public watchlist"
    public static let followWatchlistDesc = "Read about every 12 hours. Best effort: Letterboxd can block this."
    public static let autoList = "Auto-request from this list"
    public static let plexWatchlist = "Request from my Plex watchlist"
    public static let plexList = "Request from this list"
    public static let signInPlex = "Sign in with Plex"

    public static func removeAsk(_ name: String) -> String { "Remove \(name)?" }

    public static func noted(_ n: Int, diary: Bool) -> String {
        diary ? "\(n) entries noted and left alone" : "\(n) noted and left alone"
    }

    /// "1 film couldn’t be matched" / "3 titles couldn’t be matched".
    public static func unmatched(_ n: Int, film: Bool) -> String {
        let noun = film ? "film" : "title"
        return "\(n) \(noun)\(n == 1 ? "" : "s") couldn’t be matched"
    }

    /// A pause or resume refused: an admin's pause gets its own plain words.
    public static func pauseError(_ error: Error, resuming: Bool) -> String {
        if resuming, case .http(403, _)? = error as? APIError {
            return "An admin paused this source, so only an admin can resume it."
        }
        return failed
    }

    /// The baseline picker's value for a read's `baseline` (`EXISTING`/`existing`).
    public static func baseline(_ raw: String?) -> String {
        raw?.lowercased() == "existing" ? "existing" : "new"
    }
}

/// The Follow a list sheet (web `follow-copy.ts`).
public enum FollowCopy {
    public static let title = "Follow a list"
    public static let follow = "Follow"

    public static func linkedAfter(_ n: Int, max: Int) -> String { "\(n) of \(max) linked after this" }

    public static func following(_ label: String) -> String { "Following \(label). Its first check starts now." }
}

/// Admin-only remembered matches (web `REMEMBERED`).
public enum RememberedCopy {
    public static let title = "Remembered matches"
    public static let desc = "Titles an admin matched by hand. Every check reuses them until you forget one."
    public static let forget = "Forget this match"
    public static let ask = "Forget? The next check looks it up again. Nothing already requested changes."
    public static let yes = "Forget"
    public static let keep = "Keep"
    public static let none = "Nothing is remembered."
    public static let plexItem = "Plex item"

    public static func link(_ n: Int) -> String { "Remembered matches · \(n)" }

    /// "→ Primal (2019)".
    public static func into(_ m: ListMatch) -> String {
        "→ \(m.title ?? "TMDB \(m.tmdbId)")\(m.year.map { " (\($0))" } ?? "")"
    }

    public static func entry(_ m: ListMatch) -> String {
        m.isPlex && m.entryUrl == nil ? plexItem : m.externalKey
    }

    public static func who(_ m: ListMatch) -> String {
        m.resolvedBy.map { "chosen by @\($0)" } ?? "chosen"
    }
}
