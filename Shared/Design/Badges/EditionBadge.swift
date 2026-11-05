import SwiftUI
import FusionhaKit

/// One version's v2 badge (A1 monochrome): an 18pt piece (23 with "!"),
/// then the ring while it downloads or the quiet "n/m" while it is partly
/// on disk. For a title with both versions use `EditionTicketPair`.
struct EditionBadge: View {
    let tier: QualityTier
    let state: EditionBadgeState
    /// Partly owned versions show "n/m" beside the badge.
    var showsCount = true
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .page
        HStack(spacing: 0) {
            TicketPieceView(side: nil, letters: tier.badgeLetters, state: state,
                            width: TicketMetrics.width(held: state.isHeld), scale: scale, ink: ink)
            BadgeAccessory(state: state, showsCount: showsCount, scale: scale, ink: ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.badgeLetters) \(state.spoken)")
    }
}

/// What sits beside a piece: the download ring (2pt in, the mock's -1 margin
/// on a 3pt gap) or the "n/m" count (4pt in). Nothing for the other states.
struct BadgeAccessory: View {
    let state: EditionBadgeState
    var showsCount = true
    let scale: CGFloat
    let ink: BadgeInk

    var body: some View {
        if case let .downloading(progress) = state {
            DownloadRing(progress: progress, scale: scale)
                .badgeInk(ink)
                .padding(.leading, (TicketMetrics.itemGap - 1) * scale)
        } else if showsCount, let count = state.count {
            Text(verbatim: count)
                .font(.system(size: 10 * scale, weight: .semibold))
                .tracking(-0.2 * scale)
                .monospacedDigit()
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, (TicketMetrics.itemGap + 1) * scale)
        }
    }

    /// Whether anything is drawn (the pair's spacing depends on it).
    static func isEmpty(_ state: EditionBadgeState, showsCount: Bool) -> Bool {
        !state.showsRing && !(showsCount && state.count != nil)
    }
}
