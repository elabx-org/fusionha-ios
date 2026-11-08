import SwiftUI
import Charts
import FusionhaKit

/// History › Insights in v2 (look pass family 3, mock look-b.js `insights`):
/// v1's numbers (`HistoryInsightsLogic`) as W1 modules on the title's wash.
/// The net score with its sparkline, Events, Upgrades and Indexers, then the
/// score progression per version and the provenance lanes, all in the page's
/// one ink with HD/4K media badges instead of v1's tier colours.
struct V2HistoryInsights: View {
    @Environment(\.pagePalette) private var page
    let versions: [DetailEdition]
    let entries: [HistoryEntry]

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let stats = HistoryInsightsLogic.stats(versions, entries)
        let series = HistoryInsightsLogic.progression(versions, entries)
        let swim = HistoryInsightsLogic.swimlane(versions, entries)
        VStack(alignment: .leading, spacing: 10) {
            hero(stats, series: series)
            HStack(alignment: .top, spacing: 10) {
                V2InsightModule(symbol: "list.bullet", label: "Events", value: "\(stats.eventsCount)",
                                sub: stats.daySpanLabel)
                V2InsightModule(symbol: "sparkles", label: "Upgrades", value: "\(stats.upgradesCount)",
                                sub: stats.upgradesByTier.isEmpty ? nil
                                    : stats.upgradesByTier.map { "\($0.count) \($0.label)" }.joined(separator: " · "))
            }
            V2InsightModule(symbol: "globe", label: "Indexers", value: "\(stats.indexersCount)",
                            sub: stats.indexerNames.isEmpty ? nil
                                : stats.indexerNames.map(HistoryInsightsLogic.indexerChip).joined(separator: ", "))
            heading("Score progression")
            if stats.hasAnyImport {
                V2ScoreProgressionGrid(series: series)
            } else {
                empty("No imports yet — nothing to chart.")
            }
            heading("Provenance — which release held each slot")
            if let start = swim.start {
                V2ProvenanceCard(lanes: swim.lanes, start: start)
            } else {
                empty("No grabs yet — nothing to show.")
            }
        }
    }

    private func hero(_ stats: HistoryInsightsLogic.Stats, series: [HistoryInsightsLogic.Series]) -> some View {
        let points = HistoryInsightsLogic.sparkline(entries)
        return VStack(alignment: .leading, spacing: 6) {
            V2InsightLabel(symbol: "sparkles", text: "Net CF score gained")
            Text(V2HistoryEvent.score(stats.netScore))
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ink)
            if let trend = stats.trendLabel {
                (Text(Image(systemName: "arrow.up")) + Text(" ") + Text(trend).bold().foregroundColor(ink)
                    + Text(Self.firstImports(series)))
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
            }
            if points.count > 1 {
                V2InsightSpark(points: points).frame(height: 64).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle()
        .accessibilityElement(children: .combine)
    }

    /// " · from +550 and +2,150 at the first imports".
    static func firstImports(_ series: [HistoryInsightsLogic.Series]) -> String {
        let firsts = series.compactMap { $0.points.first?.score }.map(V2HistoryEvent.score)
        guard !firsts.isEmpty else { return "" }
        let at = firsts.count == 1 ? "at the first import" : "at the first imports"
        return " · from \(firsts.joined(separator: " and ")) \(at)"
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(ink)
            .accessibilityAddTraits(.isHeader)
            .padding(.top, 14)
            .padding(.bottom, 2)
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v2CardStyle(padding: 14, radius: 20)
    }
}

/// A module's small label: a muted symbol and words ("Events").
struct V2InsightLabel: View {
    @Environment(\.pagePalette) private var page
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(page?.inkMuted ?? Theme.mut)
            .labelStyle(.titleAndIcon)
    }
}

/// One number module: label, the number in the rounded face, a muted line.
struct V2InsightModule: View {
    @Environment(\.pagePalette) private var page
    let symbol: String
    let label: String
    let value: String
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            V2InsightLabel(symbol: symbol, text: label)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(page?.ink ?? Theme.txt)
                .padding(.top, 2)
            if let sub {
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle()
        .accessibilityElement(children: .combine)
    }
}

/// The one-ink area sparkline: a soft fill, the line, a dot per import.
struct V2InsightSpark: View {
    @Environment(\.pagePalette) private var page
    let points: [Int]

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        Chart(Array(points.enumerated()), id: \.offset) { i, score in
            AreaMark(x: .value("Import", i), y: .value("Score", score))
                .foregroundStyle(ink.opacity(0.10))
            LineMark(x: .value("Import", i), y: .value("Score", score))
                .foregroundStyle(ink)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            PointMark(x: .value("Import", i), y: .value("Score", score))
                .foregroundStyle(ink)
                .symbolSize(22)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }
}
