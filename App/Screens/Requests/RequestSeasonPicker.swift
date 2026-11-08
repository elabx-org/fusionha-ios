import SwiftUI
import FusionhaKit

/// The series scope picker (web `SeasonRow` + `useSeasonSelection`): tick a
/// whole season (sent as `seasons`), or expand one and tick episodes (sent as
/// `episodes`, only those not covered by a whole season). Nothing ticked asks
/// for the whole series.
struct RequestSeasonPicker: View {
    let pick: MediaSearchResult
    let preview: MediaPreviewDetail?
    let loaded: Bool
    @Binding var selSeasons: Set<Int>
    @Binding var selEpisodes: Set<EpisodeRef>
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openSeasons: Set<Int> = []
    @State private var episodeTitles: [Int: [Int: String]] = [:]

    static let hint = "Tick a whole season, or expand for specific episodes. Select nothing to request the whole series."
    private var v2: Bool { ProductLook.isV2 }

    @ViewBuilder
    var body: some View {
        if !loaded {
            Text("Loading seasons…").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
        } else if let list = preview?.seasons, !list.isEmpty {
            if ProductLook.isV2 {
                // v2: one inset-grouped card of season rows (look pass family 5).
                VStack(alignment: .leading, spacing: 8) {
                    RequestGroupCard {
                        ForEach(Array(list.enumerated()), id: \.element.id) { index, season in
                            if index > 0 { RequestRowDivider() }
                            seasonRow(season)
                        }
                    }
                    Text(Self.hint).font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .padding(.horizontal, 12).padding(.top, 2)
                }
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(list) { season in seasonRow(season) }
                    Text(Self.hint)
                        .font(.system(size: 11.5)).foregroundStyle(Theme.dim)
                        .padding(.top, 1)
                }
            }
        } else {
            Text("No season data available.").font(.system(size: 12.5)).foregroundStyle(Theme.dim)
        }
    }

    private func seasonRow(_ season: PreviewSeason) -> some View {
        let n = season.seasonNumber
        let full = selSeasons.contains(n)
        let open = openSeasons.contains(n)
        let label = n == 0 ? "Specials" : "Season \(n)"
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { toggleSeason(season) } label: {
                    Group {
                        if v2 { RequestCheckCircle(checked: full) } else { WebCheckSquare(checked: full) }
                    }
                    .frame(width: v2 ? 54 : 44, height: v2 ? 56 : 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Select \(label)")
                Button {
                    withAnimation(DiscoverMotion.reduced(reduceMotion) ? nil : .easeOut(duration: 0.2)) {
                        if open { openSeasons.remove(n) } else { openSeasons.insert(n) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if v2 {
                            // v2: "Season 1" over "8 eps", as a list row.
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label).font(.system(size: 16)).foregroundStyle(Theme.txt)
                                Text("\(season.episodeCount) eps").font(.system(size: 13)).foregroundStyle(Theme.mut)
                            }
                            Spacer(minLength: 0)
                        } else {
                            Text(label).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Theme.txt)
                            Spacer(minLength: 0)
                            Text("\(season.episodeCount) eps").font(.system(size: 11)).foregroundStyle(Theme.dim)
                        }
                        Image(systemName: "chevron.right").font(.system(size: v2 ? 13 : 11, weight: .bold)).foregroundStyle(Theme.mut)
                            .rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .padding(.trailing, v2 ? 16 : 13)
                    .frame(minHeight: v2 ? 56 : 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(open ? "Collapse" : "Expand") \(label)")
            }
            if open {
                VStack(spacing: 0) {
                    ForEach(1...max(1, season.episodeCount), id: \.self) { e in
                        let selected = full || selEpisodes.contains(EpisodeRef(season: n, episode: e))
                        Button { toggleEpisode(season, e) } label: {
                            HStack(spacing: 10) {
                                if v2 {
                                    RequestCheckCircle(checked: selected, size: 20)
                                } else {
                                    WebCheckSquare(checked: selected, size: 18)
                                }
                                Text(EpisodeCode.episode(season: n, episode: e)).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.mut)
                                    .frame(minWidth: 56, alignment: .leading)
                                Text(episodeTitles[n]?[e] ?? "Episode \(e)")
                                    .font(.system(size: 12.5)).foregroundStyle(selected ? Theme.txt : Theme.mut)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, v2 ? 56 : 38).padding(.trailing, 13).padding(.vertical, v2 ? 10 : 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(v2 ? Theme.txt.opacity(0.03) : Theme.panel2)
                .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
                .transition(.opacity)
                .task {
                    guard episodeTitles[n] == nil, let client = model.client else { return }
                    let eps = (try? await client.previewSeason(kind: pick.previewKind, tmdbId: pick.tmdbId, season: n)) ?? []
                    var map: [Int: String] = [:]
                    for ep in eps { if let t = ep.title { map[ep.episodeNumber] = t } }
                    episodeTitles[n] = map
                }
            }
        }
        .modifier(RequestSeasonSurface(full: full, v2: v2))
    }

    private func toggleSeason(_ season: PreviewSeason) {
        let n = season.seasonNumber
        if selSeasons.contains(n) {
            selSeasons.remove(n)
        } else {
            selSeasons.insert(n)
            selEpisodes = selEpisodes.filter { $0.season != n }
        }
    }

    private func toggleEpisode(_ season: PreviewSeason, _ e: Int) {
        let n = season.seasonNumber
        let ref = EpisodeRef(season: n, episode: e)
        if selSeasons.contains(n) {
            selSeasons.remove(n)
            for other in 1...max(1, season.episodeCount) where other != e {
                selEpisodes.insert(EpisodeRef(season: n, episode: other))
            }
        } else if selEpisodes.contains(ref) {
            selEpisodes.remove(ref)
        } else {
            selEpisodes.insert(ref)
            let all = (1...max(1, season.episodeCount)).allSatisfy { selEpisodes.contains(EpisodeRef(season: n, episode: $0)) }
            if all {
                selSeasons.insert(n)
                selEpisodes = selEpisodes.filter { $0.season != n }
            }
        }
    }
}

/// A season row's surface: v1's own bordered card (accent edge when the
/// whole season is ticked); v2's row inside the shared grouped card.
private struct RequestSeasonSurface: ViewModifier {
    let full: Bool
    let v2: Bool

    func body(content: Content) -> some View {
        if v2 {
            content
        } else {
            content
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(full ? Theme.indigo.opacity(0.4) : Theme.line))
        }
    }
}
