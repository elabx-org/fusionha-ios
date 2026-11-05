import SwiftUI
import FusionhaKit

/// Everything under a v2 Library poster (mock browse-lib.js `lpost`), so the
/// art itself stays clean: the title, a meta line (year, the kind glyph, the
/// Anime tag, an attention glyph, the monitor bookmark), then the title's
/// HD and 4K as one T5 ticket (`EditionTicketPair`).
struct V2PosterCaption: View {
    let item: MediaItem
    /// The shelf's smaller cards drop the meta line.
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
        VStack(alignment: .leading, spacing: 1) {
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(monitored ? ink : muted)
                .lineLimit(1)
            if showsMeta { meta }
            EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
                .padding(.top, 5)
        }
    }

    private var meta: some View {
        HStack(spacing: 4) {
            if let year = item.year {
                Text(verbatim: String(year)).monospacedDigit()
                Text(verbatim: "·").accessibilityHidden(true)
            }
            Image(systemName: V2EditionBadges.kindSymbol(item)).accessibilityHidden(true)
            if item.isAnime == true {
                Text("Anime")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.anime)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Theme.anime.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            if item.hasAttention == true {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Theme.stuck)
                    .accessibilityLabel("Needs attention")
            }
            Spacer(minLength: 2)
            Image(systemName: monitored ? "bookmark.fill" : "bookmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(monitored ? ink : muted.opacity(0.7))
                .accessibilityLabel(monitored ? "Monitored" : "Not monitored")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(muted)
        .lineLimit(1)
        .padding(.top, 1)
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

    /// Movie, series or anime, as a glyph.
    static func kindSymbol(_ item: MediaItem) -> String {
        if item.isAnime == true { return "sparkles" }
        return item.kind == .movie ? "film" : "tv"
    }
}
