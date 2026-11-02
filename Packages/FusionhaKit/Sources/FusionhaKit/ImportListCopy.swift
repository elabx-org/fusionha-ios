import Foundation

/// Words and small formatters of the import lists surfaces, Settings and
/// Tasks (web `import-list-format.ts`, `preview-problem.ts`,
/// `import-lists-card-format.ts`, fusionha 0.4.237).
public enum ImportListCopy {
    public static let title = "Import lists"
    public static let add = "Add import list"
    public static let edit = "Edit import list"
    public static let formDesc = "Titles on this list are added to the library on a schedule."
    public static let adminLead = "Admin only."
    public static let adminRest = "Each new title on a list is added through the same Add path as Add title: one version per tier you pick, with its root folder and quality profile from Default Profiles. Excluded titles and Discover ignores are skipped. People’s own watchlists and followed lists live in their Account and make requests instead."
    public static let empty = "No import lists yet. Add a public MDBList, Trakt or Letterboxd list to fill your library from it."
    public static let noPermission = "You need permission to manage integrations to see import lists."
    public static let demo = "Import lists are not available in the demo."
    public static let maxAdd = "Add at most per sync"
    public static let maxAddDesc = "The rest wait for the next check, so a long list doesn’t start hundreds of searches at once. Applies to every import list."
    public static let addressPlaceholder = "Paste a public MDBList, Trakt or Letterboxd list"
    public static let versionsTitle = "Versions to create"
    public static let versionsHint = "Each tier is a separate version with its own folder, profile and downloads. A better 1080p release never competes with 4K."
    public static let fromDefaults = "From Default Profiles"
    public static let monitored = "Monitored"
    public static let monitoredDesc = "New versions are monitored, so the scheduled search looks for them."
    public static let searchOnAdd = "Search on add"
    public static let searchOnAddDesc = "Search right away for each added title. Off: the scheduled search picks them up."
    public static let checkEvery = "Check every"
    public static let letterboxdEvery = "Letterboxd lists are read at most every 12 hours"
    public static let neverDeletes = "Removing a list never deletes anything it added."
    public static let deleteDesc = "Removing a list never deletes anything it added. The titles stay in your library."
    public static let saveFailed = "Couldn’t save. Try again."
    public static let syncLimited = "Try again in a minute"
    public static let syncFailed = "Couldn’t start a check. Try again."
    public static let deleteFailed = "Couldn’t delete. Try again."
    public static let exclusionsDesc = "Titles that import lists never add. An exclusion can cover every list or just one."
    public static let noExclusions = "No exclusions here yet."
    public static let ignoresDesc = "Titles hidden in Discover are skipped by every import list too. They’re managed in Discover."
    public static let noRuns = "This list hasn’t run yet."
    public static let noRunItems = "No titles were recorded for this run."
    public static let reviewTitle = "Pick the right title"
    public static let nothingLeft = "Nothing left to review."
    /// A failed read is said, never shown as an empty list.
    public static let unmatchedFailed = "Couldn’t load the titles to review."
    public static let runsFailed = "Couldn’t load this list’s runs."
    public static let runItemsFailed = "Couldn’t load this run’s titles."

    public static let intervalPresets = [6, 12, 24, 168]
    public static let maxAddPresets = [10, 25, 50, 100]
    /// Letterboxd is read at most every 12 hours (`interval_too_short`).
    public static let letterboxdMinHours = 12

    public static func kindWord(_ kind: String) -> String {
        switch kind {
        case "movie": return "Movies"
        case "series": return "Series"
        case "anime": return "Anime"
        default: return kind.capitalized
        }
    }

    public static func kindHint(_ kind: ImportListMediaKind) -> String {
        switch kind {
        case .movie: return "Only movies on the list are added."
        case .series: return "Only series on the list are added."
        case .anime: return "Anime adds both the movies and the series on the list."
        }
    }

    /// 6 → "6 h"; a whole number of days → "7 days" (24 → "24 h").
    public static func every(_ hours: Int) -> String {
        if hours > 24, hours % 24 == 0 { return "\(hours / 24) days" }
        return "\(hours) h"
    }

    /// The row pill (web `statusLook`): word and tone (nil = `dim`).
    public static func status(_ list: ImportList) -> (word: String, tone: MonoToken?) {
        guard list.enabled else { return ("Paused", nil) }
        switch list.status {
        case "OK": return ("Healthy", .done)
        case "DEGRADED": return ("Partly working", .miss)
        case "PRIVATE": return ("Can’t read", .miss)
        case "ERROR": return ("Error", .danger)
        case "BLOCKED": return ("Blocked", .stuck)
        case "UNAVAILABLE": return ("Not set up", nil)
        case "PENDING": return ("First sync pending", .grab)
        default: return (list.status.capitalized, nil)
        }
    }

    /// "last sync added 3 · 2 hr ago", or "not checked yet".
    public static func lastSync(_ list: ImportList, now: Date = Date()) -> String {
        guard let at = list.lastCheckedAt else { return "not checked yet" }
        return "last sync added \(list.lastRun?.counts.added ?? 0) · \(WatchlistTime.lastRun(at, now: now))"
    }

    /// "MDBList · every 6 h · last sync added 3 · 2 hr ago".
    public static func meta(_ list: ImportList, now: Date = Date()) -> String {
        [list.site.word, "every \(every(list.intervalHours))", lastSync(list, now: now)].joined(separator: " · ")
    }

