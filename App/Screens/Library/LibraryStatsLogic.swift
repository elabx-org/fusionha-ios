import SwiftUI
import FusionhaKit

// The Library stats sheet's lower half (LibraryPulse.tsx `sheetSection`s):
// "In progress" is the Operations feed (shell/OperationsPanel.tsx
// `OperationsList` + lib/api/activity.ts `composeOperations`) and "Needs
// attention" is the merged attention list (shell/AttentionControl.tsx
// `AttentionList`): the disabled-indexers group, then every file / held-import
// / no-grab row, rows about one title kept adjacent.

// MARK: - Model

/// One background operation (`Operation`), from a command, a download or a run.
struct StatsOperation: Identifiable, Hashable {
    enum Status: Hashable { case running, queued, completed, failed, attention }

    let id: String
    let label: String
    let message: String?
    let status: Status
    /// 0–100, nil for indeterminate work.
    let progress: Int?
    let timestamp: String?
    let downloadId: Int?
    let tier: QualityTier?
    let itemId: Int?

    var active: Bool { status == .running || status == .queued || status == .attention }
}

/// One "Needs attention" row (`AttentionRow`).
struct StatsAttentionRow: Identifiable, Hashable {
    enum Kind: Int, Hashable {
        // Sort weight (`KIND_ORDER`): a held import leads the file rows about the same title.
        case importHeld = 0, deadContent, deadLink, notFound, partial, numbering, metadataRemoved, scopeMismatch, noGrab
    }
    enum Action: Hashable { case manualImport, replace(QualityTier?), setType, review, view, seeWhy }

    let id: String
    let kind: Kind
    let kindChip: String
    let title: String
    let tier: QualityTier?
    let variant: String?
    let reason: String
    let action: Action
    let actionLabel: String
    let ghost: Bool
    let itemId: Int?
    let runId: Int?
    let dismissItemId: Int?
}

enum StatsSheetLogic {
    private static let schedulerMirrored: Set<String> = ["rss", "scheduled"]
    private static let refreshScan = "Refresh & Scan"
    private static let defaultHeldReason = "not an upgrade for the existing file"

    private static func commandStatus(_ s: String) -> StatsOperation.Status {
        switch s {
        case "running": return .running
        case "failed": return .failed
        case "queued": return .queued
        default: return .completed
        }
    }

    static func operation(_ c: OperationCommand) -> StatsOperation {
        StatsOperation(id: "cmd:\(c.id)", label: ActFmt.taskLabel(c.name), message: c.message,
                       status: commandStatus(c.status), progress: c.progress.map { Int(($0 * 100).rounded()) },
                       timestamp: c.ended ?? c.started, downloadId: nil, tier: nil, itemId: nil)
    }

    private static func queueStatus(_ s: String) -> StatsOperation.Status {
        switch s.lowercased() {
        case "held": return .attention
        case "failed", "warning": return .failed
        case "completed", "imported": return .completed
        case "queued", "delay", "pending", "paused": return .queued
        default: return .running
        }
    }

    static func operation(_ q: QueueItem) -> StatsOperation {
        let status = queueStatus(q.status)
        let label = q.episodeLabel.map { "\(q.title) · \($0)" } ?? q.title
        let pct: Int? = status == .running ? queuePct(q) : (status == .completed ? 100 : nil)
        let message = status == .attention
            ? "Manual import required — \(q.held?.line ?? q.heldReason ?? defaultHeldReason)"
            : (q.releaseTitle ?? q.downloadClient)
        return StatsOperation(id: "dl:\(q.id)", label: label, message: message, status: status, progress: pct,
                              timestamp: nil, downloadId: q.id, tier: q.tier, itemId: q.mediaItemId)
    }

    /// `queueProgressPct`: bytes when sizes are known, else the client's percent.
    private static func queuePct(_ q: QueueItem) -> Int {
        let pct = q.size > 0 ? (q.size - q.sizeleft) / q.size * 100 : q.progress
        return min(100, max(0, Int(pct.rounded())))
    }

    static func operation(_ run: ActivityRun) -> StatsOperation {
        let queued = run.status == "running" && run.phase == "queued"
        let status: StatsOperation.Status = queued ? .queued
            : run.status == "running" ? .running
            : (run.status == "failed" || run.status == "interrupted") ? .failed : .completed
        let running = status == .running
        let detail = (run.targetSummary ?? run.targetTitle)
        let message: String? = queued ? "Queued" : running ? runMessage(run) : status == .failed ? "Failed" : nil
        return StatsOperation(id: "run:\(run.id)", label: detail.map { "\(run.name) · \($0)" } ?? run.name,
                              message: message, status: status, progress: running ? runPct(run) : nil,
                              timestamp: run.endedAt ?? run.startedAt, downloadId: nil, tier: nil, itemId: nil)
    }

