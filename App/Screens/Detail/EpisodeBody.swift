import SwiftUI
import FusionhaKit

// The Seasons tab: an episode row's expanded body (DetailEpisodes).

/// The expanded body: one facts block per scoped edition, then the actions.
struct EpisodeBody: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let season: Season
    let episode: Episode
    let code: String

    var body: some View {
        let editions = store.scopedEditions
        VStack(alignment: .leading, spacing: 12) {
            ForEach(editions) { edition in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(edition.label).font(.system(size: 11, weight: .heavy)).foregroundStyle(DetailTokens.tier(edition.tier))
                        Spacer(minLength: 0)
                        EpisodeStatusChip(episode: episode, edition: edition)
                    }
                    if let file = episode.file(for: edition.id) {
                        facts(file)
                    } else {
                        Text("No file for this version.").font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    }
                }
                .padding(14)
                // A well inside the season card, not a card on a card.
                .background(Theme.txt.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
            }
            if model.me?.can("search") ?? true {
                HStack(spacing: 8) {
                    SearchActionButton(label: code, editionId: store.scopeEditionId, episodeId: episode.id,
                                       size: 44, glyph: 16, bordered: true)
                    interactive(editions)
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    private func facts(_ file: MovieFile) -> some View {
        let probe = file.mediaInfo?.probe
        var rows: [(String, String)] = [("Quality", DetailText.quality(file.quality)), ("Size", DetailText.bytes(file.size))]
        if let v = DetailMediaFacts.audio(probe) { rows.append(("Audio", v)) }
        if let v = DetailMediaFacts.codec(probe) { rows.append(("Codec", v)) }
        if let v = DetailMediaFacts.range(probe) { rows.append(("Range", v)) }
        if let v = file.releaseGroup, !v.isEmpty { rows.append(("Group", v)) }
        if let v = file.cfScore { rows.append(("CF", v >= 0 ? "+\(v)" : "\(v)")) }
        if let v = file.languages, !v.isEmpty { rows.append(("Languages", v.joined(separator: ", "))) }
        if let v = file.releaseType, !v.isEmpty, v != "unknown" { rows.append(("Release Type", v)) }
        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                         alignment: .leading, spacing: 10) {
            ForEach(rows.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(rows[i].0).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.dim)
                    Text(rows[i].1)
                        .font(.system(size: 12.5, design: rows[i].0 == "Size" ? Font.Design.monospaced : Font.Design.default))
                        .foregroundStyle(rows[i].0 == "Size" ? Theme.mut : Theme.txt)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// ManualSearchTrigger: direct with one version, else "Search which version?".
    @ViewBuilder
    private func interactive(_ editions: [DetailEdition]) -> some View {
        let all = detail.orderedEditions
        if all.count == 1, let only = all.first {
            DetailSquareAction(systemImage: "person", label: "Interactive search") {
                store.interactive = InteractiveTarget(editionIds: [only.id], episodeId: episode.id,
                                                      subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
            }
        } else {
            Menu {
                Section("Search which version?") {
                    ForEach(all) { edition in
                        Button {
                            store.interactive = InteractiveTarget(editionIds: [edition.id], episodeId: episode.id,
                                                                  subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
                        } label: {
                            Text(edition.label)
                            Text(episode.file(for: edition.id) == nil
                                 ? "missing — most likely what you want · 1 query"
                                 : "has a file · re-search for an upgrade · 1 query")
                        }
                    }
                    Button {
                        store.interactive = InteractiveTarget(editionIds: all.map(\.id), episodeId: episode.id,
                                                              subtitle: "S\(season.seasonNumber)·E\(episode.episodeNumber)")
                    } label: {
                        Text("All versions")
                        Text("search every version · tiers × versions · \(all.count) queries")
                    }
                }
            } label: {
                Image(systemName: "person")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.txt)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("Interactive search")
        }
    }
}
