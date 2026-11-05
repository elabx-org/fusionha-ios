import SwiftUI
import FusionhaKit

/// One season on the title's Seasons tab (mock kit `scard`, one card per
/// season): the series poster until season posters arrive, "Season 1",
/// its episode count and air span, one lane per version (T5 badge, one-ink
/// rail, n/m), what is still moving, and a chevron. Tapping it pushes the
/// season page.
struct V2SeasonCard: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let season: Season
    let facts: V2SeasonFacts
    /// The open Duo's narrow column: a smaller poster.
    var compact = false
    /// The season open beside this list (the wide child's left column).
    var selected = false

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var posterWidth: CGFloat { compact ? 60 : 74 }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PosterImage(url: TMDBImage.resized(detail.posterUrl, to: "w185"))
                .frame(width: posterWidth, height: posterWidth * 1.5)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(season.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ink)
                Text(facts.spanLine)
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
                    .padding(.top, 2)
                VStack(spacing: 8) {
                    ForEach(facts.lanes) { lane in
                        V2SeasonLaneRow(lane: lane, ticks: false)
                    }
                }
                .padding(.top, 8)
                // Muted even when held: the badge carries the orange (kit `.scard .tx .m`).
                Text(facts.stateLine)
                    .font(.system(size: 12.5))
                    .foregroundStyle(muted)
                    .padding(.top, 7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 16))
                .foregroundStyle(muted)
                .accessibilityHidden(true)
        }
        .padding(12)
        .background { ModuleSurface(radius: 20, selected: selected) }
        .opacity(season.monitored == false ? 0.6 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint("Opens the season")
    }

    private var spokenLabel: String {
        let lanes = facts.lanes.map { "\($0.edition.tier.badgeLetters) \($0.state.spoken)" }.joined(separator: ", ")
        let off = season.monitored == false ? ", not monitored" : ""
        return "\(season.title)\(off). \(facts.spanLine). \(lanes). \(facts.stateLine)"
    }
}

/// A version's lane: its T5 badge, the one-ink rail (ticks on the season
/// page, the capsule on the card) and "n/m".
struct V2SeasonLaneRow: View {
    @Environment(\.pagePalette) private var page
    let lane: V2SeasonLane
    var ticks = true
    var showsCount = true

    var body: some View {
        HStack(spacing: 8) {
            EditionBadge(tier: lane.edition.tier, state: lane.state, showsCount: false)
            Group {
                if ticks {
                    EpisodeTicks(have: lane.have, aired: lane.aired, total: lane.total, rest: lane.rest)
                } else {
                    RailBarV2(have: lane.have, aired: lane.aired, total: lane.total, rest: lane.rest)
                }
            }
            .frame(maxWidth: .infinity)
            if showsCount, let count = lane.count {
                Text(verbatim: count)
                    .font(.system(size: ticks ? 12.5 : 11.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .frame(minWidth: ticks ? nil : 30, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(lane.edition.label), \(lane.state.spoken)\(lane.count.map { ", \($0)" } ?? "")")
    }
}
