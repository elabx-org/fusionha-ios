import SwiftUI
import FusionhaKit

/// The episode's header beside its season's list on the flat open Duo (mock
/// browse.js episode on the inner display): the band above carries the
/// series art, so the page opens on "Season 1 · Episode 4", a small still
/// (the episode's own, else the series art), the title and
/// "S1 · E4 · Oct 20 '26 · 48m". Content, not glass.
struct V2EpisodeWideHeader: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Season \(seasonNumber) · Episode \(episode.episodeNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(muted)
            HStack(spacing: 12) {
                PosterImage(url: V2EpisodeRow.still(episode, in: detail))
                    .frame(width: 96, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title ?? "Episode \(episode.episodeNumber)")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                    Text(V2EpisodeText.pageMeta(episode, season: seasonNumber))
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
