import SwiftUI
import Charts
import FusionhaKit

// MARK: - Indexers tab (FleetOverview)

struct ActivityIndexersTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actReduceMotion) private var reduce
    @State private var range = "7d"
    @State private var stats: ActivityIndexerStats?
    @State private var failed = false
    @State private var othersOpen = false
    @State private var grown = false

    private static let ranges: [(String, String)] = [("24h", "24h"), ("7d", "7d"), ("30d", "30d"), ("all", "All-time")]
    private static var palette: [Color] { [Theme.indigo, Theme.cyan, Theme.done, Theme.edition, Theme.miss] }

    private var phrase: String {
        switch range {
        case "24h": return "last 24h"
        case "30d": return "last 30 days"
        case "all": return "all-time"
        default: return "last 7 days"
        }
    }

    var body: some View {
        ActivityPage {
            VStack(alignment: .leading, spacing: 14) {
                header
                if let stats {
                    kpis(stats)
                    shareCard(stats)
                    activityCard(stats.summary)
                } else if failed {
                    ActEmpty(message: "Indexer stats could not be loaded. Check the backend and try again.")
                } else {
                    ActEmpty(message: "Loading indexer stats…")
                }
            }
        }
        .task(id: range) {
            do {
                let result = try await model.client?.activityIndexerStats(range: range)
                if reduce { stats = result } else { withAnimation(ActMotion.reveal()) { stats = result } }
                failed = false
                grown = false
                if reduce { grown = true } else { withAnimation(ActMotion.reveal(0.7).delay(0.05)) { grown = true } }
            } catch {
                failed = stats == nil
            }
        }
    }

    private var header: some View {
        ActFlow(spacing: 10, lineSpacing: 8) {
            Text("Fleet overview").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
            let total = stats?.summary.indexers ?? 0
            Text("\(ActFmt.plural(total, "indexer")) · \(phrase)").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
            ActSegment(options: Self.ranges, selection: $range)
        }
    }

    private func kpis(_ s: ActivityIndexerStats) -> some View {
        let summary = s.summary
        let total = summary.indexers
        let off = summary.off
        let avg = summary.avgSuccessRange.map { Int(($0 * 100).rounded()) }
        return Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
            kpiTile {
                kpiNumber("\(total)")
                (Text("\(summary.healthy) healthy").bold().foregroundColor(Theme.done) + Text(" · ")
                 + Text("\(summary.backoff) backoff").bold().foregroundColor(Theme.miss) + Text(" · \(off) off"))
                    .font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
                healthMix([(summary.healthy, Theme.done), (summary.backoff, Theme.miss), (off, Theme.dim)])
                    .padding(.top, 10)
            }
            kpiTile {
                kpiNumber((summary.grabsRange ?? 0).formatted())
                Text("grabs · \(phrase)").font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
            }
            }
            GridRow {
            kpiTile {
                kpiNumber((summary.queriesRange ?? 0).formatted())
                Text("API queries · \(phrase)").font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
                if let series = summary.activitySeries, !series.isEmpty {
                    sparkline(series, color: Theme.grab).frame(width: 90, height: 34).padding(.top, 6)
                }
            }
            kpiTile {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        Circle().stroke(Theme.txt.opacity(0.08), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(avg ?? 0) / 100 * (grown ? 1 : 0))
                            .stroke((avg ?? 0) < 90 ? Theme.miss : Theme.done, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 34, height: 34)
                    (Text(avg.map { "\($0)" } ?? "—") + Text(avg == nil ? "" : "%").font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.dim))
                        .font(.system(size: 30, weight: .heavy).monospacedDigit())
                        .tracking(-0.9)
                        .foregroundStyle(Theme.done)
                }
                Text("avg success · \(phrase)").font(.system(size: 11.5)).foregroundStyle(Theme.mut).padding(.top, 7)
            }
            }
        }
    }

    private func kpiTile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 84, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func kpiNumber(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .heavy).monospacedDigit())
            .tracking(-0.9)
            .foregroundStyle(Theme.txt)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }

    /// The healthy / backoff / off mix bar (`flex: n` segments, scaleX in).
    private func healthMix(_ segs: [(Int, Color)]) -> some View {
        let weights = segs.map { max(Double($0.0), 0.001) }
        let sum = weights.reduce(0, +)
        return GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(segs.indices, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(segs[i].1)
                        .frame(width: max(0, (geo.size.width - CGFloat(segs.count - 1) * 2) * CGFloat(weights[i] / sum)))
                }
            }
            .scaleEffect(x: grown ? 1 : 0, anchor: .leading)
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private struct Share: Identifiable {
        let id: String
        let name: String
        let pct: Double
        let grabs: Int
        let color: Color
        let isOthers: Bool
    }

    private func shareCard(_ s: ActivityIndexerStats) -> some View {
        let fleet = s.summary.grabsRange ?? s.indexers.reduce(0) { $0 + ($1.grabsRange ?? 0) }
        let sorted = s.indexers.filter { ($0.grabsRange ?? 0) > 0 }.sorted { ($0.grabsRange ?? 0) > ($1.grabsRange ?? 0) }
        let share: (Int) -> Double = { fleet > 0 ? Double($0) / Double(fleet) * 100 : 0 }
        var entries: [Share] = sorted.prefix(5).enumerated().map { i, ix in
            Share(id: "\(ix.id)", name: ix.name, pct: share(ix.grabsRange ?? 0), grabs: ix.grabsRange ?? 0,
                  color: Self.palette[i % Self.palette.count], isOthers: false)
        }
        let rest = Array(sorted.dropFirst(5))
        if !rest.isEmpty {
            let restGrabs = rest.reduce(0) { $0 + ($1.grabsRange ?? 0) }
            entries.append(Share(id: "others", name: "\(rest.count) other\(rest.count > 1 ? "s" : "")", pct: share(restGrabs),
                                 grabs: restGrabs, color: Theme.dim, isOthers: true))
        }
        let others = rest.map { Share(id: "\($0.id)", name: $0.name, pct: share($0.grabsRange ?? 0), grabs: $0.grabsRange ?? 0, color: Theme.dim, isOthers: false) }
        return VStack(alignment: .leading, spacing: 12) {
            cardHeading("Grab share — who's pulling weight")
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(entries) { e in
                        Rectangle().fill(e.color)
                            .frame(width: max(0, (geo.size.width - CGFloat(max(entries.count - 1, 0)) * 2) * CGFloat(e.pct / 100)))
                    }
                    Spacer(minLength: 0)
                }
                .scaleEffect(x: grown ? 1 : 0, anchor: .leading)
            }
            .frame(height: 14)
            .background(Theme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entries) { e in
                    if e.isOthers {
                        Button {
                            if reduce { othersOpen.toggle() } else { withAnimation(.easeOut(duration: 0.2)) { othersOpen.toggle() } }
                        } label: {
                            legendRow(e, caret: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        legendRow(e, caret: false)
                    }
                }
                if othersOpen {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(others) { o in legendRow(o, caret: false) }
                    }
                    .padding(.leading, 18)
                }
                if entries.isEmpty {
                    Text("No grabs in this window yet.").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func legendRow(_ e: Share, caret: Bool) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 3).fill(e.color).frame(width: 9, height: 9)
            HStack(spacing: 4) {
                Text(e.name).foregroundStyle(Theme.txt).lineLimit(1)
                if caret {
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(othersOpen ? 90 : 0))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.1f%%", e.pct)).font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.txt)
            Text("\(e.grabs.formatted()) grabs").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        }
        .font(.system(size: 12.5))
        .contentShape(Rectangle())
    }

    private func activityCard(_ summary: ActivityIndexerSummary) -> some View {
        let series = summary.activitySeries ?? []
        let peak = series.max() ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            cardHeading("Activity · \(phrase) (all indexers)")
            (Text((summary.queriesRange ?? 0).formatted()) + Text(" queries").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.dim))
                .font(.system(size: 24, weight: .heavy).monospacedDigit())
                .foregroundStyle(Theme.txt)
            Text(peak > 0 ? "peak \(peak.formatted()) / bucket" : "—")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.dim)
                .padding(.top, 2)
            if !series.isEmpty {
                sparkline(series, color: Theme.cyan).frame(height: 72).padding(.top, 10)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }

    private func cardHeading(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.95)
            .foregroundStyle(Theme.dim)
            .padding(.bottom, 12)
    }

    private func sparkline(_ values: [Int], color: Color) -> some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("Bucket", index), y: .value("Queries", grown ? value : 0))
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Bucket", index), y: .value("Queries", grown ? value : 0))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(values.max() ?? 0, 1))
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}
