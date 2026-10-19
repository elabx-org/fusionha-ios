import SwiftUI
import FusionhaKit

/// The readiness tiles (web `ReadinessTiles`): clients, free space, indexers
/// and the next RSS sync / search counting down. A grid that always fits the
/// width, never a scroller: 2 columns on the phone (the clients tile folds into
/// the strip there), auto-fit when medium, all five across when wide.
struct ReadinessTiles: View {
    let summary: IdleSummary?
    let columns: Int
    /// Phone: the Download clients tile is dropped (the strip carries it).
    var compact = false

    private enum Kind: Hashable { case clients, disk, indexers, rss, search }

    var body: some View {
        let kinds: [Kind] = compact ? [.disk, .indexers, .rss, .search] : [.clients, .disk, .indexers, .rss, .search]
        let rows = stride(from: 0, to: kinds.count, by: max(1, columns)).map { Array(kinds[$0..<min($0 + max(1, columns), kinds.count)]) }
        VStack(spacing: compact ? 8 : 10) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: compact ? 8 : 10) {
                    ForEach(row, id: \.self) { tile($0) }
                    ForEach(0..<(max(1, columns) - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Readiness")
    }

    @ViewBuilder
    private func tile(_ kind: Kind) -> some View {
        switch kind {
        case .clients: clientsTile
        case .disk: diskTile
        case .indexers: indexersTile
        case .rss:
            CountdownTile(task: summary?.tasks.rss, icon: "dot.radiowaves.left.and.right", label: "Next RSS sync",
                          windowSeconds: Double(summary?.tasks.rss?.intervalSeconds ?? 900),
                          sub: summary?.rssSubText ?? IdleSummary.everyLabel(seconds: 900),
                          runText: "Syncing…", runSub: summary?.rssRunningSub ?? "", compact: compact)
        case .search:
            CountdownTile(task: summary?.tasks.search, icon: "magnifyingglass", label: "Next search",
                          windowSeconds: 3600,
                          sub: summary?.searchSubText(upgradeClock: upgradeClock) ?? "Missing",
                          runText: "Searching…", runSub: IdleSummary.searchRunningSub, compact: compact)
        }
    }

    private var upgradeClock: String? {
        summary?.tasks.upgrade?.nextRunDate.map { $0.formatted(date: .omitted, time: .shortened) }
    }

    private var clientsTile: some View {
        ReadinessTile(icon: "cable.connector", label: "Download clients", compact: compact) {
            if let summary {
                if summary.clients.total == 0 {
                    ReadinessCaption(text: "none configured")
                } else {
                    QueueClearClientList(clients: summary.clients.items).padding(.top, 8)
                }
            }
        }
    }

    private var diskTile: some View {
        let disk = summary?.disk
        let state: IdleTime.TileState = summary?.diskLow == true ? .warn : .ok
        return ReadinessTile(icon: "externaldrive", label: "Free space", state: state, compact: compact) {
            ReadinessValue(value: disk.map { ActFmt.bytes(Double($0.freeBytes)) } ?? "—", compact: compact)
            ReadinessDiskBar(fraction: summary?.freeFraction ?? 0, color: state.color)
            ReadinessCaption(text: disk.map { "of \(ActFmt.bytes(Double($0.totalBytes))) · \(summary?.rootsVolumesText ?? "")" }
                             ?? "roots not readable")
        }
    }

    private var indexersTile: some View {
        let state: IdleTime.TileState = summary?.indexers.healthy == 0 ? .warn : .ok
        return ReadinessTile(icon: "antenna.radiowaves.left.and.right", label: "Indexers", state: state, compact: compact) {
            ReadinessValue(value: summary.map { "\($0.indexers.healthy)" } ?? "—",
                           note: summary.map { "/ \($0.indexers.total) healthy" }, compact: compact)
            ReadinessCaption(text: summary?.indexersSubText ?? " ")
        }
    }
}
