import SwiftUI
import FusionhaKit

/// The wide episode child's left column (mock browse.js episode on the
/// inner display): the season's name and count over its tick lanes, then
/// its episodes as short rows (no overview), the open one ringed. A tap
/// swaps the episode beside it; the list follows the season page's sort.
struct V2WideEpisodeList: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    let season: Season
    @Binding var selected: Int?

    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let editions = detail.orderedEditions
        let facts = V2SeasonFacts(season: season, editions: editions)
        let oldest = store.oldestFirst.contains(season.seasonNumber)
        let episodes = season.episodes.sorted {
            oldest ? $0.episodeNumber < $1.episodeNumber : $0.episodeNumber > $1.episodeNumber
        }
        let still = TMDBImage.resized(detail.backdropUrl ?? detail.posterUrl, to: "w300")
        let fileFacts = SeasonFileFacts.perVersion(season, editions: editions)
        ScrollViewReader { reader in
            ScrollView {
                // Not lazy: a season is a few dozen rows at most, and `scrollTo`
                // only reaches rows that exist, so the open episode far down a
                // long season is centred on the first open.
                VStack(alignment: .leading, spacing: 4) {
                    header(facts, fileFacts: fileFacts)
                        .padding(.bottom, 10)
                    ForEach(episodes, id: \.id) { episode in
                        row(episode, state: V2EpisodeState(episode: episode, editions: editions),
                            still: V2EpisodeRow.still(episode, series: still), fileFacts: fileFacts)
                            .id(episode.id)
                    }
                }
                .padding(.leading, V2TitleWide.gutter - 10)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .onAppear { if let selected { reader.scrollTo(selected, anchor: .center) } }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func header(_ facts: V2SeasonFacts, fileFacts: [SeasonVersionFileFacts]) -> some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(season.title).font(.system(size: 17, weight: .bold))
                Text(facts.countLine)
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if !fileFacts.isEmpty { V2SeasonFileFactsHeader(versions: fileFacts) }
            VStack(spacing: 6) {
                ForEach(facts.lanes) { V2SeasonLaneRow(lane: $0, showsCount: false) }
            }
            if let activity = store.seasonActivity(season.seasonNumber) {
                V2SearchStatusLine(activity: activity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    /// The facts are plain content here: a tap opens the episode beside the list.
    private func row(_ episode: Episode, state: V2EpisodeState, still: URL?,
                     fileFacts: [SeasonVersionFileFacts]) -> some View {
        let isOpen = episode.id == selected
        return Button {
            withAnimation(reduce ? nil : .easeInOut(duration: 0.2)) { selected = episode.id }
        } label: {
            V2EpisodeRow(detail: detail, episode: episode, state: state,
                         monitored: store.episodeMonitored(episode), stillURL: still, showsOverview: false,
                         fileFacts: fileFacts)
                .padding(.horizontal, 10)
                .background {
                    if isOpen { ModuleSurface(radius: 16, selected: true) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityHint(isOpen ? "" : "Opens the episode beside the list")
    }
}
