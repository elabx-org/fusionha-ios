import SwiftUI
import FusionhaKit

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
                                Text("▲\(early) early").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.done)
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
