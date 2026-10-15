import Foundation

/// A request's per-version lifecycle on its card (web `lifecycle.ts`,
/// `labels.ts`, `RequestStatusLine.tsx`): which version leads, the five-stop
/// stepper, the status line under it, the wash, and what the requester may
/// do. Pure, so the rules are tested.
public enum RequestLifecycle {
    public typealias Entry = RequestLifecycleEntry
    public typealias Step = RequestLifecycleEntry.Step

    /// The five stops; `unreleased` and `paused` sit on Searching.
    public static let steps = ["Requested", "Approved", "Searching", "Downloading", "Available"]

    public static func stopIndex(_ step: Step) -> Int {
        switch step {
        case .requested, .declined, .deferred, .withdrawn, .removed: return 0
        case .approved: return 1
        case .searching, .unreleased, .paused: return 2
        case .downloading: return 3
        case .available: return 4
        }
    }

    private static func rank(_ e: Entry) -> Double {
        switch e.step {
        case .declined, .deferred, .withdrawn, .removed: return -1
        case .requested: return 0
        case .approved: return 1
        case .paused, .unreleased: return 2
        case .searching: return 3
        case .downloading: return e.importing ? 4.5 : 4
        case .available: return 5
        }
    }

    /// The most advanced version leads the card; a tie goes to more progress.
    public static func lead(_ lifecycle: [Entry]) -> Entry? {
        var best: Entry?
        for e in lifecycle {
            guard let b = best else { best = e; continue }
            let diff = rank(e) - rank(b)
            if diff > 0 || (diff == 0 && (e.progressPct ?? -1) > (b.progressPct ?? -1)) { best = e }
        }
        return best
    }

    /// Every other tracked version (each is independent: a stuck 4K never hides behind an available HD).
    public static func lagging(_ lifecycle: [Entry], lead: Entry?) -> [Entry] {
        guard let lead, let i = lifecycle.firstIndex(of: lead) else { return [] }
        var rest = lifecycle
        rest.remove(at: i)
        return rest
    }

    public static func stepWord(_ e: Entry) -> String {
        if e.step == .downloading && e.importing { return "importing" }
        switch e.step {
        case .unreleased: return "waiting for release"
        case .deferred: return "not available yet"
        default: return e.step.rawValue
        }
    }

    /// A held version always says why: "needs a manual import".
    public static func versionWord(_ e: Entry) -> String {
        e.needsManualImport ? "needs a manual import" : stepWord(e)
    }

    /// The stepper's label for stop `i`: "Auto-approved" on Approved for an
    /// automatic approval, "Waiting" on Searching while unreleased,
    /// "Importing" on Downloading once the transfer is done.
    public static func stopLabel(_ i: Int, entry: Entry, auto: Bool) -> String {
        if i == 1 && auto { return "Auto-approved" }
        if i == 2 && entry.step == .unreleased { return "Waiting" }
        if i == 3 && entry.step == .downloading && entry.importing { return "Importing" }
        return steps[i]
    }

    /// The colour role of one stop.
    public enum Tone: Sendable, Hashable { case done, unaired, dim, mut, accent, grab, attention, danger, waiting, none }

    public static func stopTone(_ i: Int, entry: Entry) -> Tone {
        if entry.needsManualImport { return .attention }
        let stop = stopIndex(entry.step)
        if entry.step == .available { return .done }
        if entry.step == .unreleased && i == 2 { return .unaired }
        if entry.step == .paused && i == 2 { return .dim }
        if i == 0 && i < stop { return .mut }
        return i <= 1 ? .accent : .grab
    }

    /// The card's ambient wash: declined red, deferred amber, waiting for
    /// quota amber, withdrawn none, a held version amber, done green only
    /// when every version is in, else the still-moving version's colour.
    public static func wash(status: String, lifecycle: [Entry]) -> Tone {
        switch status {
        case "rejected": return .danger
        case "deferred": return .attention
        case "waiting": return .waiting
        case "withdrawn": return .none
        default: break
        }
        if lifecycle.contains(where: \.needsManualImport) { return .attention }
        if status == "fulfilled" || (!lifecycle.isEmpty && lifecycle.allSatisfy { $0.step == .available }) { return .done }
        let pending = lead(lifecycle.filter { $0.step != .available })
        switch pending?.step {
        case .unreleased: return .unaired
        case .searching, .downloading: return .grab
        case .approved: return .accent
        default: return .dim
        }
    }

