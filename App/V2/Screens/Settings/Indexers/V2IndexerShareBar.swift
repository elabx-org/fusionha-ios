import SwiftUI
import FusionhaKit

/// The grab share (mock `shareBar`): every indexer that grabbed in the
/// range as one stacked bar in its own colour, the leaders named in the
/// legend and the rest summed as "n others". The range menu sits on the
/// label, as the mock's "Last 7 days".
struct V2IndexerShareBar: View {
    let metrics: [IndexerMetric]
    let fleetGrabs: Int?
    @Binding var range: IndexerRange
    var legendCount = 5
    let colorFor: (Int) -> Color
    @Environment(\.pagePalette) private var page

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    private var grabbing: [IndexerMetric] {
        metrics.filter { $0.grabsRange > 0 }.sorted { $0.grabsRange > $1.grabsRange }
    }

    private var fleet: Int { fleetGrabs ?? metrics.reduce(0) { $0 + $1.grabsRange } }

    private func pct(_ grabs: Int) -> Int {
        fleet > 0 ? Int((Double(grabs) / Double(fleet) * 100).rounded()) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Grab share")
                Spacer(minLength: 8)
                rangeMenu
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(muted)
            if grabbing.isEmpty {
                Text("No grabs in this window yet.").font(.footnote).foregroundStyle(muted)
            } else {
                IndexerSplitBar(parts: grabbing.map { (Double($0.grabsRange), colorFor($0.id)) }, gap: 1.5)
                    .frame(height: 10)
                    .accessibilityHidden(true)
                legend
            }
        }
    }

    private var rangeMenu: some View {
        Menu {
            Picker("Date range", selection: $range) {
                ForEach(IndexerRange.allCases) { Text(Self.label($0)).tag($0) }
            }
        } label: {
            HStack(spacing: 3) {
                Text(Self.label(range))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Theme.accentText)
        }
        .accessibilityLabel("Date range, \(Self.label(range))")
    }

    static func label(_ range: IndexerRange) -> String {
        range == .all ? "All time" : range.phrase.prefix(1).uppercased() + range.phrase.dropFirst()
    }

    private var legend: some View {
        let lead = grabbing.prefix(legendCount)
        let rest = grabbing.dropFirst(legendCount)
        let restGrabs = rest.reduce(0) { $0 + $1.grabsRange }
        return PreviewFlow(spacing: 12, rowSpacing: 5) {
            ForEach(Array(lead)) { metric in
                item(metric.indexer.displayName, colorFor(metric.id), pct(metric.grabsRange))
            }
            if !rest.isEmpty {
                item("\(rest.count) other\(rest.count == 1 ? "" : "s")", (page?.ink ?? Theme.txt).opacity(0.3), pct(restGrabs))
            }
        }
    }

    private func item(_ name: String, _ color: Color, _ share: Int) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(color).frame(width: 8, height: 8)
            Text(name).foregroundStyle(muted)
            Text("\(share)%").fontWeight(.semibold).foregroundStyle(page?.ink ?? Theme.txt)
        }
        .font(.system(size: 12).monospacedDigit())
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

/// An indexer that is backing off (mock `.ixv-warn`, web `BackoffStrip`):
/// its tile, the failures and reason, when it retries, and Test.
struct V2IndexerBackoffStrip: View {
    let metric: IndexerMetric
    let color: Color
    let onTest: () -> Void
    @Environment(\.pagePalette) private var page

    private var health: IndexerStatRow.Health? { metric.stat?.health }

    var body: some View {
        HStack(spacing: 11) {
            V2IndexerTile(name: metric.indexer.displayName, color: color, state: "backoff", size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(metric.indexer.displayName) is backing off")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Button("Test", action: onTest)
                .font(.system(size: 12.5, weight: .bold))
                .buttonStyle(.glassProminent)
                .tint(Theme.stuck)
                .accessibilityLabel("Test \(metric.indexer.displayName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.stuck.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.stuck.opacity(0.35)))
    }

    /// "3 failures · HTTP 503 from Prowlarr · retries at 18:05".
    private var detail: String {
        var parts = ["\(health?.failureCount ?? 0) failure\(health?.failureCount == 1 ? "" : "s")"]
        if let reason = health?.lastFailureReason, !reason.isEmpty { parts.append(reason) }
        if let till = FetchFormat.date(health?.disabledTill), till > .now {
            parts.append("retries at \(till.formatted(date: .omitted, time: .shortened))")
        } else {
            parts.append("retrying")
        }
        return parts.joined(separator: " · ")
    }
}
