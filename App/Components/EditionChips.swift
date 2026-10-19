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
        Text(large ? tier.chipLabel : tier.pill)
            .font(.system(size: large ? 13 : 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(tier.chipText)
            .padding(.horizontal, large ? 9 : 4)
            .padding(.vertical, large ? 5 : 3)
            .frame(minWidth: 27)
            .background(TierChipBackground(tier: tier))
    }
}

/// A tier chip's background: the lit chip in the tier colour, or under
/// Monochrome `MonoTierBackground`.
struct TierChipBackground: View {
    let tier: QualityTier
    var radius: CGFloat = 6

    var body: some View {
        if Theme.isMono {
            MonoTierBackground(tier: tier, radius: radius)
        } else {
            EditionChipBackground(color: tier.color, radius: radius)
        }
    }
}

/// Monochrome's tier chips (`--tier-chip-*`): HD outlined in the light grey,
/// 4K solid in the mid grey, so the two tiers differ by shade and by shape
/// without purple and cyan.
struct MonoTierBackground: View {
    let tier: QualityTier
    var radius: CGFloat = 6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if tier == .uhd {
            shape.fill(Theme.tierFill(.uhd))
        } else {
            shape.strokeBorder(Theme.tierFill(.hd), lineWidth: 1)
        }
    }
}

extension QualityTier {
    /// The chip's text in Monochrome: the HD grey on the outlined HD chip, dark on the solid 4K one.
    var monoText: Color { self == .uhd ? Theme.bg : Theme.tierFill(.hd) }
    /// A tier chip's text on any palette.
    var chipText: Color { Theme.isMono ? monoText : color }
}

/// The two-tier "HD·4K" chip of a consolidated rail. Under Monochrome each
/// half wears its own tier chip's shade and shape.
struct TierComboPill: View {
    var body: some View {
        if Theme.isMono {
            HStack(spacing: 2) {
                half(.hd)
                half(.uhd)
            }
        } else {
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

    private func half(_ tier: QualityTier) -> some View {
        Text(tier.pill)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(tier.monoText)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(MonoTierBackground(tier: tier, radius: 5))
    }
}
