import SwiftUI
import FusionhaKit

/// Activity › Tasks › System: "Import lists" (fusionha 0.4.237, web
/// `routes/tasks/import-lists/ImportListsCard.tsx`), a sibling of Watchlists
/// & lists in the same shape: the overall line, one row per list, today's
/// totals and the `import-list-sync` job. Admin only; hidden with no lists.
struct ImportListsTaskCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    let summary: ImportListsSummary
    private static let job = "import-list-sync"

    private var tone: SyncVariant {
        if summary.running || summary.lists.contains(where: { $0.state == "running" }) { return .running }
        return summary.lists.contains { $0.state == "error" } ? .error : .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.lists) { ImportListsTaskRow(list: $0) }
            }
            .padding(.top, 12)
            Text("TODAY")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.66)
                .foregroundStyle(Theme.dim)
                .padding(.top, 14)
                .padding(.bottom, 6)
            SyncCountGrid(cells: [
                SyncProgress.Cell(key: "added", label: "Added", value: summary.today.added),
                SyncProgress.Cell(key: "owned", label: "In library", value: summary.today.owned),
                SyncProgress.Cell(key: "excluded", label: "Excluded", value: summary.today.excluded),
                SyncProgress.Cell(key: "errors", label: "Errors", value: summary.today.errors),
            ], label: "Today")
            jobChip.padding(.top, 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(TaskCard(wash: tone.color))
    }

    private var head: some View {
        let running = tone == .running
        let count = summary.lists.filter { $0.state == "running" }.count
        return HStack(alignment: .center, spacing: 13) {
            TaskIconTile(color: tone.color, spinning: running && !reduce) {
                Image(systemName: "list.bullet.rectangle")
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Import lists").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt)
                    Spacer(minLength: 4)
                    Button("Open settings") { model.openSettings(panel: "importlists") }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.borderless)
                }
                HStack(spacing: 6) {
                    if running { SyncDot(color: Theme.grab, live: true) }
                    Text(running
                         ? "Syncing\(count > 0 ? " \(count) \(count == 1 ? "list" : "lists")" : "")"
                         : "Idle\(summary.nextRunAt.map { " · next list due \(WatchlistTime.until($0))" } ?? "")")
                }
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.mut)
            }
        }
    }

    private var jobChip: some View {
        let job = summary.jobs.first { $0.name == Self.job }
        return HStack(spacing: 5) {
            Circle().fill(WatchlistsTaskLogic.jobTone(job).color).frame(width: 6, height: 6)
            Text(Self.job).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.job), \(WatchlistsTaskLogic.jobHelp(job))")
    }
}

/// One list of the card (web `ListRow`): name · "MDBList · Movies" · its
/// state, then its last-pass counts, Review when titles didn't match.
struct ImportListsTaskRow: View {
    @Environment(AppModel.self) private var model
    let list: ImportListsSummaryRow

    var body: some View {
        let state = ImportListCopy.rowState(list.state)
        let c = list.counts
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                (Text(list.name).foregroundStyle(Theme.txt)
                 + Text(" · " + ImportListCopy.kindLine(provider: list.provider, mediaKind: list.mediaKind)).foregroundStyle(Theme.mut))
                    .font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 4)
                ImportListStatusPill(look: (state.word, state.tone))
            }
            HStack(spacing: 4) {
                Text(meta(c)).monospacedDigit()
                if c.unmatched > 0 {
                    Button("Review") { model.openSettings(panel: "importlists") }.buttonStyle(.borderless)
                }
            }
            .font(.system(size: 12)).foregroundStyle(Theme.mut)
            if list.state == "error" {
                Text(list.lastError ?? "Couldn’t read this list").font(.system(size: 12)).foregroundStyle(Theme.text(.danger))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(state.tone.color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func meta(_ c: ImportListRunCounts) -> String {
        var parts = ["\(c.added) added", "\(c.owned) in library"]
        if c.excluded > 0 { parts.append("\(c.excluded) excluded") }
        if c.unmatched > 0 { parts.append("\(c.unmatched) unmatched") }
        if list.state != "running", let at = list.lastCheckedAt { parts.append("checked \(WatchlistTime.lastRun(at))") }
        return parts.joined(separator: " · ")
    }
}
