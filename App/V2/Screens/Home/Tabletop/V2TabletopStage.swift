import SwiftUI
import FusionhaKit

/// The tabletop's top half: "Coming up" at the top left and the flat
/// carousel under it. It only shows; every control is on the bottom half.
struct V2TabletopStage: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Environment(\.pagePalette) private var page

    /// The heading's line and the carousel's own vertical padding.
    private static let chrome: CGFloat = 44 + 28

    private var posterHeight: CGFloat {
        min(360, max(140, space.stageHeight - Self.chrome))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Coming up")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(height: 44, alignment: .topLeading)
            V2TabletopCarousel(cards: cards, posterHeight: posterHeight, focused: $focused, opening: $opening)
                .frame(maxHeight: .infinity)
        }
        .frame(height: space.stageHeight, alignment: .top)
    }
}
