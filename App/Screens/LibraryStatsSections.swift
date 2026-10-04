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
            ? "Manual import required — \(q.heldReason ?? defaultHeldReason)"
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
/// `useOperations({ open: true })` cadence).
@MainActor
@Observable
final class StatsSheetFeed {
    private(set) var inProgress: [StatsOperation] = []
    private(set) var rows: [StatsAttentionRow] = []
    private(set) var indexers: [UnavailableIndexer] = []
    private(set) var loaded = false

    func load(client: APIClient, queue: [QueueItem]) async {
        async let commands = try? client.operationCommands()
        async let runs = try? client.systemRuns(page: 1, pageSize: 50)
        async let library = try? client.libraryAttentionEntries()
        async let runAttention = try? client.runAttentionEntries()
        async let down = try? client.stoppedIndexers()
        let ops = StatsSheetLogic.compose(commands: await commands ?? [], queue: queue, runs: await runs?.items ?? [])
        let nextRows = StatsSheetLogic.attentionRows(library: await library ?? [], held: ops.attention,
                                                     runs: await runAttention ?? [])
        let nextIndexers = await down ?? []
        if ops.inProgress != inProgress { inProgress = ops.inProgress }
        if nextRows != rows { rows = nextRows }
        if nextIndexers != indexers { indexers = nextIndexers }
        loaded = true
    }

    func drop(rowId: String) { rows.removeAll { $0.id == rowId } }
}

// MARK: - Views

/// "In progress" (`OperationsList`): live operations, or "Nothing in progress."
struct StatsInProgressList: View {
    let operations: [StatsOperation]
    let open: (StatsOperation) -> Void

    var body: some View {
        if operations.isEmpty {
            StatsEmptyLine(text: "Nothing in progress.")
        } else {
            VStack(spacing: 0) {
                ForEach(operations) { op in
                    Button { open(op) } label: { StatsOperationRow(op: op) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(op.label) — open in Activity")
                }
            }
        }
    }
}

private struct StatsOperationRow: View {
    let op: StatsOperation
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(op.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                if let message = op.message {
                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.mut).lineLimit(1)
                }
                if op.status == .running || op.status == .queued {
                    bar.padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(op.status == .queued ? "queued" : op.progress.map { "\($0)%" } ?? StatsSheetLogic.relative(op.timestamp))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        let tint: Color = op.status == .completed ? Theme.done : op.status == .failed ? Theme.danger : Theme.grab
        return ZStack {
            switch op.status {
            case .running:
                if motion {
                    ProgressView().controlSize(.mini).tint(Theme.grab)
                } else {
                    Circle().fill(Theme.grab).frame(width: 9, height: 9)
                }
            case .queued, .attention:
                Circle().fill(Theme.grab.opacity(0.6)).frame(width: 8, height: 8)
            case .completed:
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
            case .failed:
                Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundStyle(tint)
        .frame(width: 30, height: 30)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var bar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(colors: [Theme.i1, Theme.i2], startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * CGFloat(op.progress ?? 35) / 100)
        }
        .frame(height: 4)
        .background(Theme.panel2, in: Capsule())
        .clipShape(Capsule())
    }
}

/// "Needs attention" (`AttentionList`).
struct StatsAttentionList: View {
    let indexers: [UnavailableIndexer]
    let rows: [StatsAttentionRow]
    let manageIndexers: () -> Void
    let openRow: (StatsAttentionRow) -> Void
    let act: (StatsAttentionRow) -> Void
    let dismissRow: (StatsAttentionRow) -> Void

    @Environment(\.motionEnabled) private var motion
    @State private var indexersOpen = false

    var body: some View {
        if indexers.isEmpty && rows.isEmpty {
            StatsEmptyLine(text: "Nothing needs attention right now.")
        } else {
            VStack(spacing: 0) {
                if !indexers.isEmpty {
                    indexerGroup
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 || !indexers.isEmpty { Rectangle().fill(Theme.line).frame(height: 1) }
                    attentionRow(row)
                }
            }
        }
    }

