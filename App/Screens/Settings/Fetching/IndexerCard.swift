import SwiftUI
import FusionhaKit

// The indexer performance card (`IndexersPanel.tsx`), split from IndexersPanel.

private let capChips: [(String, String)] = [("tv", "TV"), ("movie", "Movies"), ("anime", "Anime"), ("id_search", "id-search")]

func kindScopeLabel(_ scope: String) -> String {
    switch scope {
    case "anime": return "Anime only"
    case "non_anime": return "Non-anime"
    default: return "All series"
    }
}

struct IndexerCard: View {
    let metric: IndexerMetric
    let index: Int
    let maxShare: Double
    let maxYield: Double
    let result: ConnectionTestResult?
    let testing: Bool
    let onToggle: (Bool) -> Void
    let onTest: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var indexer: SearchIndexerInfo { metric.indexer }
    private var stateColor: Color {
        metric.state == "backoff" ? Theme.miss : metric.state == "disabled" ? Theme.dim : Theme.done
    }
    private var sparkColor: Color {
        metric.state == "backoff" ? Theme.miss : metric.state == "disabled" ? Theme.dim : Theme.grab
    }
    private var delay: Double { Double(min(index, 10)) * 0.045 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            top
            metricsGrid
            mixRow
            if metric.state == "backoff" { backoffStrip }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [stateColor.opacity(0.10), stateColor.opacity(0)], startPoint: .leading, endPoint: .center),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(metric.state == "backoff" ? Theme.miss.opacity(0.35) : Theme.line))
        .opacity(metric.state == "disabled" ? 0.72 : 1)
    }

    private var top: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(stateColor).frame(width: 8, height: 8)
                    .background(Circle().fill(stateColor.opacity(0.18)).padding(-3))
                    .padding(.top, 6)
                FetchFlow(spacing: 6, lineSpacing: 5) {
                    Text(indexer.displayName).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(1)
                    if indexer.source == "prowlarr" {
                        Text("P")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Color(hex: 0xE66001), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .accessibilityLabel("Synced from Prowlarr")
                    }
                    let tint = indexer.isTorrent ? Theme.grab : Theme.indigo
                    Text(indexer.isTorrent ? "TORRENT" : "USENET")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(tint.opacity(0.4)))
                    Text("· pri \(indexer.priority)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Theme.dim)
                    if metric.isNew { FetchChip(text: "NEW", color: Theme.done, border: Theme.done.opacity(0.32), size: 8.5) }
                    if testing {
                        ProgressView().controlSize(.mini)
                    } else if let result {
                        FetchPill(text: result.ok ? "Connected" : "Failed", tone: result.ok ? .ok : .err)
                    }
                }
            }
            FetchFlow(spacing: 5, lineSpacing: 5) {
                ForEach(capChips, id: \.0) { key, label in
                    let on = capOn(key)
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(on ? Theme.txt : Theme.mut)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(on ? Theme.panel2 : .clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                }
                let scope = indexer.effectiveKindScope
                if scope != "all" {
                    Text(kindScopeLabel(scope) + (indexer.kindScopeOverride?.isEmpty == false ? " (manual)" : ""))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.panel2, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line))
                }
            }
            if let result, !result.ok {
                Text(result.message).font(.system(size: 11.5)).foregroundStyle(Theme.danger).lineLimit(3)
            }
            HStack(spacing: 4) {
                if metric.state == "backoff" {
                    Text("backoff")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Theme.miss)
                        .padding(.horizontal, 9).padding(.vertical, 2)
                        .background(Theme.miss.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.miss.opacity(0.3)))
                }
                Spacer()
                Toggle("Enable \(indexer.displayName)", isOn: Binding(get: { indexer.isEnabled }, set: onToggle))
                    .labelsHidden()
                    .tint(Theme.indigo)
                FetchIconButton(systemName: "bolt", label: "Test \(indexer.displayName)", action: onTest)
                    .disabled(testing)
                FetchIconButton(systemName: "pencil", label: "Edit \(indexer.displayName)", action: onEdit)
                FetchIconButton(systemName: "trash", label: "Delete \(indexer.displayName)", danger: true, action: onDelete)
            }
        }
    }

    private func capOn(_ key: String) -> Bool {
        let caps = metric.stat?.caps
        switch key {
        case "tv": return caps?.tv == true
        case "movie": return caps?.movie == true
        case "anime": return caps?.anime == true
        default: return caps?.idSearch == true
        }
    }

    private var metricsGrid: some View {
        let lowYield = maxYield > 0 ? metric.yieldValue <= maxYield * 0.25 : true
        return Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 14) {
            GridRow(alignment: .bottom) {
                cell("Grabs") {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(FetchFormat.grouped(metric.grabsRange)).metricValue()
                        if metric.grabs24h > 0 {
                            Text("▲\(metric.grabs24h)").font(.system(size: 10.5, weight: .bold)).foregroundStyle(Theme.done)
                        }
                    }
                    Text(metric.grabs24h > 0 ? "\(metric.grabs24h) in 24h" : "none in 24h").metricSub()
                }
                cell("Grab share") {
                    Text(verbatim: String(format: "%.1f%%", metric.share)).metricValue()
                    FetchBar(fraction: metric.share / maxShare, color: Theme.indigo, height: 5, delay: delay + 0.12)
                }
                cell("Activity") {
                    IndexerSparkline(values: metric.activity, color: sparkColor, delay: delay).frame(height: 34)
                }
            }
            GridRow(alignment: .bottom) {
                cell("Yield") {
                    (Text("\(Int(metric.yieldValue.rounded()))") + Text("/100 q").font(.system(size: 10)).foregroundColor(Theme.mut))
                        .metricValue()
                    FetchBar(fraction: metric.yieldValue / maxYield, color: lowYield ? Theme.miss : Theme.done,
                             height: 5, delay: delay + 0.18)
                }
                cell("Success") {
                    Text(metric.successPct.map { "\($0)%" } ?? "—")
                        .metricValue(color: metric.successPct == nil ? Theme.dim : (metric.successPct ?? 100) < 100 ? Theme.miss : Theme.txt)
                    Text("7-day").metricSub()
                }
                cell("Last used") {
                    Text(metric.stat?.lastUsedAt.map { FetchFormat.ago($0) } ?? "—")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                }
            }
        }
    }

    private func cell<C: View>(_ key: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mixRow: some View {
        let cm = metric.stat?.contentMix
        let tm = metric.stat?.tierMix
        let movie = cm?.movie ?? 0, series = cm?.series ?? 0, anime = cm?.anime ?? 0
        let hd = tm?.hd ?? 0, uhd = tm?.uhd ?? 0
        let excl = metric.stat?.exclusive?.total ?? 0
        let early = metric.stat?.exclusive?.early
        return VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(Theme.line).frame(height: 1)
            mixGroup("Content", parts: [(Double(movie), Theme.indigo), (Double(series), Theme.cyan), (Double(anime), Theme.edition)],
                     legend: [("\(movie) film", Theme.indigo), ("\(series) tv", Theme.cyan), ("\(anime) anime", Theme.edition)])
            mixGroup("Tier", parts: [(Double(hd), Theme.premiere), (Double(uhd), Theme.cyan)],
                     legend: [("\(hd) HD", Theme.premiere), ("\(uhd) 4K", Theme.cyan)])
            VStack(alignment: .leading, spacing: 3) {
                mixKey("Exclusive")
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(FetchFormat.grouped(excl)).font(.system(size: 15, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.edition)
                    Text("\(early.map { $0 > 0 ? "\($0) early · " : "" } ?? "")only this indexer had it")
                        .font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                }
            }
        }
    }

    private func mixKey(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(0.8).foregroundStyle(Theme.dim)
    }

    private func mixGroup(_ key: String, parts: [(Double, Color)], legend: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            mixKey(key)
            IndexerSplitBar(parts: parts.allSatisfy { $0.0 == 0 } ? [(1, Theme.txt.opacity(0.06))] : parts, gap: 0)
                .frame(height: 6)
            HStack(spacing: 10) {
                ForEach(legend, id: \.0) { text, color in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
                        Text(text).font(.system(size: 10.5)).foregroundStyle(Theme.mut)
                    }
                }
            }
        }
    }

    private var backoffStrip: some View {
        let health = metric.stat?.health
        return HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 12))
            Text("\(health?.failureCount ?? 0) consecutive failures\(health?.lastFailureReason.map { " · \($0)" } ?? "")")
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            (Text("auto-") + Text(retryHint(health?.disabledTill)).bold())
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Theme.miss)
        .padding(10)
        .background(Theme.miss.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func retryHint(_ till: String?) -> String {
        guard let date = FetchFormat.date(till) else { return "retrying" }
        let mins = Int((date.timeIntervalSinceNow / 60).rounded())
        if mins <= 0 { return "retrying" }
        if mins < 60 { return "retry in \(mins)m" }
        return "retry in \(Int((Double(mins) / 60).rounded()))h"
    }
}

private extension Text {
    func metricValue(color: Color = Theme.txt) -> some View {
        self.font(.system(size: 17, weight: .heavy).monospacedDigit()).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
    }
    func metricSub() -> some View {
        self.font(.system(size: 10.5)).foregroundStyle(Theme.mut).lineLimit(1)
    }
}
