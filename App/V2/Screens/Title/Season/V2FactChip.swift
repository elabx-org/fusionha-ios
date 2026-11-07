import SwiftUI
import FusionhaKit

/// One file fact as a small outline chip (owner option B, 2026-11-06): the
/// ticket's height and corner, monochrome in the badge ink; a fact that
/// differs from the rest of the season is outlined in the held orange and
/// set a weight heavier (the cue that survives a hue-less palette).
struct V2FactChip: View {
    let chip: FileFactChip
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        let ink = inkOverride ?? .page
        let tone = chip.differs ? ink.held : ink.secondary
        Text(verbatim: chip.text)
            .font(.system(size: 9.5 * scale, weight: chip.differs ? .semibold : .medium))
            .monospacedDigit()
            .foregroundStyle(chip.differs ? ink.held : ink.label.opacity(0.8))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4.5 * scale)
            .frame(height: MediaBadgeMetrics.height * scale)
            .overlay {
                RoundedRectangle(cornerRadius: MediaBadgeMetrics.radius * scale, style: .continuous)
                    .strokeBorder(tone, lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(FileFactsSpeech.line([chip], size: nil))
    }
}

/// The tier a group of chips belongs to, when a title has more than one
/// version ("4K" before that version's chips).
struct V2FactTierLabel: View {
    let tier: QualityTier
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        Text(verbatim: tier.badgeLetters)
            .font(.system(size: 9.5 * scale, weight: .bold))
            .foregroundStyle((inkOverride ?? .page).secondary)
            .fixedSize()
            .frame(height: MediaBadgeMetrics.height * scale)
            .accessibilityHidden(true)
    }
}