    private var indexerGroup: some View {
        let tint = Theme.stuck
        return HStack(alignment: .top, spacing: 11) {
            AttentionIcon(symbol: "antenna.radiowaves.left.and.right", tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Button {
                    withAnimation(motion ? .easeOut(duration: 0.2) : nil) { indexersOpen.toggle() }
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("\(ActFmt.plural(indexers.count, "indexer")) unavailable")
                                .font(.system(size: 12.5, weight: .heavy)).foregroundStyle(Theme.txt)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(tint)
                                .rotationEffect(.degrees(indexersOpen ? 180 : 0))
                        }
                        Text("Auto-disabled after repeated failures — retrying automatically")
                            .font(.system(size: 11)).foregroundStyle(Theme.mut)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(indexersOpen ? "expanded" : "collapsed")
                if indexersOpen {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(indexers) { ix in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 9) {
                                    Text(ix.name).font(.system(size: 11.5, weight: .heavy)).foregroundStyle(Theme.txt)
                                    Text(ix.retryHint()).font(.system(size: 10, weight: .heavy).monospacedDigit())
                                        .foregroundStyle(tint)
                                }
                                if let reason = ix.reason {
                                    Text(reason).font(.system(size: 11)).foregroundStyle(Theme.mut)
                                }
                            }
                        }
                    }
                    .padding(.top, 6)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ActionPill(label: "Manage", tint: tint, ghost: true, action: manageIndexers)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .statusWash(tint, base: .clear, radius: 0)
    }

    private func attentionRow(_ row: StatsAttentionRow) -> some View {
        let tint = row.kind == .deadLink ? Theme.stuck : Theme.miss
        return HStack(alignment: .top, spacing: 11) {
            AttentionIcon(symbol: symbol(row.kind), tint: tint)
            Button { openRow(row) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(.system(size: 12.5, weight: .heavy)).foregroundStyle(Theme.txt)
                    HStack(spacing: 5) {
                        if let tier = row.tier {
                            chip(StatsSheetLogic.tierRowLabel(tier), color: tier == .uhd ? Theme.grab : Theme.edition)
                        }
                        if let variant = row.variant { chip(variant, color: Theme.mut, fill: Theme.panel2) }
                        chip(row.kindChip, color: Theme.mut)
                    }
                    if !row.reason.isEmpty {
                        Text(row.reason).font(.system(size: 11.5)).foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                ActionPill(label: row.actionLabel, tint: tint, ghost: row.ghost) { act(row) }
                if row.runId != nil || row.dismissItemId != nil {
                    Button { dismissRow(row) } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .statusWash(tint, base: .clear, radius: 0)
    }

    private func symbol(_ kind: StatsAttentionRow.Kind) -> String {
        switch kind {
        case .importHeld: return "arrow.down.to.line"
        case .noGrab: return "magnifyingglass"
        case .numbering: return "list.number"
        case .metadataRemoved: return "icloud.slash"
        case .scopeMismatch: return "powerplug"
        case .deadLink, .deadContent: return "link"
        case .notFound, .partial: return "doc.badge.ellipsis"
        }
    }

    private func chip(_ text: String, color: Color, fill: Color = .clear) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(fill, in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color == Theme.mut ? Theme.line : color.opacity(0.45)))
    }
}

private struct AttentionIcon: View {
    let symbol: String
    let tint: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// `.rowAction` (solid amber) / `.rowActionGhost` (amber outline).
private struct ActionPill: View {
    let label: String
    let tint: Color
    let ghost: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .heavy))
                .foregroundStyle(ghost ? tint : Color(hex: 0x20160A))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(ghost ? Color.clear : tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ghost ? tint.opacity(0.45) : tint))
        }
        .buttonStyle(PressScaleStyle())
    }
}

private struct StatsEmptyLine: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity)
            .padding(26)
    }
}
