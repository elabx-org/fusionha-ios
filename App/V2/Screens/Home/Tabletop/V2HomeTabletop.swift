import SwiftUI
import FusionhaKit

/// Home half folded on a table (the fold side to side), while Coming up has
/// cards and no title is open: Home spans both halves. The top half is the
/// stage (the flat carousel); the bottom half, 20 pt clear of the fold, is
/// one scrolling page: the focused title's controls first
/// (`V2TabletopControls`), then Home's sections. `V2ComingUpRow` owns the
/// feed, the cards and the focus and hands them in; nothing here reads the
/// calendar. With a title open the shell splits at the fold again and Home is
/// its ordinary page in the top half.
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

    var body: some View {
        VStack(spacing: 0) {
            V2TabletopStage(space: space, cards: cards, focused: $focused, opening: $opening)
            // The fold and the clearance either side of it: empty.
            Color.clear.frame(height: max(0, space.floorTop - space.stageHeight))
            floor.frame(height: space.floorHeight)
        }
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
