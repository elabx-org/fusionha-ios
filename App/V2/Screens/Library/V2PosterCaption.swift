import SwiftUI
import FusionhaKit

/// Everything under a v2 Library poster (mock browse-lib.js `lpost`, the
/// owner's monitor mark M1), so the art itself stays clean: the title, then
/// one row with the title's HD and 4K as one T5 ticket (`EditionTicketPair`,
/// any n/m count included) and, after it, only what is out of the ordinary:
/// the Anime tag, the attention glyph, and a slashed bookmark with "Off"
/// when the title is not monitored. Monitored is the norm and shows nothing.
struct V2PosterCaption: View {
    let item: MediaItem
    /// The shelf's smaller cards drop the Anime tag.
    var showsMeta = true
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var monitored: Bool { item.monitored ?? true }
    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        // Only this title's versions: a poll that moves another download
        // leaves this caption alone (`QueueSlots`).
        let slots = model.queueSlots
        let badges = V2EditionBadges(item) { slots.slot(for: $0.id).progress }
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(monitored ? ink : muted)
                .lineLimit(1)
            // A narrow card with counts on both tickets keeps the slashed
            // bookmark and drops the word.
            ViewThatFits(in: .horizontal) {
                row(badges, compact: false)
                row(badges, compact: true)
            }
            .padding(.top, 5)
        }
    }

    private func row(_ badges: V2EditionBadges, compact: Bool) -> some View {
        HStack(spacing: 6) {
            EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
            marks(compact: compact)
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func marks(compact: Bool) -> some View {
        if showsMeta && item.isAnime == true {
            Text("Anime")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.anime)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Theme.anime.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        if item.hasAttention == true {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.stuck)
                .accessibilityLabel("Needs attention")
        }
        if !monitored {
            V2MonitorOffMark(color: muted, showsWord: !compact)
        }
    }
}

/// M1's "not monitored" mark: a slashed bookmark and "Off" in the muted ink.
struct V2MonitorOffMark: View {
    var color: Color
    var showsWord = true

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bookmark.slash")
            if showsWord { Text("Off") }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Not monitored")
    }
}

/// A title's HD and 4K badge states (the first version of each tier), from
/// the same rails the v1 cards read plus each version's live download.
struct V2EditionBadges: Equatable {
    var hd: EditionBadgeState?
    var uhd: EditionBadgeState?

    init(_ item: MediaItem, progress: (Edition) -> QueueProgress?) {
        for (edition, rail) in zip(item.editions, item.rails) {
            let state = EditionBadgeState(rail: rail, queue: progress(edition))
            switch edition.tier {
            case .hd: if hd == nil { hd = state }
            case .uhd: if uhd == nil { uhd = state }
            }
        }
    }
}
