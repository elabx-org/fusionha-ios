import SwiftUI
import FusionhaKit

/// The tabletop's flat look (slice 1): the top half is the stage (the flat
/// carousel, `V2TabletopStage`); the bottom half, 20 pt clear of the fold,
/// is one scrolling page: the focused title's controls first
/// (`V2TabletopControls`, with the Hologram switch), then Home's sections.
/// While the hologram lifts (`V2HomeTabletop`) the scene draws the stage's
/// posters, so the stage hides (`stageOpacity`), the bottom half fades
/// (`floorOpacity`) and nothing takes touches (`live`); all three are applied
/// inside the scroll view, whose own place in the page never changes. It
/// reports where its content starts (`top`), which is where the lift's flat
/// posters are measured from.
struct V2TabletopFlat: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    let rest: AnyView
    /// How far the bar pushes the page's content down (where the content starts).
    @Binding var top: CGFloat
    var stageOpacity: Double = 1
    var floorOpacity: Double = 1
    var live = true
    @Environment(AppModel.self) private var model

    private static let space = "v2-tabletop-page"

    var body: some View {
        // A scroll view that doesn't scroll: the system insets its content
        // below the bar (and fades it under it) as on every other Home page;
        // the container itself runs under the bar.
        ScrollView {
            VStack(spacing: 0) {
                V2TabletopStage(height: space.stageHeight(top: top), width: space.size.width, cards: cards,
                                focused: $focused, opening: $opening, shows: stageOpacity)
                // The fold and the clearance either side of it: empty.
                Color.clear.frame(height: space.gapHeight)
                floor
                    .frame(height: space.floorHeight)
                    .opacity(floorOpacity)
            }
            .allowsHitTesting(live)
            // Where the content really starts, in the container's coordinates
            // (the fold's): the scroll view's reported inset was not it.
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.space)).minY } action: { top = $0 }
        }
        .scrollDisabled(true)
        .coordinateSpace(name: Self.space)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var floor: some View {
        ScrollView {
            VStack(spacing: 0) {
                V2TabletopControls(cards: cards, current: current, focused: $focused, kindsRaw: $kindsRaw, days: $days)
                rest.padding(.top, 22)
            }
            .padding(.bottom, Theme.pageBottom)
        }
        .refreshable { await model.loadLibrary() }
    }
}
