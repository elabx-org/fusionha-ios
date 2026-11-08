import SwiftUI
import FusionhaKit

/// The fleet card (mock settings-ix.js `fleet`): "is search healthy?" in
/// one card. The count and health line with the average success ring,
/// three totals for the chosen range, the grab share as one stacked bar in
/// each indexer's colour, and a strip per indexer that is backing off.
struct V2IndexerFleetCard: View {
    let summary: IndexerStatsSummary?
    let metrics: [IndexerMetric]
    @Binding var range: IndexerRange
    /// How many indexers the legend names before "n others".
    var legendCount = 5
    let colorFor: (Int) -> Color
    let onTest: (SearchIndexerInfo) -> Void
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var total: Int { summary?.indexers ?? metrics.count }
    private var healthy: Int { summary?.healthy ?? metrics.filter { $0.state == "healthy" }.count }
    private var backoff: [IndexerMetric] { metrics.filter { $0.state == "backoff" } }
    private var avg: Int? { summary?.avgSuccessRange.map { Int(($0 * 100).rounded()) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            top
            totals.padding(.top, 14)
            V2IndexerShareBar(metrics: metrics, fleetGrabs: summary?.grabsRange, range: $range,
                              legendCount: legendCount, colorFor: colorFor)
                .padding(.top, 14)
            ForEach(backoff) { metric in
                V2IndexerBackoffStrip(metric: metric, color: colorFor(metric.id), onTest: { onTest(metric.indexer) })
                    .padding(.top, 12)
            }
        }
        .v2CardStyle(padding: 16)
    }

    private var top: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                (Text("\(total)") + Text(" indexer\(total == 1 ? "" : "s")").font(.system(size: 16, weight: .semibold))
                    .foregroundColor(muted))
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                    .foregroundStyle(ink)
                healthLine
            }
            Spacer(minLength: 8)
            if let avg {
                IndexerRing(value: avg)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Text("\(avg)%").font(.system(size: 11.5, weight: .bold).monospacedDigit()).foregroundStyle(ink)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("Average success \(avg) percent")
            }
        }
    }

    private var healthLine: some View {
        let off = max(0, total - healthy - backoff.count)
        return HStack(spacing: 6) {
            Circle().fill(backoff.isEmpty ? Theme.done : Theme.stuck).frame(width: 8, height: 8)
            if backoff.isEmpty {
                Text(healthy == total ? "All \(total) healthy" : "\(healthy) healthy").foregroundStyle(ink)
                Text(off > 0 ? "· \(off) off" : "· none backing off").foregroundStyle(muted).fontWeight(.medium)
            } else {
                Text("\(healthy) healthy").foregroundStyle(ink)
                Text("· \(backoff.count) backing off").foregroundStyle(Theme.stuck)
                if off > 0 { Text("· \(off) off").foregroundStyle(muted).fontWeight(.medium) }
            }
        }
        .font(.system(size: 13.5, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var totals: some View {
        let phrase = range == .all ? "all time" : range.rawValue
        let exclusive = summary?.exclusive?.all
        return VStack(spacing: 12) {
            V2SettingsHairline(leading: 0)
            HStack(alignment: .top, spacing: 12) {
                totalCell(FetchFormat.grouped(summary?.grabsRange ?? 0), "grabs · \(phrase)")
                divider
                totalCell(FetchFormat.grouped(summary?.queriesRange ?? 0), "queries · \(phrase)")
                divider
                totalCell(FetchFormat.grouped(exclusive?.total ?? 0),
                      exclusive?.pct.map { "exclusive · \(Int($0.rounded()))%" } ?? "exclusive")
            }
        }
    }

    private var divider: some View {
        ModuleMetrics.hairline(light: page?.isLight ?? Theme.isLight).frame(width: 0.5, height: 34)
    }

    private func totalCell(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .bold).monospacedDigit())
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11.5)).foregroundStyle(muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
