import SwiftUI
import FusionhaKit

/// One version's v2 media badge (option A, owner 2026-11-06): a 25pt
/// rounded rectangle (30 when held), then the quiet "n/m" while it is partly
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
            MediaBadgeView(letters: tier.badgeLetters, state: state, scale: scale, ink: ink)
            BadgeAccessory(state: state, showsCount: showsCount, scale: scale, ink: ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tier.badgeLetters) \(state.spoken)")
    }
}

/// What sits beside a badge: the "n/m" count of a partly owned version.
/// Downloading shows its progress inside the badge, so nothing else does.
struct BadgeAccessory: View {
    let state: EditionBadgeState
    var showsCount = true
    let scale: CGFloat
    let ink: BadgeInk

    var body: some View {
        if showsCount, let count = state.count {
            Text(verbatim: count)
                .font(.system(size: 10 * scale, weight: .semibold))
                .tracking(-0.2 * scale)
                .monospacedDigit()
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, MediaBadgeMetrics.itemGap * scale)
        }
    }

    /// Whether anything is drawn (the pair's spacing depends on it).
    static func isEmpty(_ state: EditionBadgeState, showsCount: Bool) -> Bool {
        !(showsCount && state.count != nil)
    }
}
