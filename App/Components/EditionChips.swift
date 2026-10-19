import SwiftUI
import FusionhaKit

// MARK: Edition chips (redesign `.ed`)

/// A small lit chip in its colour: a top-to-bottom wash of the colour, an
/// inner hairline and a highlight on the top edge. HD is purple, 4K cyan
/// (`QualityTier.color`); status chips pass a status colour.
struct EditionChipBackground: View {
    let color: Color
    var radius: CGFloat = 6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(color.opacity(0.18))
            .overlay(shape.strokeBorder(color.opacity(0.34), lineWidth: 1))
    }
}

/// `HD` / `4K` as a lit edition chip (CoverageRail `.tier`).
struct TierPill: View {
    let tier: QualityTier
    var large = false

    var body: some View {
        let mono = Theme.isMono
        Text(large ? tier.chipLabel : tier.pill)
            .font(.system(size: large ? 13 : 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(mono ? tier.monoText : tier.color)
            .padding(.horizontal, large ? 9 : 4)
            .padding(.vertical, large ? 5 : 3)
            .frame(minWidth: 27)
            .background {
                if mono { MonoTierBackground(tier: tier, radius: 6) } else { EditionChipBackground(color: tier.color) }
            }
    }
}

/// Monochrome's tier chips: HD outlined, 4K solid, so the two tiers stay
/// distinct without purple and cyan.
struct MonoTierBackground: View {
    let tier: QualityTier
    var radius: CGFloat = 6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if tier == .uhd {
            shape.fill(Theme.txt)
        } else {
            shape.strokeBorder(Theme.txt.opacity(0.9), lineWidth: 1)
        }
    }
}

extension QualityTier {
    /// The chip's text in Monochrome: light on the outlined HD chip, dark on the solid 4K one.
    var monoText: Color { self == .uhd ? Theme.bg : Theme.txt }
}

/// The two-tier "HD·4K" chip of a consolidated rail.
struct TierComboPill: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("HD").foregroundStyle(Theme.edition)
            Text("·").foregroundStyle(Theme.mut.opacity(0.7))
            Text("4K").foregroundStyle(Theme.grab)
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .frame(minWidth: 27)
        .background(EditionChipBackground(color: Theme.txt))
    }
}
