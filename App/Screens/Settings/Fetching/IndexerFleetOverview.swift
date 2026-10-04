import SwiftUI
import Charts
import FusionhaKit

// The Indexers panel's range-driven fleet overview (`FleetOverview` in
// IndexersPanel.tsx): KPI tiles, grab-share leaderboard, activity chart, the four
// fleet stat cards and the exclusive-grabs card. Shared drawing bits (sparkline,
// ring, split bars) live here too.

/// One indexer joined with its range-scoped stats (`buildIndexerMetrics`).
struct IndexerMetric: Identifiable {
    let indexer: SearchIndexerInfo
    let stat: IndexerStatRow?
    let grabsRange: Int
    let grabs24h: Int
    let share: Double
    let yieldValue: Double
    let successPct: Int?
    let activity: [Int]
    let state: String
    let isNew: Bool
    var id: Int { indexer.id }

    static func build(_ indexers: [SearchIndexerInfo], stats: IndexerStatsResponse?) -> [IndexerMetric] {
        let byId = Dictionary((stats?.indexers ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let clientFleet = indexers.reduce(0) { $0 + (byId[$1.id]?.grabsRange ?? 0) }
        let fleet = stats?.summary?.grabsRange ?? clientFleet
        return indexers.map { indexer in
            let stat = byId[indexer.id]
            let grabs = stat?.grabsRange ?? 0
            let created = FetchFormat.date(stat?.createdAt)
            return IndexerMetric(
                indexer: indexer,
                stat: stat,
                grabsRange: grabs,
                grabs24h: stat?.grabs24h ?? 0,
                share: fleet > 0 ? Double(grabs) / Double(fleet) * 100 : 0,
                yieldValue: stat?.yieldRange ?? 0,
                successPct: stat?.successRateRange.map { Int(($0 * 100).rounded()) },
                activity: stat?.activitySeries ?? [],
                state: stat?.health.state ?? (indexer.isEnabled ? "healthy" : "disabled"),
                isNew: created.map { Date.now.timeIntervalSince($0) <= 7 * 86_400 } ?? false)
        }
    }

    var daysSinceCreated: Int? {
        FetchFormat.date(stat?.createdAt).map { max(0, Int(Date.now.timeIntervalSince($0) / 86_400)) }
    }
}

enum IndexerRange: String, CaseIterable, Identifiable {
    case day = "24h", week = "7d", month = "30d", all = "all"
    var id: String { rawValue }
    var label: String { self == .all ? "All-time" : rawValue }
    var phrase: String {
        switch self {
        case .day: return "last 24h"
        case .week: return "last 7 days"
        case .month: return "last 30 days"
        case .all: return "all-time"
        }
    }
}

/// The leaderboard colour ramp (`SHARE_PALETTE`).
let indexerSharePalette: [Color] = [Theme.indigo, Theme.cyan, Theme.done, Theme.edition, Theme.miss]

struct IndexerFleetOverview: View {
    let summary: IndexerStatsSummary?
    let metrics: [IndexerMetric]
    @Binding var range: IndexerRange
    @State private var othersOpen = false
    @Environment(\.settingsMotionOff) private var motionOff

    private var phrase: String { range.phrase }
    private var total: Int { summary?.indexers ?? metrics.count }

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
            .font(.system(size: 8.5, weight: .bold))
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
                        .font(.system(size: 9, weight: .bold))
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

    // MARK: Fleet stat cards

    private var protocolMix: some View {
        let pm = summary?.protocolMix
        let us = pm?.usenetGrabShare ?? 0
        let to = pm?.torrentGrabShare ?? 0
        return statCard("Protocol mix") {
            IndexerSplitBar(parts: [(us, Theme.grab), (to, Theme.edition)], gap: 2).frame(height: 8).padding(.bottom, 4)
            statRow(dot: Theme.grab, "Usenet", "\(pm?.usenetCount ?? 0) · \(Int(us.rounded()))%")
            statRow(dot: Theme.edition, "Torrent", "\(pm?.torrentCount ?? 0) · \(Int(to.rounded()))%")
        }
    }

    private var efficiency: some View {
        let eff = summary?.efficiency
        let fmt: (Double?) -> String = { $0.map { String(format: "%.1f/100q", $0) } ?? "—" }
        return statCard("Efficiency · grabs per 100 q") {
            effRow("Top", good: true, eff?.leader?.name, fmt(eff?.leader?.yieldValue))
            effRow("Low", good: false, eff?.laggard?.name, fmt(eff?.laggard?.yieldValue))
            note("Low-yield indexers spend query budget for little return — candidates to de-prioritise.")
        }
    }

    private var coverage: some View {
        let cov = summary?.coverage
        let denom = Double(max(1, summary?.indexers ?? 0))
        let single = cov?.singleSource ?? []
        let rows: [(String, String, Int)] = [("tv", "TV", cov?.tv ?? 0), ("movie", "Movies", cov?.movie ?? 0),
                                              ("anime", "Anime", cov?.anime ?? 0)]
        let singleLabels = rows.filter { single.contains($0.0) }.map(\.1)
        return statCard("Category coverage") {
            ForEach(rows, id: \.0) { row in
                let warn = single.contains(row.0)
                HStack(spacing: 8) {
                    Text(row.1).font(.system(size: 12)).foregroundStyle(warn ? Theme.miss : Theme.txt)
                        .frame(width: 52, alignment: .leading)
                    FetchBar(fraction: min(1, Double(row.2) / denom), color: warn ? Theme.miss : Theme.done, height: 6)
                    Text("\(row.2) src\(row.2 == 1 ? "" : "s")")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.mut)
                        .frame(width: 52, alignment: .trailing)
                }
            }
            if singleLabels.isEmpty {
                note("Every category has ≥2 sources.", color: Theme.done)
            } else {
                note("\(singleLabels.joined(separator: ", ")) single-source — a backoff there stalls those grabs.",
                     color: Theme.miss, icon: "exclamationmark.triangle")
            }
        }
    }

    private var apiBudget: some View {
        let ab = summary?.apiBudget
        let used = ab?.queriesToday ?? 0
        let cap = ab?.totalKnownCap ?? 0
        let near = ab?.nearLimit ?? []
        let ratio: Int? = cap > 0 ? Int((Double(used) / Double(cap) * 100).rounded()) : nil
        return statCard("API query budget") {
            (Text(FetchFormat.grouped(used)) + Text(cap > 0 ? " / \(FetchFormat.grouped(cap))" : "")
                .font(.system(size: 13)).foregroundColor(Theme.mut))
                .font(.system(size: 20, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.txt)
            Text(verbatim: "queries today\(ratio.map { " · \($0)% of cap" } ?? " · no cap set")")
                .font(.system(size: 11)).foregroundStyle(Theme.mut)
            if let ratio {
                FetchBar(fraction: min(1, Double(ratio) / 100), color: ratio >= 80 ? Theme.miss : Theme.grab).padding(.vertical, 4)
            }
            if near.isEmpty {
                note(cap > 0 ? "All indexers well within limits." : "No per-indexer caps configured · \(phrase).", color: Theme.done)
            } else {
                note(near.map { "\($0.name) \($0.queriesToday)/\($0.cap)" }.joined(separator: ", ") + " near limit",
                     color: Theme.miss, icon: "exclamationmark.triangle")
            }
        }
    }

    private func statCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            cardTitle(title)
            content()
        }
        .fetchCard(padding: 14, radius: 14)
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
    }

