import Foundation

/// Activity › Tasks › System › "Watchlists & lists" (fusionha 0.4.215, web
/// `routes/tasks/watchlists/`): the admin rollup's words, tones and counts.
public enum WatchlistsTaskLogic {
    /// The three scheduler jobs that live in the card; their runs leave Recent.
    public static let jobs = ["request-source-sync", "plex-watchlist-poll", "letterboxd-csv-match"]

    public static func isWatchlistJobRun(_ name: String) -> Bool { jobs.contains(name) }

    /// Recent's stand-in for the job rows that moved into the card.
    public static let foldedNote = "The three watchlist jobs no longer clutter Recent. Their status lives in the Watchlists & lists card."

    private static let kindLabels = [
        "PLEX_WATCHLIST": "Plex watchlist",
        "PLEX_LIST": "Plex list",
        "LETTERBOXD_WATCHLIST": "Letterboxd watchlist",
        "LETTERBOXD_RSS": "Letterboxd diary (RSS)",
        "LETTERBOXD_LIST": "Letterboxd list",
    ]

    public static func kindLabel(_ kind: String) -> String {
        kindLabels[kind] ?? kind.lowercased().replacingOccurrences(of: "_", with: " ")
    }

    public static func hasPlexSource(_ sources: [SummarySource]) -> Bool {
        sources.contains { $0.kind.hasPrefix("PLEX_") }
    }

    /// The card's wash: running, else error when any source failed, else idle.
    public static func tone(_ summary: RequestSourcesSummary) -> SyncVariant {
        if summary.runningSources > 0 { return .running }
        return summary.sources.contains { $0.state == "error" } ? .error : .idle
    }

    public static func tone(_ source: SummarySource) -> SyncVariant {
        switch source.state {
        case "running": return .running
        case "error": return .error
        default: return .idle
        }
    }

    /// The source's pill: Checking · Error · OK.
    public static func stateLabel(_ source: SummarySource) -> String {
        switch tone(source) {
        case .running: return "Checking"
        case .error: return "Error"
        default: return "OK"
        }
    }

    /// "Syncing 1 source · 24 of 38 checked" / "Idle · next source due in 5 hr".
    public static func overall(_ summary: RequestSourcesSummary, now: Date = Date()) -> SyncLine {
        typealias S = SyncLine.Segment
        let n = summary.runningSources
        guard n > 0 else {
            let due = summary.nextRunAt.map { " · next source due \(WatchlistTime.until($0, now: now))" } ?? ""
            return SyncLine([S("Idle" + due)])
        }
        return SyncLine([S("Syncing \(n) \(n == 1 ? "source" : "sources") · "),
                         S("\(summary.checked) of \(summary.total)", bold: true), S(" checked")])
    }

    /// "member · Letterboxd list · Best of 2026" (the label is left off a Plex watchlist).
    public static func detail(_ source: SummarySource) -> String {
        var text = " · \(kindLabel(source.kind))"
        if let label = source.label, !source.kind.hasPrefix("PLEX_WATCHLIST") { text += " · \(label)" }
        return text
    }

    /// "24 of 38 · 0 requested · 0 owned · 1 baseline", or "… · checked 3 min ago" at rest.
    public static func meta(_ source: SummarySource, now: Date = Date()) -> SyncLine {
        typealias S = SyncLine.Segment
        let c = source.counts
        let running = source.state == "running"
        var out: [S] = []
        if running, let total = source.total {
            out += [S("\(source.checked ?? 0) of \(total)", bold: true), S(" · ")]
        }
        out += [S("\(c.requested)", bold: true), S(" requested · "), S("\(c.owned)", bold: true), S(" owned")]
        if c.queued > 0 { out.append(S(" · \(c.queued) queued")) }
        if c.waiting > 0 { out.append(S(" · \(c.waiting) waiting")) }
        if c.skipped > 0 { out.append(S(" · \(c.skipped) skipped")) }
        if c.baseline > 0 { out += [S(" · "), S("\(c.baseline)", bold: true), S(" baseline")] }
        if !running, let last = source.lastCheckedAt {
            out.append(S(" · checked \(WatchlistTime.lastRun(last, now: now))"))
        }
        return SyncLine(out)
    }

    /// The error line under a failing source, with when it retries.
    public static func errorLine(_ source: SummarySource, now: Date = Date()) -> String? {
        guard source.state == "error" else { return nil }
        let why = source.lastError ?? "Couldn’t read this source"
        guard let next = source.nextCheckAt else { return why }
        return "\(why) · retrying \(WatchlistTime.until(next, now: now))"
    }

    /// A job label's dot: running, failed, ran fine, or never ran (paused = dim).
    public static func jobTone(_ job: SummaryJob?) -> SyncVariant {
        guard let job else { return .paused }
        if job.running { return .running }
        guard job.lastRunAt != nil else { return .paused }
        let status = (job.lastStatus ?? "").lowercased()
        return status.contains("fail") || status.contains("error") ? .error : .idle
    }

    public static func jobHelp(_ job: SummaryJob?, now: Date = Date()) -> String {
        guard let last = job?.lastRunAt else { return "Not run yet" }
        return "Last run \(WatchlistTime.lastRun(last, now: now))"
    }

    /// Today: Requested · Owned · Skipped · Errors.
    public static func todayCells(_ today: SummaryToday) -> [SyncProgress.Cell] {
        [
            SyncProgress.Cell(key: "requested", label: "Requested", value: today.requested),
            SyncProgress.Cell(key: "owned", label: "Owned", value: today.owned),
            SyncProgress.Cell(key: "skipped", label: "Skipped", value: today.skipped),
            SyncProgress.Cell(key: "errors", label: "Errors", value: today.errors),
        ]
    }
}
