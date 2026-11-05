import SwiftUI
import FusionhaKit

/// A wanted title on the open Duo's right page (mock activity-log.js
/// `wantedSplit`), and in a sheet on the phone: the title, one W1 card per
/// version (ticket, state, the fact behind it), why it is wanted in plain
/// facts (the server sends no rationale, so the app states only what the
/// wire says and links the real decision trails), the searches, then the
/// missing episodes, each with its own search.
struct WantedDecisionPane: View {
    let item: WantedItem
    let tab: WantedTab
    let interval: Int
    @Environment(AppModel.self) private var model
    @Environment(ActToaster.self) private var toaster
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var search = V2WantedSearch()

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            versions
            why
            actions
            if let run = search.gradualRun {
                WantedGradualStrip(itemId: item.id, runId: run, fallbackTotal: search.gradualTotal, interval: interval) {
                    withAnimation(motion ? .easeOut(duration: 0.2) : nil) { search.gradualRun = nil }
                }
                .v2CardStyle(padding: 0)
            }
            episodes
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            V2ScopeThumb(url: item.posterUrl, width: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.system(size: 22, weight: .bold)).foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                let kind = item.isAnime ? "Anime" : (item.kind == .movie ? "Movie" : "Series")
                Text("\(kind) · \(item.editions.count) version\(item.editions.count == 1 ? "" : "s")")
                    .font(.system(size: 13)).foregroundStyle(muted)
            }
        }
    }

    private var versions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) { ForEach(item.editions) { card($0) } }
            VStack(spacing: 10) { ForEach(item.editions) { card($0) } }
        }
    }

    private func card(_ edition: WantedEdition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                EditionBadge(tier: edition.tier, state: V2WantedEditionCopy.badge(edition), showsCount: false)
                Text(V2WantedEditionCopy.words(edition).capitalizedFirst)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
            }
            Text(WantedLogic.cue(item, edition)).font(.system(size: 12.5)).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            if let quality = edition.currentQuality {
                Text("Have \(ActFmt.quality(quality))").font(.system(size: 12.5)).foregroundStyle(muted)
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity, alignment: .leading)
        .v2CardStyle(padding: 14)
        .accessibilityElement(children: .combine)
    }

    private var why: some View {
        VStack(alignment: .leading, spacing: 6) {
            V2ScopeSectionHead(title: "Why it is wanted", systemImage: "questionmark.circle")
            ForEach(item.editions) { edition in
                Text("\(edition.tier.badgeLetters): \(WantedLogic.stateLabel(edition.state).lowercased()), \(WantedLogic.cue(item, edition)).")
                    .font(.system(size: 13.5)).foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("See the decision trails") { model.open(item.id, tab: .searches) }
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .buttonStyle(.plain)
        }
    }

    private var actions: some View {
        ActFlow(spacing: 8, lineSpacing: 8) {
            if tab == .missing || tab == .cutoff {
                V2CapsuleButton(title: "Search all", systemImage: "magnifyingglass", prominent: true,
                                busy: search.searchingKey == "title") {
                    search.run(item, label: item.title, key: "title", client: model.client, toaster: toaster)
                }
                if item.kind == .series {
                    V2CapsuleButton(title: "Missing only", systemImage: "magnifyingglass") {
                        Task { await search.startGradual(item, missingOnly: true, client: model.client, toaster: toaster) }
                    }
                    V2CapsuleButton(title: "Each episode", systemImage: "list.bullet") {
                        Task { await search.startGradual(item, missingOnly: false, client: model.client, toaster: toaster) }
                    }
                } else {
                    V2CapsuleButton(title: "Missing only", systemImage: "magnifyingglass") {
                        search.run(item, label: "\(item.title) (missing only)", key: "title", missingOnly: true,
                                   client: model.client, toaster: toaster)
                    }
                }
            }
            V2CapsuleButton(title: "Interactive", systemImage: "person") { model.interactiveSearch(item.id, tier: nil) }
            V2CapsuleButton(title: "Open title", systemImage: "arrow.up.right.square") { model.open(item.id) }
        }
    }

    private struct MissingRow: Identifiable {
        let episode: WantedEpisode
        var tiers: [QualityTier]
        var id: Int { episode.id }
    }

    /// Every version's missing episodes once (a gap in both versions is one row).
    private var missingEpisodes: [MissingRow] {
        var rows: [MissingRow] = []
        for edition in item.editions {
            for episode in edition.missingEpisodes ?? [] {
                if let index = rows.firstIndex(where: { $0.id == episode.id }) {
                    rows[index].tiers.append(edition.tier)
                } else {
                    rows.append(MissingRow(episode: episode, tiers: [edition.tier]))
                }
            }
        }
        return rows
    }

    @ViewBuilder
    private var episodes: some View {
        let rows = missingEpisodes
        let total = item.editions.map { $0.missingEpisodeCount ?? ($0.missingEpisodes?.count ?? 0) }.max() ?? 0
        if !rows.isEmpty {
            WidgetModule(caption: "Missing episodes", systemImage: "list.bullet") {
                ForEach(rows) { row in episodeRow(row.episode, tiers: row.tiers) }
                if total > rows.count {
                    Text("+\(total - rows.count) more aired episode\(total - rows.count == 1 ? "" : "s") not shown")
                        .font(.system(size: 12.5)).foregroundStyle(muted)
                }
            }
        }
    }

    private func episodeRow(_ episode: WantedEpisode, tiers: [QualityTier]) -> some View {
        let key = "ep-\(episode.seasonNumber)-\(episode.episodeNumber)"
        let aired = episode.airDate.map { " · aired \(ActFmt.releaseDate($0))" } ?? ""
        let versions = tiers.map(\.badgeLetters).joined(separator: " and ")
        return HStack(spacing: 11) {
            Text("E\(episode.episodeNumber)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(ink)
                .frame(width: 30, height: 30)
                .background(ink.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(episode.title ?? "Episode \(episode.episodeNumber)").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink).lineLimit(1)
                Text("S\(episode.seasonNumber) E\(episode.episodeNumber)\(aired) · \(versions) missing")
                    .font(.system(size: 12)).foregroundStyle(muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            V2RoundIconButton(systemImage: "magnifyingglass", label: "Search for \(item.title) \(episode.code)", size: 32,
                              busy: search.searchingKey == key) {
                search.run(item, label: "\(item.title) \(episode.code)", key: key, episodeId: episode.id,
                           client: model.client, toaster: toaster)
            }
        }
    }
}
