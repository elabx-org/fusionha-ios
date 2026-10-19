import Foundation

/// How one source's sync reads: mid-pass, failing, switched off, or at rest
/// (web `syncVariant`). The App colours it: running = grabbing, error =
/// danger, paused = dim, idle = done.
public enum SyncVariant: String, Sendable, Hashable {
    case running, error, paused, idle
}

/// A line of text with bold runs (the web's `<b>` inside a state line).
public struct SyncLine: Sendable, Hashable {
    public struct Segment: Sendable, Hashable {
        public let text: String
        public let bold: Bool

        public init(_ text: String, bold: Bool = false) {
            self.text = text
            self.bold = bold
        }
    }

    public let segments: [Segment]

    public init(_ segments: [Segment]) { self.segments = segments }

    /// The words without styling (tests, VoiceOver).
    public var plain: String { segments.map(\.text).joined() }
}

/// The sync-progress rules of fusionha 0.4.215 (web `lib/api/sync-progress.ts`
/// and `components/sync-progress/sync-copy.ts`): the state line, the bar's
/// percent, the five counts and when to poll fast.
public enum SyncProgress {
    /// The fast cadence while any source is mid-pass.
    public static let runningPollSeconds = 2

    public static let syncing = "Syncing"
    public static let syncingButton = "Syncing…"
    public static let followsIt = "Runs on its own too; this follows it."

    public static func isRunning(_ sync: SourceSync?) -> Bool { sync?.isRunning == true }

    public static func anyRunning(_ syncs: [SourceSync?]) -> Bool { syncs.contains { isRunning($0) } }

    /// Any part of the Letterboxd card mid-pass: the diary, the own watchlist or a linked source.
    public static func letterboxdRunning(_ read: LetterboxdRead?, sources: [LbSource]) -> Bool {
        anyRunning([read?.diary?.sync, read?.watchlistFollow.sync] + sources.map(\.sync))
    }

    /// The Plex watchlist or any of its lists mid-pass.
    public static func plexRunning(_ read: PlexWatchlistRead?) -> Bool {
        guard let read else { return false }
        return anyRunning([read.sync] + read.lists.sources.map(\.sync))
    }

    /// "Checking 24 of 38": the share of a running pass, 0–100; nil until the total is known.
    public static func percent(_ sync: SourceSync?) -> Int? {
        guard let sync, let total = sync.total, total > 0 else { return nil }
        let pct = (Double(sync.checked ?? 0) / Double(total) * 100).rounded()
        return Int(max(0, min(100, pct)))
    }

    public static func variant(_ sync: SourceSync?, paused: Bool = false) -> SyncVariant {
        if paused { return .paused }
        if isRunning(sync) { return .running }
        return sync?.state == "error" ? .error : .idle
    }

    /// One source's state line (web `SyncStatus`): "Checking 24 of 38 · 6
    /// requested so far" / "Up to date · checked 3 min ago · next check in
    /// 12 hr" / "Couldn’t read this source · … · retrying in 12 min" /
    /// "Paused · …".
    public static func line(_ sync: SourceSync?, requested: Int = 0, lastCheckedAt: String? = nil,
                            nextCheckAt: String? = nil, lastError: String? = nil,
                            errorLead: String = "Couldn’t read this source", paused: Bool = false,
                            pausedText: String? = nil, note: String? = nil, now: Date = Date()) -> SyncLine {
        typealias S = SyncLine.Segment
        switch variant(sync, paused: paused) {
        case .running:
            guard let total = sync?.total else { return SyncLine([S("Reading the source…")]) }
            return SyncLine([S("Checking "), S("\(sync?.checked ?? 0)", bold: true), S(" of \(total) · "),
                             S("\(requested)", bold: true), S(" requested so far")])
        case .error:
            let retry = nextCheckAt.map { "retrying \(WatchlistTime.until($0, now: now))" }
            return SyncLine([S(errorLead, bold: true)] + [lastError, retry].compactMap { $0 }.map { S(" · \($0)") })
        case .paused:
            return SyncLine([S("Paused", bold: true)] + (pausedText.map { [S(" · \($0)")] } ?? []))
        case .idle:
            let lead = lastCheckedAt != nil || note != nil ? "Up to date" : "Waiting for the first check"
            let when = checkedNext(lastCheckedAt, nextCheckAt, now: now)
            let rest = [note, when.isEmpty ? nil : when].compactMap { $0 }
            return SyncLine([S(lead, bold: true)] + rest.map { S(" · \($0)") })
        }
    }

    /// The word a screen reader hears when the state changes (not the moving count).
    public static func announcement(_ variant: SyncVariant, lastCheckedAt: String? = nil, note: String? = nil,
                                    errorLead: String = "Couldn’t read this source") -> String {
        switch variant {
        case .running: return syncing
        case .error: return errorLead
        case .paused: return "Paused"
        case .idle: return lastCheckedAt != nil || note != nil ? "Up to date" : "Waiting for the first check"
        }
    }

    /// "checked 3 min ago · next check in 12 hr".
    public static func checkedNext(_ lastCheckedAt: String?, _ nextCheckAt: String?, now: Date = Date()) -> String {
        var parts: [String] = []
        if let lastCheckedAt { parts.append("checked \(WatchlistTime.lastRun(lastCheckedAt, now: now))") }
        if let nextCheckAt { parts.append("next check \(WatchlistTime.until(nextCheckAt, now: now))") }
        return parts.joined(separator: " · ")
    }

    /// The queued backlog drains on its own, so say so.
    public static func queuedHint(_ counts: SourceCounts?) -> String? {
        let n = counts?.queued ?? 0
        return n > 0 ? "\(n) queued · working through them" : nil
    }

    /// "43 films recorded as baseline" (the diary's idle detail).
    public static func baselineNote(_ n: Int?) -> String? {
        guard let n, n > 0 else { return nil }
        return "\(n) \(n == 1 ? "film" : "films") recorded as baseline"
    }

    // MARK: Counts

    /// One small count tile.
    public struct Cell: Sendable, Hashable, Identifiable {
        public let key: String
        public let label: String
        public let value: Int
        public var id: String { key }

        public init(key: String, label: String, value: Int) {
            self.key = key
            self.label = label
            self.value = value
        }
    }

    /// Requested · In library · Queued · Waiting · Skipped (web `SyncCounts`);
    /// zeros when an older server sends no counts.
    public static func cells(_ counts: SourceCounts?) -> [Cell] {
        let c = counts ?? .empty
        return [
            Cell(key: "requested", label: "Requested", value: c.requested),
            Cell(key: "owned", label: "In library", value: c.owned),
            Cell(key: "queued", label: "Queued", value: c.queued),
            Cell(key: "waiting", label: "Waiting", value: c.waiting),
            Cell(key: "skipped", label: "Skipped", value: c.skipped),
        ]
    }
}