    private func statRow(dot: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut)
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
        }
    }

    private func effRow(_ tag: String, good: Bool, _ name: String?, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(tag)
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundStyle(good ? Theme.done : Theme.miss)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background((good ? Theme.done : Theme.miss).opacity(0.14), in: Capsule())
            Text(name.map { $0.replacingOccurrences(of: #"\s*\(prowlarr\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive]) } ?? "—")
                .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            Spacer()
            Text(value).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
        }
    }

    private func note(_ text: String, color: Color = Theme.mut, icon: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11)) }
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(color)
        .padding(.top, 2)
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

// MARK: Exclusive grabs

private enum ExclusiveFilter: String, CaseIterable, Identifiable {
    case all, movie, series, anime, hd, uhd
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .movie: return "Movies"
        case .series: return "Series"
        case .anime: return "Anime"
        case .hd: return "HD"
        case .uhd: return "4K"
        }
    }
    var noun: String {
        switch self {
        case .all: return "all"
        case .uhd: return "4K"
        case .hd: return "HD"
        default: return rawValue
        }
    }
}

/// "Exclusive grabs — who's irreplaceable", re-bucketed by the filter chips.
struct IndexerExclusiveCard: View {
    let summary: IndexerStatsSummary?
    let metrics: [IndexerMetric]
    @State private var filter: ExclusiveFilter = .all

    private func bucket(_ ex: IndexerStatsSummary.ExclusiveSummary?) -> IndexerStatsSummary.ExclusiveStat? {
        switch filter {
        case .all: return ex?.all
        case .movie: return ex?.movie
        case .series: return ex?.series
        case .anime: return ex?.anime
        case .hd: return ex?.hd
        case .uhd: return ex?.uhd
        }
    }

    private func count(_ ex: IndexerStatRow.Exclusive?) -> Int {
        switch filter {
        case .all: return ex?.total ?? 0
        case .movie: return ex?.movie ?? 0
        case .series: return ex?.series ?? 0
        case .anime: return ex?.anime ?? 0
        case .hd: return ex?.hd ?? 0
        case .uhd: return ex?.uhd ?? 0
        }
    }

