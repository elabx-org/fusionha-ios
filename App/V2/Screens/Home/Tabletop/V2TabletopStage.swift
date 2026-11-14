import SwiftUI
import FusionhaKit

/// The tabletop's top half: "Coming up" at the top left and the flat
/// carousel under it. It only shows; every control is on the bottom half.
/// While the hologram lifts, the scene draws the heading and the posters in
/// this stage's place (`V2TabletopSpace.flatCarousel`) and the stage hides,
/// still laid out and still on its focused card.
struct V2TabletopStage: View {
    /// The stage's height: from under the bar to 20 pt above the fold.
    let height: CGFloat
    let width: CGFloat
    let cards: [V2ComingUpCard]
    @Binding var focused: Int?
    @Binding var opening: Int?
    /// 0 while the scene draws in its place (the lift).
    var shows: Double = 1
    @Environment(\.pagePalette) private var page

    /// The heading's line.
    static let headingHeight: CGFloat = 44
    /// The heading's line and the carousel's own vertical padding.
    private static let chrome: CGFloat = headingHeight + 28

    /// The focused poster's height on a stage `stage` tall.
    static func posterHeight(stage: CGFloat) -> CGFloat {
        min(360, max(140, stage - chrome))
    }

    private var posterHeight: CGFloat { Self.posterHeight(stage: height) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Coming up")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(height: Self.headingHeight, alignment: .topLeading)
            V2TabletopCarousel(cards: cards, posterHeight: posterHeight, containerWidth: width,
                               focused: $focused, opening: $opening)
                // A new poster size is a new row, opened on the focused card:
                // resized in place it kept its offset and sat off its focus.
                .id(Int(posterHeight))
                .frame(maxHeight: .infinity)
        }
        .frame(height: height, alignment: .top)
        .opacity(shows)
        .accessibilityHidden(shows <= 0)
    }
}