    /// "2 titles couldn’t be matched".
    public static func unmatched(_ n: Int) -> String { "\(n) \(n == 1 ? "title" : "titles") couldn’t be matched" }

    public static func deleteAsk(_ name: String) -> String { "Delete \(name)?" }
    public static func checking(_ name: String) -> String { "Checking \(name) now" }

    /// A run item's outcome word and tone (web `OUTCOME_LOOK`).
    public static func outcome(_ raw: String) -> (word: String, tone: MonoToken?) {
        switch raw {
        case "ADDED": return ("Added", .done)
        case "QUEUED": return ("Queued", .grab)
        case "OWNED": return ("Already in library", nil)
        case "EXCLUDED": return ("Excluded", nil)
        case "IGNORED": return ("Ignored", nil)
        case "UNMATCHED": return ("Unmatched", .miss)
        case "SKIPPED_KIND": return ("Skipped", .stuck)
        default: return (raw.capitalized, nil)
        }
    }

    /// One part of the run bar.
    public struct Segment: Hashable, Sendable {
        public let outcome: String
        public let count: Int
    }

    /// The run bar's segments in order.
    public static func segments(_ c: ImportListRunCounts) -> [Segment] {
        [Segment(outcome: "ADDED", count: c.added), Segment(outcome: "OWNED", count: c.owned),
         Segment(outcome: "EXCLUDED", count: c.excluded), Segment(outcome: "UNMATCHED", count: c.unmatched),
         Segment(outcome: "SKIPPED_KIND", count: c.skippedKind), Segment(outcome: "QUEUED", count: c.queued)]
    }

    /// Finished, Failed or Running.
    public static func runState(_ run: ImportListRun) -> (word: String, tone: MonoToken?) {
        if run.error != nil { return ("Failed", .danger) }
        return run.finishedAt != nil ? ("Finished", .done) : ("Running", .grab)
    }

    /// "1.2 s · 17 read", or nil while running.
    public static func runDuration(_ run: ImportListRun) -> String? {
        guard let start = ServerTime.parse(run.startedAt), let end = ServerTime.parse(run.finishedAt) else { return nil }
        return String(format: "%.1f s · %d read", end.timeIntervalSince(start), run.counts.total)
    }

    /// "added 3 · 12 in library · 1 excluded" (a closed run's line).
    public static func runLine(_ c: ImportListRunCounts) -> String {
        "added \(c.added) · \(c.owned) in library · \(c.excluded) excluded"
    }

    public static func reason(_ raw: String?) -> String {
        switch raw {
        case "no_match": return "No title on TMDB matched."
        case "ambiguous": return "More than one title matched."
        case "no_year": return "The list gave no year to tell titles apart."
        default: return "It couldn’t be matched."
        }
    }

    /// "1 title from X couldn’t be matched. Choose what each is, or ignore it."
    public static func reviewDesc(_ n: Int, list: String) -> String {
        "\(n == 1 ? "1 title" : "\(n) titles") from \(list) couldn’t be matched. Choose what each is, or ignore it."
    }

    public static func titleWithYear(_ title: String?, _ year: Int?) -> String {
        "\(title ?? "Untitled")\(year.map { " (\($0))" } ?? "")"
    }

    /// A failed address preview (web `previewProblem`): nil for a 429 (it
    /// retries quietly). `fatal` keeps Save off; `traktLink` points at
    /// Settings › Indexers.
    public struct Problem: Equatable, Sendable {
        public let text: String
        public let fatal: Bool
        public var traktLink = false
    }

    public static func problem(_ error: Error) -> Problem? {
        switch (error as? APIError)?.code {
        case "rate_limited": return nil
        case "unsupported_site":
            return Problem(text: "fusionha can’t follow that address. Paste a public list from MDBList, Trakt or Letterboxd.", fatal: true)
        case "coming_later": return Problem(text: "That kind of address isn’t supported yet. It’s coming later.", fatal: true)
        case "provider_unavailable": return Problem(text: "Trakt isn’t set up on this server", fatal: true, traktLink: true)
        case "source_unreadable": return Problem(text: "That list isn’t public", fatal: true)
        case "unavailable": return Problem(text: "fusionha can’t reach that site right now. Try again in a moment.", fatal: false)
        default:
            if case .http(429, _)? = error as? APIError { return nil }
            return Problem(text: "Couldn’t read that address. Check it and try again.", fatal: false)
        }
    }

    /// A refused save, add or review (web `e.message`): the server's own
    /// sentence for a coded refusal (`{"detail": {"code", "detail"}}`), else
    /// `fallback`. The admin panel shows these as the web does.
    public static func serverMessage(_ error: Error, fallback: String = saveFailed) -> String {
        guard case .http(_, let body)? = error as? APIError,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any] else { return fallback }
        if let text = object["detail"] as? String { return text }
        if let detail = object["detail"] as? [String: Any] {
            return (detail["message"] as? String) ?? (detail["detail"] as? String) ?? fallback
        }
        return fallback
    }

    /// Tasks card row (web `ListRow`): `Checking`, `Error` or `OK`.
    public static func rowState(_ raw: String) -> (word: String, tone: MonoToken) {
        switch raw {
        case "running": return ("Checking", .grab)
        case "error": return ("Error", .danger)
        default: return ("OK", .done)
        }
    }

    /// "MDBList · Movies".
    public static func kindLine(provider: String, mediaKind: String) -> String {
        "\(SourceProvider(feed: provider).word) · \(kindWord(mediaKind))"
    }
}
