import SwiftUI
import FusionhaKit

/// One episode on the season page (mock kit `erow`): a still (the series
/// art until the server sends episode stills), the title, "E4 · 48m ·
/// Oct 20", two lines of overview, one T5 badge per version and the status
/// circle. Episodes not out yet dim their art. Content, not glass.
struct V2EpisodeRow: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let state: V2EpisodeState
    var monitored = true
    var stillWidth: CGFloat = 120
    /// Shorter rows (the open Duo's list beside an episode): no overview.
    var showsOverview = true

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var upcoming: Bool { state.circle == .upcoming }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(url: TMDBImage.resized(detail.backdropUrl ?? detail.posterUrl, to: "w300"))
                .frame(width: stillWidth, height: (stillWidth * 9 / 16).rounded())
                .saturation(upcoming ? 0.5 : 1)
                .brightness(upcoming ? -0.1 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(episode.title ?? "Episode \(episode.episodeNumber)")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(V2EpisodeText.meta(episode, anime: detail.isAnime == true))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(muted)
                    .padding(.top, 1)
                if showsOverview { overview }
                HStack(spacing: 5) {
                    ForEach(state.badges.indices, id: \.self) { i in
                        EditionBadge(tier: state.badges[i].tier, state: state.badges[i].state)
                    }
                    if !monitored {
                        Image(systemName: "bookmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(muted)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            V2EpisodeStatusCircle(circle: state.circle)
                .opacity(monitored ? 1 : 0.5)
                // Centred on the still (kit `.st` margin-top 20 beside a 120pt still).
                .padding(.top, max(2, ((stillWidth * 9 / 16).rounded() - 28) / 2))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    @ViewBuilder
    private var overview: some View {
        if let text = episode.overview, !text.isEmpty {
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(muted)
                .lineSpacing(1.5)
                .lineLimit(2)
                .padding(.top, 4)
        } else {
            Label(V2EpisodeText.noSynopsis(episode), systemImage: "clock")
                .font(.system(size: 12).italic())
                .foregroundStyle(muted.opacity(0.8))
                .lineLimit(1)
                .padding(.top, 4)
        }
    }

    private var spokenLabel: String {
        let title = episode.title ?? "Episode \(episode.episodeNumber)"
        let badges = state.badges.map { "\($0.tier.badgeLetters) \($0.state.spoken)" }.joined(separator: ", ")
        return "\(V2EpisodeText.meta(episode, anime: detail.isAnime == true)), \(title). \(state.spoken). \(badges)"
            + (monitored ? "" : ". Not monitored")
    }
}
