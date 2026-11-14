import SwiftUI
import FusionhaKit

/// Home half folded on a table (the fold side to side), while Coming up has
/// cards and no title is open: Home spans both halves. The top half is the
/// stage (the flat carousel); the bottom half, 20 pt clear of the fold, is
/// one scrolling page: the focused title's controls first
/// (`V2TabletopControls`), then Home's sections. `V2ComingUpRow` owns the
/// feed, the cards and the focus and hands them in; nothing here reads the
/// calendar. With a title open the shell splits at the fold again and Home is
/// its ordinary page in the top half. With the hologram switched on
/// (`V2TabletopHologram`, off by default) the two halves are the hologram
/// scene instead (`V2HologramPage`).
struct V2HomeTabletop: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    let rest: AnyView
    @Environment(AppModel.self) private var model
    @AppStorage(V2TabletopHologram.key) private var hologram = false

    private static let space = "v2-tabletop-page"

    /// How far the bar pushes the page's content down (where the content starts).
    @State private var top: CGFloat = 0

    var body: some View {
        if V2TabletopHologram.isOn(stored: hologram) {
            V2HologramPage(space: space, cards: cards, current: current, focused: $focused, opening: $opening,
                           kindsRaw: $kindsRaw, days: $days)
        } else {
            flat
        }
    }

    private var flat: some View {
        // A scroll view that doesn't scroll: the system insets its content
        // below the bar (and fades it under it) as on every other Home page;
        // the container itself runs under the bar.
        ScrollView {
            VStack(spacing: 0) {
                V2TabletopStage(height: space.stageHeight(top: top), width: space.size.width, cards: cards, focused: $focused, opening: $opening)
                // The fold and the clearance either side of it: empty.
                Color.clear.frame(height: space.gapHeight)
                floor.frame(height: space.floorHeight)
            }
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