    var body: some View {
        let stat = bucket(summary?.exclusive)
        let rows = metrics.map { (m: $0, n: count($0.stat?.exclusive)) }.filter { $0.n > 0 }.sorted { $0.n > $1.n }
        let maxN = Double(max(1, rows.map(\.n).max() ?? 1))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Exclusive grabs — who’s irreplaceable").font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
            Text("releases that met your quality rules but were on ONLY that indexer")
                .font(.system(size: 11)).foregroundStyle(Theme.mut)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ExclusiveFilter.allCases) { f in
                        Button { filter = f } label: {
                            Text(f.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(filter == f ? Theme.edition : Theme.mut)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(filter == f ? Theme.edition.opacity(0.14) : .clear, in: Capsule())
                                .overlay(Capsule().strokeBorder(filter == f ? Theme.edition.opacity(0.45) : Theme.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(FetchFormat.grouped(stat?.total ?? 0))
                    .font(.system(size: 26, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.edition)
                Text(verbatim: "exclusive grabs · \(String(format: "%.1f", stat?.pct ?? 0))% of \(filter.noun) grabs")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
            }
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.element.m.id) { i, row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(indexerSharePalette[i % indexerSharePalette.count]).frame(width: 7, height: 7)
                            Text(row.m.indexer.displayName).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt)
                                .lineLimit(1)
                            Spacer()
                            (Text(FetchFormat.grouped(row.n)).bold() + Text(" exclusive"))
                                .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                            if let early = row.m.stat?.exclusive?.early, early > 0 {
                                Text("▲\(early) early").font(.system(size: 10.5, weight: .bold)).foregroundStyle(Theme.done)
                            }
                        }
                        FetchBar(fraction: Double(row.n) / maxN, color: Theme.edition, height: 6, delay: Double(i) * 0.07)
                    }
                }
                if rows.isEmpty {
                    Text("No exclusive grabs in this window yet.").font(.system(size: 12)).foregroundStyle(Theme.mut)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text("An indexer’s exclusive grabs are ones no other configured indexer offered — losing it would have cost you that content.")
                .font(.system(size: 11)).foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fetchCard(padding: 14, radius: 14)
    }
}

// MARK: Drawing

/// A stacked horizontal bar of proportional segments that grow in on appear.
struct IndexerSplitBar: View {
    let parts: [(Double, Color)]
    var gap: CGFloat = 2
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let total = max(parts.reduce(0) { $0 + max($1.0, 0) }, 0.0001)
            let usable = geo.size.width - gap * CGFloat(max(parts.count - 1, 0))
            HStack(spacing: gap) {
                ForEach(parts.indices, id: \.self) { i in
                    Capsule()
                        .fill(parts[i].1)
                        .frame(width: max(0, usable * CGFloat(max(parts[i].0, 0) / total)))
                        .scaleEffect(x: motionOff || shown ? 1 : 0, anchor: .leading)
                        .animation(motionOff ? nil : .easeOut(duration: 0.5).delay(Double(i) * 0.06), value: shown)
                }
            }
        }
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .clipShape(Capsule())
        .onAppear { shown = true }
    }
}

/// The small draw-in sparkline: a gradient area under a line with an end dot.
struct IndexerSparkline: View {
    let values: [Int]
    var color: Color = Theme.cyan
    var delay: Double = 0
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if pts.count > 0 {
                    area(pts, size: geo.size)
                        .fill(LinearGradient(colors: [color.opacity(0.45), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .opacity(Double(progress))
                    line(pts)
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    if let end = pts.last {
                        Circle().fill(color).frame(width: 4.4, height: 4.4).position(end).opacity(Double(progress))
                    }
                }
            }
        }
        .onAppear {
            if motionOff { progress = 1 } else {
                withAnimation(.easeOut(duration: 0.9).delay(delay)) { progress = 1 }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxV = Double(max(values.max() ?? 1, 1))
        return values.enumerated().map { i, v in
            let x = values.count > 1 ? CGFloat(i) / CGFloat(values.count - 1) * size.width : size.width / 2
            let y = size.height - CGFloat(Double(v) / maxV) * (size.height - 4) - 2
            return CGPoint(x: x, y: y)
        }
    }

    private func line(_ pts: [CGPoint]) -> Path {
        Path { p in
            p.move(to: pts[0])
            for pt in pts.dropFirst() { p.addLine(to: pt) }
        }
    }

    private func area(_ pts: [CGPoint], size: CGSize) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: size.height))
            for pt in pts { p.addLine(to: pt) }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
        }
    }
}

/// The wide fleet activity chart (Swift Charts): queries per bucket over the range.
struct IndexerActivityChart: View {
    let values: [Int]
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            AreaMark(x: .value("Bucket", i), y: .value("Queries", shown || motionOff ? v : 0))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [Theme.cyan.opacity(0.45), Theme.cyan.opacity(0)],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Bucket", i), y: .value("Queries", shown || motionOff ? v : 0))
                .interpolationMethod(.monotone)
                .foregroundStyle(Theme.cyan)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(1, values.max() ?? 1))
        .onAppear {
            if !motionOff { withAnimation(.easeOut(duration: 0.8)) { shown = true } }
        }
        .accessibilityLabel("Query activity, peak \(values.max() ?? 0) per bucket")
    }
}

/// The avg-success ring in the KPI corner: green ≥ 90 %, amber below.
struct IndexerRing: View {
    let value: Int?
    @Environment(\.settingsMotionOff) private var motionOff
    @State private var shown = false

    var body: some View {
        let v = Double(value ?? 0) / 100
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: motionOff || shown ? v : 0)
                .stroke((value ?? 0) < 90 ? Theme.miss : Theme.done, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(2)
        .onAppear {
            if !motionOff { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
        }
    }
}
