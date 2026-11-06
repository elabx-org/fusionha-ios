import Foundation

/// What one automatic search on a title page was started for. The control
/// that started it, and the row it acts on, show its state in place.
public enum SearchTarget: Hashable, Sendable {
    /// Every monitored version of the title.
    case title
    /// One version of the title (a movie's version card, or a focused version).
    case version(Int)
    /// Every version of one episode.
    case episode(Int)
    /// One version of one episode.
    case episodeVersion(episode: Int, version: Int)
    /// A whole season (Search season, Search each episode).
    case season(Int)
    /// A season's missing episodes, one at a time.
    case seasonMissing(Int)

    /// The episode this target is about, if it is one.
    public var episodeId: Int? {
        switch self {
        case .episode(let id), .episodeVersion(let id, _): return id
        default: return nil
        }
    }
}

/// A search's state where it was started: running, then its outcome for a
/// few seconds, then gone.
public enum SearchActivity: Equatable, Sendable {
    case searching
    /// The run grabbed this many releases (versions).
    case grabbed(Int)
    /// The run finished without grabbing anything.
    case nothingNew
    /// The request itself failed.
    case failed

    public var isSearching: Bool { self == .searching }

    /// The control's label while this lasts.
    public var label: String {
        switch self {
        case .searching: return "Searching…"
        case .grabbed(let n): return n > 1 ? "Grabbed \(n)" : "Grabbed"
        case .nothingNew: return "Nothing new"
        case .failed: return "Couldn't search"
        }
    }

    /// What VoiceOver announces.
    public var spoken: String {
        switch self {
        case .searching: return "Searching"
        case .grabbed(let n): return n > 1 ? "Grabbed \(n) releases" : "Grabbed a release"
        case .nothingNew: return "Search finished, nothing new"
        case .failed: return "Couldn't search"
        }
    }

    /// The SF Symbol for an outcome (searching shows a spinner instead).
    public var symbol: String {
        switch self {
        case .searching: return "magnifyingglass"
        case .grabbed: return "checkmark"
        case .nothingNew: return "minus"
        case .failed: return "exclamationmark.triangle"
        }
    }

    /// The outcome of a scoped search's decisions: nil = the request failed.
    public static func outcome(grabbed: Int?) -> SearchActivity {
        guard let grabbed else { return .failed }
        return grabbed > 0 ? .grabbed(grabbed) : .nothingNew
    }
}

/// The title page's searches, keyed by what each was started for. One run
/// per target at a time; an outcome is cleared only by the run that set it.
public struct SearchActivityBook: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public var activity: SearchActivity
        /// Which run wrote it, so a stale clear never wipes a newer run.
        public var token: Int
    }

    public private(set) var entries: [SearchTarget: Entry] = [:]
    private var nextToken = 0

    public init() {}

    public func activity(_ target: SearchTarget) -> SearchActivity? { entries[target]?.activity }

    public func isSearching(_ target: SearchTarget) -> Bool { activity(target)?.isSearching == true }

    /// The state to show for a place that covers several targets: a running
    /// search wins over an outcome.
    public func activity(any targets: [SearchTarget]) -> SearchActivity? {
        let found = targets.compactMap { activity($0) }
        return found.first(where: \.isSearching) ?? found.first
    }

    /// Every target about this episode (its own search and its versions').
    public func activity(episode id: Int) -> SearchActivity? {
        activity(any: entries.keys.filter { $0.episodeId == id }.sorted { "\($0)" < "\($1)" })
    }

    /// Starts a run: its token, or nil when one is already running there.
    public mutating func begin(_ target: SearchTarget) -> Int? {
        guard !isSearching(target) else { return nil }
        nextToken += 1
        entries[target] = Entry(activity: .searching, token: nextToken)
        return nextToken
    }

    /// The run's outcome, if the run still owns the target.
    public mutating func finish(_ target: SearchTarget, token: Int, _ outcome: SearchActivity) {
        guard entries[target]?.token == token else { return }
        entries[target] = Entry(activity: outcome, token: token)
    }

    /// Back to normal after the outcome has shown, if the run still owns it.
    public mutating func clear(_ target: SearchTarget, token: Int) {
        guard let entry = entries[target], entry.token == token, !entry.activity.isSearching else { return }
        entries[target] = nil
    }
}
