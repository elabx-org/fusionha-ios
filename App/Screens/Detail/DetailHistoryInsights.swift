import SwiftUI
import Charts
import FusionhaKit

/// The History tab's Insights (HistoryInsights.tsx): the net-score hero with
/// its sparkline, Events / Upgrades / Indexers cards, a tier-coloured score
/// progression per version and the provenance swimlane.
struct HistoryInsightsView: View {
    let versions: [DetailEdition]
    let entries: [HistoryEntry]

    var body: some View {
        let stats = HistoryInsightsLogic.stats(versions, entries)
        let series = HistoryInsightsLogic.progression(versions, entries)
        let swim = HistoryInsightsLogic.swimlane(versions, entries)
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                hero(stats)
                card("list.bullet", Theme.i1, value: "\(stats.eventsCount)", label: "Events") {
                    if let span = stats.daySpanLabel { Text(span) }
                }
                card("sparkles", Theme.done, value: "\(stats.upgradesCount)", label: "Upgrades") {
                    if !stats.upgradesByTier.isEmpty {
                        Text(stats.upgradesByTier.map { "\($0.count) \($0.label)" }.joined(separator: " · "))
                    }
                }
                card("server.rack", Theme.edition, value: "\(stats.indexersCount)", label: "Indexers") {
                    if !stats.indexerNames.isEmpty {
                        Text(stats.indexerNames.map(HistoryInsightsLogic.indexerChip).joined(separator: ", ")).lineLimit(2)
                    }
                }
            }
            DetailMonoHeading(text: "Score progression").padding(.top, 10)
            if stats.hasAnyImport {
                ForEach(series) { ScoreProgressionCard(series: $0) }
            } else {
                EmptyBox(message: "No imports yet — nothing to chart.")
            }
            DetailMonoHeading(text: "Provenance — which release held each slot").padding(.top, 10)
            if let start = swim.start {
                ProvenanceSwimlane(lanes: swim.lanes, start: start)
            } else {
                EmptyBox(message: "No grabs yet — nothing to show.")
            }
        }
    }

    private func hero(_ stats: HistoryInsightsLogic.Stats) -> some View {
        let points = HistoryInsightsLogic.sparkline(entries)
        return card("sparkles", Theme.done, value: DetailText.score(stats.netScore), label: "Net CF score gained") {
            VStack(alignment: .leading, spacing: 6) {
                if let trend = stats.trendLabel {
                    Label(trend, systemImage: "chevron.up").foregroundStyle(Theme.done)
                }
                if points.count > 1 {
                    Chart(Array(points.enumerated()), id: \.offset) { i, score in
                        LineMark(x: .value("Import", i), y: .value("Score", score))
                            .foregroundStyle(Theme.done)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 32)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func card(_ symbol: String, _ tone: Color, value: String, label: String,
                      @ViewBuilder sub: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 28, height: 28)
                .background(tone.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(value).font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundStyle(Theme.txt)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.mut)
            sub().font(.system(size: 11)).foregroundStyle(Theme.dim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .detailCard(radius: 14, shadow: false)
        .accessibilityElement(children: .combine)
    }
}

/// One version's import scores over time, in its tier colour.
private struct ScoreProgressionCard: View {
    let series: HistoryInsightsLogic.Series

    var body: some View {
        let color = DetailTokens.tier(series.tier)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DetailTierChip(tier: series.tier, label: series.label)
                Spacer()
                if let last = series.points.last {
                    Text("now \(DetailText.score(last.score))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.txt)
                }
            }
            if series.points.isEmpty {
                Text("No imports yet").font(.system(size: 12)).foregroundStyle(Theme.dim)
            } else {
                Chart(Array(series.points.enumerated()), id: \.offset) { i, point in
                    AreaMark(x: .value("Import", i), y: .value("Score", point.score))
                        .foregroundStyle(color.opacity(0.14))
                    LineMark(x: .value("Import", i), y: .value("Score", point.score))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    PointMark(x: .value("Import", i), y: .value("Score", point.score))
                        .foregroundStyle(Theme.done)
                        .annotation(position: .top) {
                            Text(DetailText.score(point.score))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.mut)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
                .accessibilityLabel("\(series.label) score progression")
            }
        }
        .padding(12)
        .detailCard(radius: 14, shadow: false)
    }
}

/// Which release held each version's slot, as bars along time.
private struct ProvenanceSwimlane: View {
    let lanes: [HistoryInsightsLogic.Lane]
    let start: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(lanes) { lane in
                VStack(alignment: .leading, spacing: 6) {
                    DetailTierChip(tier: lane.tier, label: lane.label)
                    if lane.segments.isEmpty {
                        Text("Nothing grabbed yet").font(.system(size: 12)).foregroundStyle(Theme.dim)
                    } else {
                        bars(lane)
                        if let current = lane.segments.last {
                            Text(current.title + (current.score.map { " · \(DetailText.score($0))" } ?? ""))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.mut)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(12)
        .detailCard(radius: 14, shadow: false)
    }

    private func bars(_ lane: HistoryInsightsLogic.Lane) -> some View {
        let color = DetailTokens.tier(lane.tier)
        return Chart(Array(lane.segments.enumerated()), id: \.offset) { _, seg in
            BarMark(xStart: .value("From", seg.start), xEnd: .value("To", max(seg.end, seg.start.addingTimeInterval(3600))),
                    y: .value("Slot", lane.label), height: .fixed(24))
                .foregroundStyle(color.opacity(seg.isCurrent ? 0.85 : 0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel(seg.title + (seg.score.map { " · \(DetailText.score($0))" } ?? ""))
        }
        .chartXScale(domain: start...max(Date(), start.addingTimeInterval(86_400)))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 11))
            }
        }
        .frame(height: 52)
    }
}