    /// `runOpMessage`: "probing 40/178", the phase, or the factual line.
    private static func runMessage(_ run: ActivityRun) -> String? {
        let total = run.progressTotal ?? 0, current = run.progressCurrent ?? 0
        if total > 0 { return run.phase.map { "\($0) \(current)/\(total)" } ?? "\(current)/\(total)" }
        return run.phase ?? factualLine(run)
    }

    /// The Tasks feed's factual line ("Grabbed 1 · 34 / 58 evaluated", "Searching…").
    private static func factualLine(_ run: ActivityRun) -> String {
        var parts: [String] = []
        if run.grabbed > 0 { parts.append("Grabbed \(run.grabbed)") }
        if run.upgraded > 0 { parts.append("\(run.upgraded) upgraded") }
        if run.evaluated > 0 {
            parts.append(run.releases > 0 ? "\(run.evaluated) / \(run.releases) evaluated" : "\(run.evaluated) evaluated")
        } else if run.releases > 0 {
            parts.append("\(run.releases) releases")
        }
        return parts.isEmpty ? "Searching…" : parts.joined(separator: " · ")
    }

    private static func runPct(_ run: ActivityRun) -> Int? {
        let total = run.progressTotal ?? 0, current = run.progressCurrent ?? 0
        if total > 0 { return min(100, max(0, Int((Double(current) / Double(total) * 100).rounded()))) }
        return run.releases > 0 ? min(100, max(0, Int((Double(run.evaluated) / Double(run.releases) * 100).rounded()))) : nil
    }

    /// `refreshGroupOperation`: a batch of in-flight Refresh & Scan runs as one row.
    private static func refreshGroup(_ runs: [ActivityRun]) -> StatsOperation {
        let scanning = runs.filter { $0.phase != nil && $0.phase != "queued" }.count
        let queued = runs.count - scanning
        var parts: [String] = []
        if scanning > 0 { parts.append("\(scanning) scanning") }
        if queued > 0 { parts.append("\(queued) queued") }
        let titles = ActFmt.plural(runs.count, "title")
        return StatsOperation(id: "group:refresh-scan", label: "\(refreshScan) · \(titles)",
                              message: parts.isEmpty ? titles : parts.joined(separator: " · "),
                              status: scanning > 0 ? .running : .queued, progress: nil,
                              timestamp: runs.map(\.startedAt).min(), downloadId: nil, tier: nil, itemId: nil)
    }

    /// `composeOperations`: (in progress, awaiting the user).
    static func compose(commands: [OperationCommand], queue: [QueueItem], runs: [ActivityRun])
        -> (inProgress: [StatsOperation], attention: [StatsOperation]) {
        let runItems = runs.filter { !schedulerMirrored.contains($0.trigger) }
        let isActiveRefresh: (ActivityRun) -> Bool = { $0.name == refreshScan && $0.status == "running" }
        let activeRefresh = runItems.filter(isActiveRefresh)
        var ops = commands.map { operation($0) } + queue.map { operation($0) }
        ops += runItems.filter { !isActiveRefresh($0) }.map { operation($0) }
        ops += activeRefresh.count > 1 ? [refreshGroup(activeRefresh)] : activeRefresh.map { operation($0) }
        return (ops.filter { $0.active && $0.status != .attention }, ops.filter { $0.status == .attention })
    }

    private static let replaceable: Set<String> = ["dead_link", "dead_content"]

    static func row(_ e: LibraryAttentionEntry, index: Int) -> StatsAttentionRow {
        let kind: StatsAttentionRow.Kind
        switch e.kind {
        case "dead_content": kind = .deadContent
        case "dead_link": kind = .deadLink
        case "partial": kind = .partial
        case "numbering_mismatch": kind = .numbering
        case "metadata_removed": kind = .metadataRemoved
        case "arr_scope_mismatch": kind = .scopeMismatch
        default: kind = .notFound
        }
        let chip = kind == .numbering ? "Numbering" : kind == .metadataRemoved ? "Removed"
            : kind == .scopeMismatch ? "Connection" : "File"
        let action: StatsAttentionRow.Action = kind == .scopeMismatch ? .setType : kind == .numbering ? .review
            : replaceable.contains(e.kind) ? .replace(e.tier) : .view
        let label = kind == .scopeMismatch ? "Set type" : kind == .numbering ? "Review"
            : replaceable.contains(e.kind) ? "Replace" : "View"
        return StatsAttentionRow(id: "lib:\(e.itemId):\(e.tier?.rawValue ?? "item"):\(e.edition ?? ""):\(index)",
                                 kind: kind, kindChip: chip, title: e.title, tier: e.tier, variant: e.edition,
                                 reason: e.message, action: action, actionLabel: label, ghost: true,
                                 itemId: e.itemId, runId: nil, dismissItemId: kind == .scopeMismatch ? e.itemId : nil)
    }

