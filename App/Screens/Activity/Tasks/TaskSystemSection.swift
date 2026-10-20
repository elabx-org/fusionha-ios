import SwiftUI
import FusionhaKit

/// Tasks › System (web `TasksTab.module.css` `.sysGrid`): Media enrichment,
/// RSS Sync, Watchlists & lists and Scheduled. One column on the phone; above
/// 720 (the desktop layout, measured on the Activity pane) three across, 10
/// apart (`repeat(3, minmax(0, 1fr))`), cards top-aligned in each row.
/// Enrichment's subtasks follow the grid there, full width.
struct TaskSystemSection: View {
    let enrichment: ActivityEnrichmentStatus?
    let rss: ActivitySystemTask?
    let latestRss: ActivityRun?
    let watchlists: RequestSourcesSummary?
    let scheduled: [ActivitySystemTask]
    let refresh: () async -> Void
    @Environment(\.paneSize) private var pane

    private enum Kind: Hashable { case enrichment, rss, watchlists, scheduled }

    private var kinds: [Kind] {
        var out: [Kind] = []
        if enrichment != nil { out.append(.enrichment) }
        if rss != nil { out.append(.rss) }
        if watchlists != nil { out.append(.watchlists) }
        if !scheduled.isEmpty { out.append(.scheduled) }
        return out
    }

    var body: some View {
        if pane.isDesktopPane {
            let kinds = self.kinds
            let rows = stride(from: 0, to: kinds.count, by: 3).map { Array(kinds[$0..<min($0 + 3, kinds.count)]) }
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(rows, id: \.self) { row in
                        GridRow {
                            ForEach(row, id: \.self) { kind in
                                card(kind).frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                            ForEach(row.count..<3, id: \.self) { _ in
                                Color.clear.frame(maxWidth: .infinity).gridCellUnsizedAxes(.vertical)
                            }
                        }
                    }
                }
                subtasks
            }
        } else {
            VStack(spacing: 10) {
                ForEach(kinds, id: \.self) { kind in
                    card(kind)
                    if kind == .enrichment { subtasks }
                }
            }
        }
    }

    @ViewBuilder private func card(_ kind: Kind) -> some View {
        switch kind {
        case .enrichment: if let enrichment { EnrichmentCard(status: enrichment) }
        case .rss: if let rss { RssSyncCard(task: rss, latestRun: latestRss) }
        case .watchlists: if let watchlists { WatchlistsTaskCard(summary: watchlists) }
        case .scheduled: ScheduledCard(tasks: scheduled)
        }
    }

    @ViewBuilder private var subtasks: some View {
        if let subs = enrichment?.subtasks, !subs.isEmpty {
            EnrichmentSubtasksView(subtasks: subs, onChanged: refresh)
        }
    }
}
