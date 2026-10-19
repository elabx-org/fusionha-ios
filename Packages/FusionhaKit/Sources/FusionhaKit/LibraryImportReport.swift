import Foundation

// The post-import analysis task view (web `summarisePostImportTask`) and the
// committed-import report's sums (web `CommitReportCard`).

/// One post-import analysis task as the launcher card shows it.
public struct LibraryImportTaskView: Sendable, Hashable {
    /// `analyzing` · `complete` · `paused` · `cancelled`
    public let state: String
    public let stateLabel: String
    /// "Analyzing 240 of 1,240 files".
    public let progressLabel: String
    /// 0…100.
    public let percent: Int
    public let issueCount: Int

    public init(_ task: LibraryImportEnrichment) {
        self.init(state: task.state, total: task.total, enriched: task.enriched, issue: task.issue)
    }

    /// A per-import analysis nested under Tasks › Media enrichment.
    public init(_ sub: EnrichmentSubtask) {
        self.init(state: sub.state, total: sub.total, enriched: sub.enriched, issue: sub.issue)
    }

    init(state rawState: String?, total rawTotal: Int?, enriched rawEnriched: Int?, issue rawIssue: Int?) {
        let raw = rawState ?? ""
        let known = ["complete", "paused", "cancelled"]
        state = known.contains(raw) ? raw : "analyzing"
        switch state {
        case "complete": stateLabel = "Complete"
        case "paused": stateLabel = "Paused"
        case "cancelled": stateLabel = "Cancelled"
        default: stateLabel = "Analyzing"
        }
        let total = max(0, rawTotal ?? 0)
        let enriched = min(max(0, rawEnriched ?? 0), total)
        if state == "complete" {
            percent = 100
        } else {
            percent = total > 0 ? min(100, Int((Double(enriched) / Double(total) * 100).rounded())) : 0
        }
        progressLabel = "Analyzing \(LibraryImportRules.grouped(enriched)) of \(LibraryImportRules.grouped(total)) files"
        issueCount = max(0, rawIssue ?? 0)
    }

    public var isAnalyzing: Bool { state == "analyzing" }
    public var isComplete: Bool { state == "complete" }
    /// Pause and Cancel while analysing.
    public var canPause: Bool { isAnalyzing }
    /// Resume once paused or cancelled.
    public var canResume: Bool { state == "paused" || state == "cancelled" }
    /// A finished job with no issues is silent.
    public var visible: Bool { !(isComplete && issueCount == 0) }

    /// The web's `ENRICHMENT_REASON_LABEL`; an unknown reason shows as sent.
    public static func reasonLabel(_ reason: String) -> String {
        switch reason {
        case "unlinked": return "Not linked to a title"
        case "unreadable": return "Unreadable file"
        case "probe_failed": return "Could not read media info"
        default: return reason
        }
    }
}

/// One title in the report's "Added" list.
public struct LibraryImportAddedRow: Sendable, Hashable, Identifiable {
    public let itemId: Int
    public let title: String
    public let year: Int?
    public let tiers: [QualityTier]
    public let files: Int
    public var id: Int { itemId }
}

/// The committed import's stat row and Added list.
public struct LibraryImportReport: Sendable, Hashable {
    public let added: [LibraryImportAddedRow]
    public let updated: Int
    /// Committed rows that adopted no new file (an idempotent re-commit).
    public let skipped: Int
    public let filesAdopted: Int

    public init(result: LibraryImportCommitResult, items: [LibraryImportItem]) {
        var names: [Int: (String, Int?)] = [:]
        for item in items {
            if let id = item.tmdbId { names[id] = (item.title, item.year) }
        }
        let committed = result.items ?? []
        func files(_ c: LibraryImportCommittedItem) -> Int {
            (c.versions ?? []).reduce(0) { $0 + ($1.filesCreated ?? 0) }
        }
        var rows: [LibraryImportAddedRow] = []
        for c in committed where c.created {
            let name = names[c.tmdbId]
            rows.append(LibraryImportAddedRow(itemId: c.itemId, title: name?.0 ?? "TMDB \(c.tmdbId)", year: name?.1,
                                              tiers: (c.versions ?? []).map(\.tier), files: files(c)))
        }
        added = rows
        updated = committed.filter { !$0.created }.count
        skipped = committed.filter { files($0) == 0 }.count
        filesAdopted = committed.reduce(0) { $0 + files($1) }
    }
}
