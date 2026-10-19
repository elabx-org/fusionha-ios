import SwiftUI
import Charts
import FusionhaKit

// The Indexers panel's range-driven fleet overview (`FleetOverview` in
// IndexersPanel.tsx): KPI tiles, grab-share leaderboard, activity chart, the four
// fleet stat cards (IndexerFleetStatCards) and the exclusive-grabs card
// (IndexerExclusiveCard). Drawing bits live in IndexerCharts.

struct IndexerFleetOverview: View {
    let summary: IndexerStatsSummary?
    let metrics: [IndexerMetric]
    @Binding var range: IndexerRange
    @State private var othersOpen = false
    @Environment(\.settingsMotionOff) private var motionOff

    var phrase: String { range.phrase }
    var total: Int { summary?.indexers ?? metrics.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Fleet overview").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("\(total) indexer\(total == 1 ? "" : "s") · \(phrase)")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
                Picker("Date range", selection: $range) {
                    ForEach(IndexerRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            kpis
            leaderboard.fetchReveal(4)
            activityCard.fetchReveal(5)
            protocolMix.fetchReveal(6)
            efficiency.fetchReveal(7)
            coverage.fetchReveal(8)
            apiBudget.fetchReveal(9)
            IndexerExclusiveCard(summary: summary, metrics: metrics).fetchReveal(10)
        }
    }

    // MARK: KPI tiles

    private var kpis: some View {
        let healthy = summary?.healthy ?? 0
        let backoff = summary?.backoff ?? 0
        let off = summary?.off ?? max(0, total - healthy - backoff)
        let activity = summary?.activitySeries ?? []
        let avg = summary?.avgSuccessRange.map { Int(($0 * 100).rounded()) }
        return VStack(spacing: 10) {
            kpiTile {
                Text("\(total)").kpiNumber()
                (Text("\(healthy) healthy").bold().foregroundColor(Theme.done) + Text(" · ")
                    + Text("\(backoff) backoff").bold().foregroundColor(Theme.miss) + Text(" · \(off) off"))
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                IndexerSplitBar(parts: [(Double(healthy), Theme.done), (Double(backoff), Theme.miss), (Double(off), Theme.dim)])
                    .frame(height: 6).padding(.top, 6)
            }
            .fetchReveal(0)
            kpiTile {
                Text(FetchFormat.grouped(summary?.grabsRange ?? 0)).kpiNumber()
                Text("grabs · \(phrase)").kpiLabel()
            }
            .fetchReveal(1)
            kpiTile(trailing: {
                if !activity.isEmpty {
                    IndexerSparkline(values: activity, color: Theme.grab).frame(width: 90, height: 34)
                }
            }) {
                Text(FetchFormat.grouped(summary?.queriesRange ?? 0)).kpiNumber()
                Text("API queries · \(phrase)").kpiLabel()
            }
            .fetchReveal(2)
            kpiTile(trailing: { IndexerRing(value: avg).frame(width: 42, height: 42) }) {
                (Text(verbatim: avg.map { "\($0)" } ?? "—") + Text(verbatim: avg == nil ? "" : "%").font(.system(size: 14, weight: .bold)))
                    .kpiNumber(color: Theme.done)
                Text("avg success · \(phrase)").kpiLabel()
            }
            .fetchReveal(3)
        }
    }

    private func kpiTile<T: View, C: View>(@ViewBuilder trailing: () -> T = { EmptyView() },
                                           @ViewBuilder content: () -> C) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) { content() }
            Spacer(minLength: 0)
            trailing()
        }
        .fetchCard(padding: 14, radius: 14)
    }

    // MARK: Leaderboard

    private struct ShareEntry: Identifiable {
        let id: String
        let name: String
        let pct: Double
        let grabs: Int
        let color: Color
        var isNew = false
        var isOthers = false
    }

    private var shareData: (entries: [ShareEntry], others: [ShareEntry]) {
        let fleet = summary?.grabsRange ?? metrics.reduce(0) { $0 + $1.grabsRange }
        let pct: (Int) -> Double = { fleet > 0 ? Double($0) / Double(fleet) * 100 : 0 }
        let sorted = metrics.filter { $0.grabsRange > 0 }.sorted { $0.grabsRange > $1.grabsRange }
        let top = sorted.prefix(5)
        let rest = sorted.dropFirst(5)
        var entries = top.enumerated().map { i, m in
            ShareEntry(id: "\(m.id)", name: m.indexer.displayName, pct: pct(m.grabsRange), grabs: m.grabsRange,
                       color: indexerSharePalette[i % indexerSharePalette.count], isNew: m.isNew)
        }
        for m in rest where m.isNew {
            entries.append(ShareEntry(id: "\(m.id)", name: m.indexer.displayName, pct: pct(m.grabsRange),
                                      grabs: m.grabsRange, color: Theme.done, isNew: true))
        }
        let plain = rest.filter { !$0.isNew }
        let others = plain.map {
            ShareEntry(id: "\($0.id)", name: $0.indexer.displayName, pct: pct($0.grabsRange), grabs: $0.grabsRange, color: Theme.dim)
        }
        if !plain.isEmpty {
            let restGrabs = plain.reduce(0) { $0 + $1.grabsRange }
            entries.append(ShareEntry(id: "others", name: "\(plain.count) other\(plain.count > 1 ? "s" : "")",
                                      pct: pct(restGrabs), grabs: restGrabs, color: Theme.dim, isOthers: true))
        }
        return (entries, others)
    }

    private var leaderboard: some View {
        let data = shareData
        let newest = metrics.filter { $0.isNew && $0.stat?.createdAt != nil }
            .min { ($0.daysSinceCreated ?? 99) < ($1.daysSinceCreated ?? 99) }
        return VStack(alignment: .leading, spacing: 10) {
            cardTitle("Grab share — who's pulling weight")
            IndexerSplitBar(parts: data.entries.map { ($0.pct, $0.color) }, gap: 2).frame(height: 10)
            VStack(spacing: 6) {
                ForEach(data.entries) { entry in
                    if entry.isOthers {
                        Button {
                            SettingsMotion.perform(motionOff) { othersOpen.toggle() }
                        } label: {
                            legendRow(entry, caret: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(othersOpen ? "Hide the other indexers" : "Show the other indexers")
                    } else {
                        legendRow(entry)
                    }
                }
                if othersOpen {
                    VStack(spacing: 6) {
                        ForEach(data.others) { legendRow($0) }
                    }
                    .padding(.leading, 14)
                    .transition(.opacity)
                }
                if data.entries.isEmpty {
                    Text("No grabs in this window yet.").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let newest {
                HStack(alignment: .top, spacing: 8) {
                    newBadge
                    (Text(newest.indexer.displayName).bold() + Text(verbatim: " added \(agoLabel(newest.daysSinceCreated)) — already \(String(format: "%.1f", newest.share))% of grabs over the \(phrase)."))
                        .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                }
                .padding(10)
                .background(Theme.done.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .fetchCard(padding: 14, radius: 14)
    }

    private func agoLabel(_ days: Int?) -> String {
        guard let days else { return "recently" }
        return days == 0 ? "today" : days == 1 ? "1 day ago" : "\(days) days ago"
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.done)
            .padding(.horizontal, 5)
            .overlay(Capsule().strokeBorder(Theme.done.opacity(0.32)))
    }

    private func legendRow(_ entry: ShareEntry, caret: Bool = false) -> some View {
        HStack(spacing: 8) {
            Circle().fill(entry.color).frame(width: 8, height: 8)
            HStack(spacing: 4) {
                Text(entry.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                if entry.isNew { newBadge }
                if caret {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(othersOpen ? 90 : 0))
                }
            }
            Spacer(minLength: 6)
            Text(String(format: "%.1f%%", entry.pct))
                .font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
            Text("\(FetchFormat.grouped(entry.grabs)) grabs")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                .frame(minWidth: 70, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    // MARK: Activity

    private var activityCard: some View {
        let activity = summary?.activitySeries ?? []
        let peak = activity.max() ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            cardTitle("Activity · \(phrase) (all indexers)")
            (Text(FetchFormat.grouped(summary?.queriesRange ?? 0)) + Text(" queries").font(.system(size: 12)).foregroundColor(Theme.mut))
                .font(.system(size: 24, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.txt)
            Text(peak > 0 ? "peak \(FetchFormat.grouped(peak)) / bucket" : "—")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
            if !activity.isEmpty {
                IndexerActivityChart(values: activity).frame(height: 72).padding(.top, 8)
            }
        }
        .fetchCard(padding: 14, radius: 14)
    }

}

private extension Text {
    func kpiNumber(color: Color = Theme.txt) -> some View {
        self.font(.system(size: 26, weight: .heavy).monospacedDigit()).tracking(-0.5).foregroundStyle(color)
    }
    func kpiLabel() -> some View {
        self.font(.system(size: 11.5)).foregroundStyle(Theme.mut)
    }
}
