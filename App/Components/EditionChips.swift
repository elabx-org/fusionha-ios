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
            .fill(LinearGradient(colors: [color.opacity(0.24), color.opacity(0.12)], startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(color.opacity(0.34), lineWidth: 1))
            .overlay(alignment: .top) {
                shape.strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.25)))
            }
    }
}

/// `HD` / `4K` as a lit edition chip (CoverageRail `.tier`).
struct TierPill: View {
    let tier: QualityTier
    var large = false

    var body: some View {
        Text(large ? tier.chipLabel : tier.pill)
            .font(.system(size: large ? 13 : 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(tier.color)
            .padding(.horizontal, large ? 9 : 4)
            .padding(.vertical, large ? 5 : 3)
            .frame(minWidth: 27)
            .background(EditionChipBackground(color: tier.color))
    }
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
