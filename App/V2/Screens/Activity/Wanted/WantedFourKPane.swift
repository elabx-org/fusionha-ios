import SwiftUI
import FusionhaKit

/// A title seen in 4K, on the open Duo's right page (mock activity-log.js
/// `wantedSplit` 4K state), and in a sheet on the phone: what you have, the
/// best 4K release seen (where it was seen, its formats, per season), then
/// Add 4K version (v1's add-edition sheet), Check for 4K now and Open title.
/// Nothing is grabbed until you add the version.
struct WantedFourKPane: View {
    let item: FourKAvailableItem
    let add: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @State private var checking = false

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                V2ScopeThumb(url: item.posterUrl, width: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.system(size: 22, weight: .bold)).foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        EditionBadge(tier: .hd, state: .onDisk, showsCount: false)
                        EditionBadge(tier: .uhd, state: .missing, showsCount: false)
                        Text(V2FourKCopy.owned(item)).font(.system(size: 13)).foregroundStyle(muted)
                    }
                }
            }
            V2ScopeSectionHead(title: "Best 4K release seen", systemImage: "sparkles")
            best
            if let seasons = item.seasons, !seasons.isEmpty {
                WidgetModule(caption: "By season", systemImage: "square.stack") {
                    ForEach(seasons) { season in seasonRow(season) }
                }
            }
            V2ScopeSectionHead(title: "Add a 4K version", systemImage: "plus.circle")
            Text("fusionha only reports what it has seen; nothing is grabbed until you add the version.")
                .font(.system(size: 13)).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            ActFlow(spacing: 8, lineSpacing: 8) {
                V2CapsuleButton(title: "Add 4K version", systemImage: "plus", prominent: true, action: add)
                V2CapsuleButton(title: "Check for 4K now", systemImage: "magnifyingglass", busy: checking) { check() }
                V2CapsuleButton(title: "Open title", systemImage: "arrow.up.right.square") { model.open(item.id) }
            }
        }
    }

    private var best: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.bestReleaseName ?? item.bestQuality.map { ActFmt.quality($0) } ?? "A 2160p release")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(V2FourKCopy.seen(item)).font(.system(size: 12.5)).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            let sources = V2FourKCopy.sources(item.sources, item.source)
            if !sources.isEmpty {
                Text("Seen via \(sources.joined(separator: " and "))").font(.system(size: 12.5)).foregroundStyle(muted)
            }
            if let tags = item.formatTags, !tags.isEmpty {
                ActFlow(spacing: 5, lineSpacing: 5) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                        Text(tag.label)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 14)
    }

    private func seasonRow(_ season: FourKSeason) -> some View {
        HStack(spacing: 11) {
            Text(String(format: "S%02d", season.seasonNumber))
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(ink)
                .frame(minWidth: 36, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(season.bestReleaseName ?? "Seen \(season.seenCount)×").font(.system(size: 13)).foregroundStyle(ink)
                    .lineLimit(1).truncationMode(.middle)
                let sources = V2FourKCopy.sources(nil, season.source)
                Text(([season.bestQuality.map { ActFmt.quality($0) }] + sources.map { Optional($0) })
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12)).foregroundStyle(muted).lineLimit(1)
            }
        }
    }

    private func check() {
        checking = true
        Task {
            defer { checking = false }
            do {
                let result = try await model.client?.activityCheckFourK(itemId: item.id)
                let message = result?.message ?? ""
                toaster.show(message.isEmpty ? "Checked \(item.title) for 4K." : message,
                             tone: result?.foundUhd == true ? .success : .info)
            } catch {
                toaster.error(error)
            }
        }
    }
}

extension V2FourKCopy {
    private static let sourceLabels: [String: String] = [
        "rss": "RSS", "manual": "Manual search", "observed": "Auto search", "probe": "Probe", "check": "Checked",
    ]

    /// Where a 4K release was seen, in words (v1 `fourKSources`).
    static func sources(_ sources: [String]?, _ source: String?) -> [String] {
        let raw = (sources?.isEmpty == false ? sources : source.map { [$0] }) ?? []
        var out: [String] = []
        for s in raw { if let label = sourceLabels[s], !out.contains(label) { out.append(label) } }
        return out
    }
}
