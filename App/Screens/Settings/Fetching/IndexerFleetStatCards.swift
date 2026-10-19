import SwiftUI
import FusionhaKit

// The fleet overview's four stat cards: protocol mix, efficiency, coverage
// and the API budget (`FleetOverview` in IndexersPanel.tsx).

extension IndexerFleetOverview {
    var protocolMix: some View {
        let pm = summary?.protocolMix
        let us = pm?.usenetGrabShare ?? 0
        let to = pm?.torrentGrabShare ?? 0
        return statCard("Protocol mix") {
            IndexerSplitBar(parts: [(us, Theme.grab), (to, Theme.edition)], gap: 2).frame(height: 8).padding(.bottom, 4)
            statRow(dot: Theme.grab, "Usenet", "\(pm?.usenetCount ?? 0) · \(Int(us.rounded()))%")
            statRow(dot: Theme.edition, "Torrent", "\(pm?.torrentCount ?? 0) · \(Int(to.rounded()))%")
        }
    }

    var efficiency: some View {
        let eff = summary?.efficiency
        let fmt: (Double?) -> String = { $0.map { String(format: "%.1f/100q", $0) } ?? "—" }
        return statCard("Efficiency · grabs per 100 q") {
            effRow("Top", good: true, eff?.leader?.name, fmt(eff?.leader?.yieldValue))
            effRow("Low", good: false, eff?.laggard?.name, fmt(eff?.laggard?.yieldValue))
            note("Low-yield indexers spend query budget for little return — candidates to de-prioritise.")
        }
    }

    var coverage: some View {
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

    var apiBudget: some View {
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

    func statCard<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            cardTitle(title)
            content()
        }
        .fetchCard(padding: 14, radius: 14)
    }

    func cardTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
    }

    func statRow(dot: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.mut)
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.txt)
        }
    }

    func effRow(_ tag: String, good: Bool, _ name: String?, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(tag)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(good ? Theme.done : Theme.miss)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background((good ? Theme.done : Theme.miss).opacity(0.14), in: Capsule())
            Text(name.map { $0.replacingOccurrences(of: #"\s*\(prowlarr\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive]) } ?? "—")
                .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            Spacer()
            Text(value).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
        }
    }

    func note(_ text: String, color: Color = Theme.mut, icon: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 5) {
            if let icon { Image(systemName: icon).font(.system(size: 11)) }
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(color)
        .padding(.top, 2)
    }
}
