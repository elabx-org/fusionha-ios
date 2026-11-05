import SwiftUI
import FusionhaKit

/// A title's HD and 4K badges as the two halves of one T5 ticket (owner
/// 2026-11-04). When both halves draw the same and carry nothing beside
/// them (both filled, or both outlined, with no ring, count or "!") they plug together with a
/// 1.3pt gap; otherwise they sit apart, each with its ring or count, so the
/// shape itself says "these differ". The change animates (`.snappy`)
/// unless Reduce Motion is on. A title with one version shows one badge.
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
        // Joined when both halves draw alike with nothing beside them (the
        // mock's rule): with counts hidden, partial and on disk look the same.
        let joined = !a.isHeld && !b.isHeld && a.isFilled == b.isFilled
            && BadgeAccessory.isEmpty(a, showsCount: showsCount)
            && BadgeAccessory.isEmpty(b, showsCount: showsCount)
        let m = TicketMetrics.self
        // Joined: body, 1.3 gap, body. Apart: the left half keeps room for
        // its scallops, then the row gap, 2pt more, and the right half's own
        // offset (seam to seam 1.8 + 3 + 2 + 1.1 with nothing between).
        let afterLeft = joined ? m.joinedGap : m.leftOverhang
        let beforeRight = joined ? 0 : m.itemGap + m.apartExtra + m.rightOverhang
        return HStack(spacing: 0) {
            TicketPieceView(side: .left, letters: QualityTier.hd.badgeLetters, state: a,
                            width: m.width(held: a.isHeld) + m.leftExtra, scale: scale, ink: ink)
            Color.clear.frame(width: snap(afterLeft))
            if !joined {
                BadgeAccessory(state: a, showsCount: showsCount, scale: scale, ink: ink)
                    .transition(.opacity)
            }
            Color.clear.frame(width: snap(beforeRight))
            TicketPieceView(side: .right, letters: QualityTier.uhd.badgeLetters, state: b,
                            width: m.width(held: b.isHeld) + m.rightExtra, scale: scale, ink: ink)
            if !joined {
                BadgeAccessory(state: b, showsCount: showsCount, scale: scale, ink: ink)
                    .transition(.opacity)
            }
        }
        .frame(height: m.height * scale)
        .animation(reduceMotion ? nil : .snappy, value: joined)
        .animation(reduceMotion ? nil : .snappy, value: a)
        .animation(reduceMotion ? nil : .snappy, value: b)
    }

    private func snap(_ points: CGFloat) -> CGFloat {
        TicketMetrics.snap(points * scale, displayScale)
    }
}