    /// The viewer joined this row ("Me too") and does not own it.
    public static func isJoinedView(_ r: MediaRequest, viewerId: Int?) -> Bool {
        r.demand?.joinedByMe == true && r.userId != viewerId
    }

    /// A still-open ask may be withdrawn; a joiner leaves instead.
    public static func canWithdraw(_ r: MediaRequest, lead: Entry?, viewerId: Int?) -> Bool {
        if isJoinedView(r, viewerId: viewerId) { return false }
        switch r.status {
        case "waiting", "pending", "deferred": return true
        case "approved": return lead?.step != .available
        default: return false
        }
    }

    /// "Movie", "Series · S1", "Series · S1–S3".
    public static func kindLabel(_ r: MediaRequest) -> String {
        guard r.kind == .series else { return "Movie" }
        let seasons = (r.seasons ?? []).sorted()
        guard let first = seasons.first, let last = seasons.last else { return "Series" }
        return first == last ? "Series · S\(first)" : "Series · S\(first)–S\(last)"
    }

    public static func reasonLabel(_ reason: String?) -> String? {
        switch reason {
        case "not_available_yet": return "Not available yet"
        case "over_quota": return "Over quota"
        case "not_for_this_library": return "Not for this library"
        case "other": return "Other"
        default: return nil
        }
    }

    public static func sourceText(_ source: RequestSource?) -> String {
        guard let source, source.kind != "MANUAL" else { return "Requested in fusionha" }
        let labels = ["PLEX_WATCHLIST": "Plex watchlist", "LIST_FEED": "List", "LETTERBOXD_LIST": "Letterboxd list",
                      "LETTERBOXD_RSS": "Letterboxd diary", "LETTERBOXD_CSV": "Letterboxd watchlist"]
        let base = labels[source.kind] ?? source.kind
        return source.label.map { "\(base) · \($0)" } ?? base
    }

    /// "Auto-approved · rule: Under 20 GB".
    public static func autoText(_ by: RequestApprovedBy) -> String {
        ["Auto-approved", by.rule.map { "rule: \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    /// The lead version's status line (web `RequestStatusLine`).
    public enum StatusLine: Sendable, Hashable {
        case attention(String)
        case progress(Int?)
        case plain(String, icon: String?)
        case unreleased(days: Int?)
        case done(String)
    }

    public static func statusLine(_ r: MediaRequest, lead e: Entry, lagging: [Entry], now: Date = Date()) -> StatusLine? {
        switch e.step {
        case .downloading:
            if e.needsManualImport { return .attention("Needs a manual import · an admin will finish it") }
            if e.importing { return .plain("Importing the file…", icon: nil) }
            return .progress(e.progressPct)
        case .searching:
            if let next = e.nextRetryAt, let at = ServerTime.parse(next) {
                return .plain("Searching · next try \(relativeFuture(at, now: now))", icon: "magnifyingglass")
            }
            return .plain("Searching indexers", icon: "magnifyingglass")
        case .unreleased:
            return .unreleased(days: e.availableFrom.map { daysUntil($0, now: now) })
        case .requested:
            return .plain("Waiting for an admin", icon: "clock")
        case .approved:
            return .plain("Approved · the first search starts shortly", icon: nil)
        case .available:
            let tiers = (r.lifecycle ?? []).filter { $0.step == .available }.map(\.tier.chipLabel)
            let held = lagging.contains(where: \.needsManualImport)
            return .done("In your library · \(tiers.joined(separator: " and "))\(held ? " · needs a manual import" : "")")
        case .paused:
            return .plain("Paused · an admin stopped searching for this version", icon: nil)
        case .removed:
            return .plain("Removed · an admin deleted this version", icon: nil)
        default:
            return nil
        }
    }

    /// Days until a `YYYY-MM-DD`, from local midnight; never negative.
    public static func daysUntil(_ isoDay: String, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        guard let target = f.date(from: isoDay) else { return 0 }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: target)).day ?? 0
        return max(0, days)
    }

    /// "in 12 min", "in 3 h", "now".
    public static func relativeFuture(_ date: Date, now: Date = Date()) -> String {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded())
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "in \(minutes) min" }
        return "in \(Int((Double(minutes) / 60).rounded())) h"
    }

    /// The weekday a quota resets on ("Monday"), local time.
    public static func resetWeekday(_ iso: String?) -> String? {
        guard let iso, let date = ServerTime.parse(iso) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }
}
