import SwiftUI
import FusionhaKit

/// A season page's rail (mock rails.js B2): one 6pt tick per episode, up to
/// `OneInkRail.maxTicks`; longer seasons, and rows too narrow for a tick at
/// least as wide as it is tall (large Dynamic Type), fall back to the capsule.
/// Same one ink as `RailBarV2`.
struct EpisodeTicks: View {
    let have: Int
    let aired: Int
    let total: Int
    var rest: OneInkRail.Piece = .missing
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 6
    @ScaledMetric(relativeTo: .caption2) private var gap: CGFloat = 3
    @Environment(\.badgeInk) private var inkOverride
    /// The width on offer (0 until measured: assume the ticks fit).
    @State private var width: CGFloat = 0

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    @ViewBuilder
    private var content: some View {
        if let ticks = OneInkRail.ticks(have: have, aired: aired, total: total, rest: rest), fits(ticks.count) {
            let ink = inkOverride ?? .page
            HStack(spacing: gap) {
                ForEach(ticks.indices, id: \.self) { i in
                    tick(ticks[i], ink: ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                }
            }
            .accessibilityHidden(true)
        } else {
            RailBarV2(have: have, aired: aired, total: total, rest: rest)
        }
    }

    private func fits(_ count: Int) -> Bool {
        guard width > 0, count > 0 else { return true }
        let n = CGFloat(count)
        return (width - gap * (n - 1)) / n >= height
    }

    @ViewBuilder
    private func tick(_ piece: OneInkRail.Piece, ink: BadgeInk) -> some View {
        let shape = RoundedRectangle(cornerRadius: height / 2, style: .circular)
        switch piece {
        case .onDisk: shape.fill(ink.fill)
        case .missing: shape.fill(ink.track)
        case .downloading where ink.patterned:
            shape.fill(ink.track)
                .overlay { RailHatch().stroke(ink.accent, lineWidth: 1).clipShape(shape) }
        case .downloading: shape.fill(ink.accent)
        case .held where ink.patterned: shape.fill(ink.track).overlay { shape.strokeBorder(ink.held, lineWidth: 1) }
        case .held: shape.fill(ink.held)
        case .unaired: shape.strokeBorder(ink.secondary, lineWidth: 1)
        }
    }
}
