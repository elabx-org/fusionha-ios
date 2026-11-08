import SwiftUI
import FusionhaKit

/// "What it found" (mock `finds`): its grabs by kind and by version as two
/// one-ink bars (CLAUDE.md: monochrome, the words name the version).
struct V2IndexerFoundCard: View {
    let metric: IndexerMetric
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }

    var body: some View {
        let cm = metric.stat?.contentMix, tm = metric.stat?.tierMix
        V2IndexerCard(title: "What it found") {
            VStack(alignment: .leading, spacing: 10) {
                mix("Kind", [("Series", cm?.series ?? 0), ("Movies", cm?.movie ?? 0), ("Anime", cm?.anime ?? 0)])
                mix("Version", [("HD", tm?.hd ?? 0), ("4K", tm?.uhd ?? 0)])
            }
        }
    }

    private static let shades = [0.86, 0.52, 0.3]

    private func mix(_ title: String, _ parts: [(String, Int)]) -> some View {
        let total = parts.reduce(0) { $0 + $1.1 }
        var bars: [(Double, Color)] = [(1, ink.opacity(0.06))]
        if total > 0 {
            bars = parts.enumerated().map { index, part in (Double(part.1), ink.opacity(Self.shades[index % 3])) }
        }
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).foregroundStyle(page?.inkMuted ?? Theme.mut)
                Spacer()
                Text(parts.map { "\($0.1) \($0.0)" }.joined(separator: " · "))
                    .monospacedDigit()
                    .foregroundStyle(ink)
            }
            .font(.system(size: 12.5))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            IndexerSplitBar(parts: bars, gap: 1.5)
                .frame(height: 6)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// "What it can search" (mock `can`): the capability chips, its kind scope
/// and the search modes its caps name.
struct V2IndexerSearchCard: View {
    let metric: IndexerMetric

    private var caps: IndexerStatRow.Caps? { metric.stat?.caps }

    var body: some View {
        let indexer = metric.indexer
        let modes = indexer.searchCaps?.keys ?? []
        V2IndexerCard(title: "What it can search") {
            VStack(alignment: .leading, spacing: 8) {
                PreviewFlow(spacing: 5, rowSpacing: 5) {
                    V2IndexerChip(text: "TV", on: caps?.tv == true)
                    V2IndexerChip(text: "Movies", on: caps?.movie == true)
                    V2IndexerChip(text: "Anime", on: caps?.anime == true)
                    V2IndexerChip(text: "ID search", on: caps?.idSearch == true)
                    if indexer.effectiveKindScope != "all" {
                        V2IndexerChip(text: kindScopeLabel(indexer.effectiveKindScope)
                                      + (indexer.kindScopeOverride?.isEmpty == false ? " (manual)" : ""))
                    }
                }
                if !modes.isEmpty {
                    V2IndexerChipLine(label: "Modes", items: modes)
                }
            }
        }
    }
}

/// Its Newznab categories per kind (mock `cats`), by name where known.
struct V2IndexerCategoriesCard: View {
    let indexer: SearchIndexerInfo

    var body: some View {
        let tv = indexer.tvCategories ?? [], movie = indexer.movieCategories ?? [], anime = indexer.animeCategories ?? []
        if !(tv.isEmpty && movie.isEmpty && anime.isEmpty) {
            V2IndexerCard(title: "Categories", trailing: "\(tv.count + movie.count + anime.count)") {
                VStack(alignment: .leading, spacing: 6) {
                    if !tv.isEmpty { V2IndexerChipLine(label: "TV", items: tv.map(V2NewznabCategory.name)) }
                    if !movie.isEmpty { V2IndexerChipLine(label: "Movies", items: movie.map(V2NewznabCategory.name)) }
                    if !anime.isEmpty { V2IndexerChipLine(label: "Anime", items: anime.map(V2NewznabCategory.name)) }
                }
            }
        }
    }
}

/// Newznab's standard category names (mock `CAT`); others show the number.
enum V2NewznabCategory {
    private static let names: [Int: String] = [
        5000: "TV", 5010: "WEB-DL", 5020: "Foreign", 5030: "SD", 5040: "HD", 5045: "UHD", 5050: "Other",
        5060: "Sport", 5070: "Anime", 5080: "Documentary",
        2000: "Movies", 2010: "Foreign", 2020: "Other", 2030: "SD", 2040: "HD", 2045: "UHD", 2050: "BluRay",
        2060: "3D", 2070: "DVD", 2080: "WEB-DL",
    ]

    static func name(_ id: Int) -> String { names[id] ?? "\(id)" }
}

/// A quiet chip; `on` lifts it to the done green (a capability it has).
struct V2IndexerChip: View {
    let text: String
    var on: Bool?
    @Environment(\.pagePalette) private var page

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(on == true ? Theme.done : on == false ? (page?.inkMuted ?? Theme.mut) : ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(on == true ? Theme.done.opacity(0.16) : ink.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(on == false ? "\(text), not supported" : text)
    }
}

/// "TV  HD  UHD  Foreign …": a muted label then chips, wrapping.
struct V2IndexerChipLine: View {
    let label: String
    let items: [String]
    @Environment(\.pagePalette) private var page

    var body: some View {
        PreviewFlow(spacing: 5, rowSpacing: 5) {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .padding(.vertical, 4)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                V2IndexerChip(text: item)
            }
        }
    }
}
