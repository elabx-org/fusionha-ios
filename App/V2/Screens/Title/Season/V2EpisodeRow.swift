import SwiftUI
import FusionhaKit

/// One episode on the season page (mock kit `erow`), a row of the season's
/// episode card: a leading 112pt 16:9 still (the episode's own, else the
/// series art; the number block when there is no art),
/// the title, "E4 · 48m · Oct 20", two lines
/// of overview, one T5 badge per version and the status circle on the title
/// line. Episodes not out yet dim their lead. Content, not glass. The
/// badge line carries the file's fact chips and size (`V2EpisodeFactsLine`).
struct V2EpisodeRow: View {
    @Environment(\.pagePalette) private var page
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    let episode: Episode
    let state: V2EpisodeState
    var monitored = true
    /// The row's still. nil (no art at all): the number block.
    var stillURL: URL?
    /// Shorter rows (the open Duo's list beside an episode): no overview.
    var showsOverview = true
    /// The season's file facts per version (`SeasonFileFacts.perVersion`).
    var fileFacts: [SeasonVersionFileFacts] = []
    /// Set: the chips open Release groups / the file's sheet in this season.
    var factsSeason: Int?

    static let stillWidth: CGFloat = 112

    /// The episode's own still (absolute, 0.4.238), else the series art.
    static func still(_ episode: Episode, series: URL?) -> URL? {
        episode.stillUrl.flatMap(URL.init(string:)) ?? series
    }
    static let numberSide: CGFloat = 44
    static let leadSpacing: CGFloat = 12
    /// Where the text column starts inside the row, for the card's hairline.
    static func textLeading(hasStill: Bool) -> CGFloat {
        (hasStill ? stillWidth : numberSide) + leadSpacing
    }

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var upcoming: Bool { state.circle == .upcoming }
    /// A search for this episode started from its swipe, menu or page.
    private var search: SearchActivity? { store.searchActivity.activity(episode: episode.id) }

    var body: some View {
        HStack(alignment: .top, spacing: Self.leadSpacing) {
            lead
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
                V2EpisodeFactsLine(parts: facts, labelsTiers: fileFacts.count > 1,
                                   onGroup: factsSeason != nil && model.mayBlockGroups ? openGroups : nil,
                                   onFile: factsSeason != nil ? openFile : nil) {
                    ForEach(state.badges.indices, id: \.self) { i in
                        EditionBadge(tier: state.badges[i].tier, state: state.badges[i].state)
                    }
                    if !monitored {
                        Image(systemName: "bookmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(muted)
                            .accessibilityHidden(true)
                    }
                    if let search { V2SearchStatusLine(activity: search).padding(.leading, 4) }
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            V2EpisodeStatusCircle(circle: state.circle)
                .opacity(monitored ? 1 : 0.5)
                // On the title line: the circle's centre on the title's
                // (15.5pt bold, ~10pt to its middle).
                .alignmentGuide(.top) { $0[VerticalAlignment.center] - 10 }
        }
        .padding(.vertical, ModuleMetrics.rowPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityActions { factsActions }
        .v2SearchHaptics(search)
    }

    private var facts: [V2EpisodeFactsPart] { V2EpisodeFactsPart.parts(episode, versions: fileFacts) }

    private func openFile(_ part: V2EpisodeFactsPart) {
        guard let factsSeason else { return }
        store.fileSheet = EpisodeFileTarget(fileId: part.fileId, editionId: part.editionId, seasonNumber: factsSeason)
    }

    private func openGroups() { store.showingReleaseGroups = true }

    @ViewBuilder
    private var factsActions: some View {
        if factsSeason != nil, let part = facts.first {
            Button("Show file") { openFile(part) }
            if model.mayBlockGroups, facts.contains(where: { $0.line.chips.contains { $0.kind == .group } }) {
                Button("Release groups") { openGroups() }
            }
        }
    }

    @ViewBuilder
    private var lead: some View {
        if let stillURL {
            PosterImage(url: stillURL)
                .frame(width: Self.stillWidth, height: (Self.stillWidth * 9 / 16).rounded())
                .saturation(upcoming ? 0.5 : 1)
                .brightness(upcoming ? -0.1 : 0)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
        } else {
            Text(verbatim: "E\(episode.episodeNumber)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .foregroundStyle(upcoming ? muted : ink)
                .frame(width: Self.numberSide, height: Self.numberSide)
                .background(ink.opacity(upcoming ? 0.06 : 0.1),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
        }
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
            + (monitored ? "" : ". Not monitored") + (search.map { ". \($0.label)" } ?? "")
            + factsSpoken
    }

    private var factsSpoken: String {
        let line = V2EpisodeFactsPart.spoken(facts, labelsTiers: fileFacts.count > 1)
        return line.isEmpty ? "" : ". \(line)"
    }
}
