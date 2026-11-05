import SwiftUI

/// One row's slice of a W1 card that runs through a `List` (the season's
/// episodes): the same frosted material and wash as `ModuleSurface`, with
/// the corners rounded only where the card starts and ends, so the rows
/// read as one card while keeping the system's swipe actions and menus.
/// Rows below the first draw the hairline above themselves, inset like
/// the card's other rows. Use as the row's `listRowBackground`.
struct ModuleListSegment: View {
    enum Position {
        case only, first, middle, last

        init(index: Int, count: Int) {
            switch (index, count) {
            case (_, 1): self = .only
            case (0, _): self = .first
            case (count - 1, _): self = .last
            default: self = .middle
            }
        }

        var roundsTop: Bool { self == .only || self == .first }
        var roundsBottom: Bool { self == .only || self == .last }
    }

    let position: Position
    /// The page gutter the card sits inside (the row background spans the
    /// whole row, so the card pulls itself in by this much).
    var gutter: CGFloat = 16
    /// Where the hairline starts, from the card's leading edge.
    var hairlineLeading: CGFloat = ModuleMetrics.inset
    var radius: CGFloat = ModuleMetrics.radius
    @Environment(\.pagePalette) private var page
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let light = page?.isLight ?? Theme.isLight
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: position.roundsTop ? radius : 0,
            bottomLeadingRadius: position.roundsBottom ? radius : 0,
            bottomTrailingRadius: position.roundsBottom ? radius : 0,
            topTrailingRadius: position.roundsTop ? radius : 0,
            style: .continuous)
        shape
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, light ? .light : .dark)
            .overlay(shape.fill(ModuleMetrics.wash(light: light)))
            .overlay {
                if position.roundsTop {
                    shape.strokeBorder(
                        LinearGradient(colors: [ModuleMetrics.edge(light: light), .clear], startPoint: .top,
                                       endPoint: .init(x: 0.5, y: 0.2)),
                        lineWidth: EditionChip.hairline(displayScale))
                }
            }
            .overlay(alignment: .top) {
                if !position.roundsTop {
                    Rectangle()
                        .fill(ModuleMetrics.hairline(light: light))
                        .frame(height: EditionChip.hairline(displayScale))
                        .padding(.leading, hairlineLeading)
                        .padding(.trailing, ModuleMetrics.inset)
                }
            }
            .padding(.horizontal, gutter)
            .accessibilityHidden(true)
    }
}
