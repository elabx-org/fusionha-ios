import SwiftUI
import FusionhaKit

/// v2's Activity › Indexers (plan S10, built like the other scopes on the
/// tint ground). v1's call (`/indexers/stats` over a window); v2's look:
/// the window as glass chips, the insight module, then every indexer as one
/// W1 module, the ones backing off first, each with its share of the
/// fleet's grabs as a one-ink rail. The list runs the whole pane: an
/// indexer has nothing more to open (its settings live in Settings).
struct V2IndexersScope: View {
    @Environment(AppModel.self) private var model
    @Environment(\.paneSize) private var pane
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.motionEnabled) private var motion
    @State private var range = "7d"
    @State private var stats: ActivityIndexerStats?
    @State private var failed = false

    private static let ranges: [(key: String, label: String)] = [
        ("24h", "24 h"), ("7d", "7 days"), ("30d", "30 days"), ("all", "All time"),
    ]

    private var split: V2ScopeSplit { V2ScopeSplit(width: pane.width, duoOpen: duoOpen, bookPose: bookPose) }

    private var phrase: String {
        switch range {
        case "24h": return "24 h"
        case "30d": return "30 days"
        case "all": return "all time"
        default: return "7 days"
        }
    }

    var body: some View {
        V2ScopeColumns(split: split, enabled: false) {
            V2ScopeList(gutter: split.gutter) {
                V2ScopeCaption(lead: captionLead, rest: captionRest)
            } content: { content }
        } right: {
            EmptyView()
        }
        .v2PageGround(art: nil)
        .refreshable { await load() }
        .task(id: range) { await load() }
    }

    private var captionLead: String {
        guard let s = stats?.summary else { return failed ? "Not loaded" : "Loading…" }
        return "\(s.healthy) of \(ActFmt.plural(s.indexers, "indexer")) healthy"
    }

    private var captionRest: [String] {
        guard let s = stats?.summary else { return [] }
        return [V2IndexerInsight.problems(s), phrase]
    }

    @ViewBuilder
    private var content: some View {
        V2GlassChips(options: Self.ranges.map { V2GlassChips<String>.Option(value: $0.key, label: $0.label) },
                     selection: $range)
            .v2ScopeBlock()
        if let stats {
            V2IndexerInsight(summary: stats.summary, phrase: phrase).v2ScopeBlock(18)
            list(stats)
        } else if failed {
            ContentUnavailableView("Indexer stats could not be loaded", systemImage: "exclamationmark.icloud",
                                   description: Text("Check the server and try again."))
        } else {
            ProgressView("Loading indexer stats…").frame(maxWidth: .infinity).padding(.top, 40)
        }
    }

    @ViewBuilder
    private func list(_ stats: ActivityIndexerStats) -> some View {
        let rows = V2IndexerHealth.sorted(stats.indexers)
        let fleet = stats.summary.grabsRange ?? rows.reduce(0) { $0 + ($1.grabsRange ?? 0) }
        if rows.isEmpty {
            ContentUnavailableView("No indexers yet", systemImage: "antenna.radiowaves.left.and.right",
                                   description: Text("Add an indexer in Settings to start searching."))
        } else {
            V2ScopeSectionHead(title: "Indexers", systemImage: "antenna.radiowaves.left.and.right").v2ScopeBlock(8)
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, indexer in
                V2IndexerRow(indexer: indexer, fleetGrabs: fleet).v2ModuleRow(index, of: rows.count)
            }
        }
    }

    private func load() async {
        do {
            let result = try await model.client?.activityIndexerStats(range: range)
            withAnimation(motion ? ActMotion.rows : nil) { stats = result }
            failed = false
        } catch {
            failed = stats == nil
        }
    }
}
