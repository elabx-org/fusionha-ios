import SwiftUI
import FusionhaKit

/// The newest season on the poster-led page (mock round 2): today's season
/// card on top (it still opens the season), and inside the same card its
/// episodes, each with its version badges on one right edge. A long season
/// shows its first ten and a row to the whole season page.
struct V2SeasonEpisodesCard: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let season: Season
    let editions: [DetailEdition]
    var compact = false

    static let shown = 10
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let episodes = season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        VStack(spacing: 0) {
            NavigationLink(value: V2TitleRoute.season(season.seasonNumber)) {
                V2SeasonCard(detail: detail, season: season,
                             facts: V2SeasonFacts(season: season, editions: editions), compact: compact,
                             surface: false)
            }
            .buttonStyle(.plain)
            ForEach(Array(episodes.prefix(Self.shown)), id: \.id) { episode in
                hairline
                NavigationLink(value: V2TitleRoute.episode(season: season.seasonNumber, episodeId: episode.id)) {
                    V2SeasonEpisodeLine(detail: detail, episode: episode,
                                        state: V2EpisodeState(episode: episode, editions: editions))
                }
                .buttonStyle(.plain)
            }
            if episodes.count > Self.shown {
                hairline
                NavigationLink(value: V2TitleRoute.season(season.seasonNumber)) {
                    HStack {
                        Text("All \(episodes.count) episodes")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(muted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 4)
        .background { ModuleSurface(radius: 20) }
    }

    private var hairline: some View {
        Rectangle()
            .fill((page?.ink ?? Theme.txt).opacity(0.1))
            .frame(height: 0.5)
            .padding(.leading, 12 + V2EpisodeRow.numberSide + V2EpisodeRow.leadSpacing)
    }
}

/// One episode inside the season card: its number, title, air date, and
/// its version badges on the right.
struct V2SeasonEpisodeLine: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let state: V2EpisodeState

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        HStack(spacing: V2EpisodeRow.leadSpacing) {
            Text(verbatim: String(episode.episodeNumber))
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(muted)
                .frame(width: V2EpisodeRow.numberSide)
            VStack(alignment: .leading, spacing: 1) {
                Text(episode.title ?? "Episode \(episode.episodeNumber)")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(V2EpisodeText.meta(episode, anime: detail.isAnime == true))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                ForEach(state.badges.indices, id: \.self) { i in
                    EditionBadge(tier: state.badges[i].tier, state: state.badges[i].state, showsCount: false)
                }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the episode")
    }
}
