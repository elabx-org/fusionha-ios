import SwiftUI
import FusionhaKit

/// One indexer as a row of the Indexers module: the protocol's tile, the
/// name and its health, the window's facts in one ink, its share of the
/// fleet's grabs as a one-ink rail, and while it backs off why and until
/// when (the danger ink: a failing indexer is a failure).
struct V2IndexerRow: View {
    let indexer: IndexerStat
    /// The fleet's grabs in the window, for the share rail.
    let fleetGrabs: Int
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var health: V2IndexerHealth { V2IndexerHealth(indexer.health?.state) }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            V2TaskTile(systemImage: V2IndexerHealth.icon(indexer.protocol), failed: health == .backoff, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(indexer.name).font(.system(size: 15, weight: .bold)).foregroundStyle(ink).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(health.label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(health == .backoff ? Theme.dangerText : muted)
                }
                Text(facts).font(.system(size: 12.5).monospacedDigit()).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                if fleetGrabs > 0 { share.padding(.top, 4) }
                if health == .backoff, let failure { failure.padding(.top, 3) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(health == .off ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    /// "412 grabs · 1,204 queries · 98% success · 31 today".
    private var facts: String {
        var parts = [ActFmt.plural(indexer.grabsRange ?? 0, "grab"), ActFmt.plural(indexer.queriesRange ?? 0, "query", "queries")]
        if let rate = indexer.successRateRange { parts.append("\(Int((rate * 100).rounded()))% success") }
        if let today = indexer.queriesToday, today > 0 { parts.append("\(today.formatted()) today") }
        if let used = indexer.lastUsedAt, health != .healthy { parts.append("last used \(ActFmt.relative(used))") }
        return parts.joined(separator: " · ")
    }

    private var share: some View {
        let fraction = Double(indexer.grabsRange ?? 0) / Double(fleetGrabs)
        return HStack(spacing: 8) {
            RailBarV2(spans: fraction > 0 ? [OneInkRail.Span(piece: .onDisk, fraction: min(1, fraction))] : [])
            Text(String(format: "%.0f%%", fraction * 100))
                .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(muted)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .accessibilityLabel("\(Int((fraction * 100).rounded())) percent of grabs")
    }

    private var failure: Text? {
        let h = indexer.health
        var parts: [String] = []
        if let reason = h?.lastFailureReason, !reason.isEmpty { parts.append(reason) }
        if let until = V2QueueTime.clock(h?.disabledTill) { parts.append("resting until \(until)") }
        if let n = h?.failureCount, n > 0 { parts.append(ActFmt.plural(n, "failure")) }
        guard !parts.isEmpty else { return nil }
        return Text(parts.joined(separator: " · ")).font(.system(size: 12.5)).foregroundColor(Theme.dangerText)
    }
}

/// The server's health buckets (`/indexers/stats`): off (neither RSS nor
/// search on) wins, then backoff (inside the failure cool-off), else healthy.
enum V2IndexerHealth: Equatable {
    case healthy, backoff, off

    init(_ state: String?) {
        switch state {
        case "backoff": self = .backoff
        case "off", "disabled": self = .off
        default: self = .healthy
        }
    }

    var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .backoff: return "Backing off"
        case .off: return "Off"
        }
    }

    /// Problems first, then the busiest, the switched-off last.
    var rank: Int {
        switch self {
        case .backoff: return 0
        case .healthy: return 1
        case .off: return 2
        }
    }

    static func icon(_ kind: String?) -> String {
        switch kind?.lowercased() {
        case "torrent": return "arrow.down.circle"
        case "usenet": return "newspaper"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    static func sorted(_ indexers: [IndexerStat]) -> [IndexerStat] {
        indexers.sorted {
            let a = V2IndexerHealth($0.health?.state).rank, b = V2IndexerHealth($1.health?.state).rank
            if a != b { return a < b }
            if ($0.grabsRange ?? 0) != ($1.grabsRange ?? 0) { return ($0.grabsRange ?? 0) > ($1.grabsRange ?? 0) }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
