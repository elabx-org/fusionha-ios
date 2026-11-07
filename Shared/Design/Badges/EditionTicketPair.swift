import SwiftUI
import FusionhaKit

/// A title's HD and 4K media badges side by side (owner 2026-11-06). When
/// both say the same thing with nothing beside them (both on disk, both
/// missing, both downloading or both held) they sit 1pt apart and read as
/// one mark; otherwise 4pt apart, each with its count, so the gap itself
/// says "these differ". Changes animate (`.smooth`) unless Reduce Motion is
/// on. A title with one version shows one badge.
struct EditionTicketPair: View {
    var hd: EditionBadgeState?
    var uhd: EditionBadgeState?
    var showsCount = true
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(EditionBadgeSpeech.label(hd: hd, uhd: uhd))
    }

    @ViewBuilder
    private var content: some View {
        if let hd, let uhd {
            pair(hd, uhd)
        } else if let hd {
            EditionBadge(tier: .hd, state: hd, showsCount: showsCount)
        } else if let uhd {
            EditionBadge(tier: .uhd, state: uhd, showsCount: showsCount)
        }
    }

    private func pair(_ a: EditionBadgeState, _ b: EditionBadgeState) -> some View {
        let ink = inkOverride ?? .page
        let joined = Self.look(a) == Self.look(b)
            && BadgeAccessory.isEmpty(a, showsCount: showsCount)
            && BadgeAccessory.isEmpty(b, showsCount: showsCount)
        let gap = joined ? MediaBadgeMetrics.joinedGap : MediaBadgeMetrics.apartGap
        return HStack(spacing: 0) {
            MediaBadgeView(letters: QualityTier.hd.badgeLetters, state: a, scale: scale, ink: ink)
            BadgeAccessory(state: a, showsCount: showsCount, scale: scale, ink: ink)
            Color.clear.frame(width: MediaBadgeMetrics.snap(gap * scale, displayScale))
            MediaBadgeView(letters: QualityTier.uhd.badgeLetters, state: b, scale: scale, ink: ink)
            BadgeAccessory(state: b, showsCount: showsCount, scale: scale, ink: ink)
        }
        .animation(reduceMotion ? nil : .smooth, value: joined)
        .animation(reduceMotion ? nil : .smooth, value: a)
        .animation(reduceMotion ? nil : .smooth, value: b)
    }

    /// How a badge draws, ignoring progress and counts: solid, outline,
    /// filling or held.
    private static func look(_ s: EditionBadgeState) -> Int {
        switch s {
        case .onDisk, .partial: return 0
        case .missing: return 1
        case .downloading: return 2
        case .held: return 3
        }
    }
}