    static func row(_ op: StatsOperation) -> StatsAttentionRow {
        StatsAttentionRow(id: "op:\(op.id)", kind: .importHeld, kindChip: "Import", title: op.label, tier: op.tier,
                          variant: nil, reason: op.message ?? "", action: op.downloadId != nil ? .manualImport : .view,
                          actionLabel: op.downloadId != nil ? "Manual import" : "View", ghost: false,
                          itemId: op.itemId, runId: nil, dismissItemId: nil)
    }

    static func row(_ r: RunAttentionEntry) -> StatsAttentionRow {
        StatsAttentionRow(id: "run:\(r.runId)", kind: .noGrab, kindChip: "Search", title: r.title ?? "Untitled",
                          tier: nil, variant: nil, reason: r.reason, action: .seeWhy, actionLabel: "See why",
                          ghost: true, itemId: r.itemId, runId: r.runId, dismissItemId: nil)
    }

    /// `buildAttentionRows`.
    static func attentionRows(library: [LibraryAttentionEntry], held: [StatsOperation],
                              runs: [RunAttentionEntry]) -> [StatsAttentionRow] {
        let rows = held.map { row($0) } + library.enumerated().map { row($1, index: $0) } + runs.map { row($0) }
        return rows.sorted {
            let a = $0.itemId ?? .max, b = $1.itemId ?? .max
            return a != b ? a < b : $0.kind.rawValue < $1.kind.rawValue
        }
    }

    /// `tierRowLabel`: "HD 1080p" / "4K UHD".
    static func tierRowLabel(_ tier: QualityTier) -> String { tier == .uhd ? "4K UHD" : "HD 1080p" }

    /// `formatLastRun`-style relative stamp.
    static func relative(_ iso: String?, now: Date = Date()) -> String {
        guard let date = DetailText.instant(iso) else { return "" }
        let s = Int(now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86_400 { return "\(s / 3600)h ago" }
        return "\(s / 86_400)d ago"
    }
}

/// The sheet's live sources, polled every 2s while it is open (the web's
/// `useOperations({ open: true })` cadence). One shared feed, so reopening the
/// sheet shows the last answers at once; each source fills in as it lands
/// instead of the sheet waiting for the slowest, and held downloads come from
/// the queue the app already has.
@MainActor
@Observable
final class StatsSheetFeed {
    static let shared = StatsSheetFeed()

    private(set) var inProgress: [StatsOperation] = []
    private(set) var rows: [StatsAttentionRow] = []
    private(set) var indexers: [UnavailableIndexer] = []
    private(set) var loaded = false

    private var commands: [OperationCommand] = []
    private var runs: [ActivityRun] = []
    private var library: [LibraryAttentionEntry] = []
    private var runAttention: [RunAttentionEntry] = []
    private var queue: [QueueItem] = []

    func load(client: APIClient, queue: [QueueItem]) async {
        self.queue = queue
        recompute()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { if let v = try? await client.operationCommands() { await self.update(commands: v) } }
            group.addTask { if let v = try? await client.systemRuns(page: 1, pageSize: 50) { await self.update(runs: v.items) } }
            group.addTask { if let v = try? await client.libraryAttentionEntries() { await self.update(library: v) } }
            group.addTask { if let v = try? await client.runAttentionEntries() { await self.update(runAttention: v) } }
            group.addTask {
                if let v = try? await client.stoppedIndexers() {
                    await self.update(indexers: v)
                }
            }
        }
        loaded = true
    }

    private func update(commands: [OperationCommand]) { self.commands = commands; recompute() }
    private func update(runs: [ActivityRun]) { self.runs = runs; recompute() }
    private func update(library: [LibraryAttentionEntry]) { self.library = library; recompute() }
    private func update(runAttention: [RunAttentionEntry]) { self.runAttention = runAttention; recompute() }
    private func update(indexers: [UnavailableIndexer]) { if indexers != self.indexers { self.indexers = indexers } }

    private func recompute() {
        let ops = StatsSheetLogic.compose(commands: commands, queue: queue, runs: runs)
        let nextRows = StatsSheetLogic.attentionRows(library: library, held: ops.attention, runs: runAttention)
        if ops.inProgress != inProgress { inProgress = ops.inProgress }
        if nextRows != rows { rows = nextRows }
    }

    func drop(rowId: String) { rows.removeAll { $0.id == rowId } }
}
