import SwiftUI
import FusionhaKit

/// "Coverage and budget" (mock `extras`): how many indexers search each
/// kind, today's API budget, the most and least efficient indexer and the
/// protocol split, from the stats summary. Rows the server left out are
/// left out here.
struct V2IndexerCoverageCard: View {
    let summary: IndexerStatsSummary

    private struct Fact: Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    private var facts: [Fact] {
        var out: [Fact] = []
        if let c = summary.coverage {
            if let tv = c.tv { out.append(Fact(title: "Series", value: count(tv))) }
            if let movie = c.movie { out.append(Fact(title: "Movies", value: count(movie))) }
            if let anime = c.anime { out.append(Fact(title: "Anime", value: count(anime))) }
            if let single = c.singleSource, !single.isEmpty {
                out.append(Fact(title: "Only one source", value: single.joined(separator: ", ")))
            }
        }
        if let budget = summary.apiBudget, let today = budget.queriesToday {
            let cap = (budget.totalKnownCap ?? 0) > 0 ? "of \(FetchFormat.grouped(budget.totalKnownCap ?? 0))" : "no caps"
            out.append(Fact(title: "API budget", value: "\(FetchFormat.grouped(today)) today · \(cap)"))
            for near in budget.nearLimit ?? [] {
                out.append(Fact(title: "Near its cap", value: "\(near.name) · \(near.queriesToday) of \(near.cap)"))
            }
        }
        if let leader = summary.efficiency?.leader {
            out.append(Fact(title: "Most efficient", value: efficiency(leader)))
        }
        if let laggard = summary.efficiency?.laggard {
            out.append(Fact(title: "Least efficient", value: efficiency(laggard)))
        }
        if let mix = summary.protocolMix {
            out.append(Fact(title: "Protocols", value: "Usenet \(mix.usenetCount ?? 0) · Torrent \(mix.torrentCount ?? 0)"))
        }
        return out
    }

    var body: some View {
        let list = facts
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                V2SettingsGroupHeader(title: "Coverage and budget")
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, fact in
                        V2SettingsValueRow(title: fact.title, value: fact.value, chevron: false)
                            .overlay(alignment: .top) {
                                if index > 0 { V2SettingsHairline() }
                            }
                    }
                }
                .v2CardStyle(padding: 0)
            }
        }
    }

    private func count(_ n: Int) -> String { "\(n) indexer\(n == 1 ? "" : "s")" }

    private func efficiency(_ entry: IndexerStatsSummary.EfficiencyEntry) -> String {
        "\(entry.name) · " + String(format: "%.1f", entry.yieldValue) + " / 100 q"
    }
}
