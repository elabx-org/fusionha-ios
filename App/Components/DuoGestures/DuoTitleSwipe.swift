import SwiftUI
import FusionhaKit

// MARK: - Next / previous title (gesture 3, `DuoSwipe`)
//
// On the open Duo's right page, a sideways swipe across the hero art opens
// the next (swipe left) or previous (swipe right) title in the Library grid's
// current order and filters; the new page swings in (`DuoPageMotion`) and the
// grid scrolls to it. Only the art takes it, so the rails further down keep
// their own sideways scroll; a vertical drag still scrolls the page.

extension View {
    /// The hero art of title `id`: swipe to its neighbours in the Library order.
    func duoTitleSwipe(id: Int) -> some View {
        modifier(DuoTitleSwipe(id: id))
    }
}

private struct DuoTitleSwipe: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.detailInColumn) private var inColumn
    @Environment(\.duoOpen) private var duoOpen
    let id: Int
    @State private var tick = 0

    private var active: Bool { inColumn && duoOpen && model.tab == .library }

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(swipe, including: active ? .all : .subviews)
            .sensoryFeedback(.selection, trigger: tick)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = Double(value.translation.width)
                guard DuoSwipe.isHorizontal(dx: dx, dy: Double(value.translation.height)) else { return }
                let travel = abs(dx), flung = abs(Double(value.predictedEndTranslation.width))
                guard travel >= 70 || flung >= 180 else { return }
                guard let next = model.duoGestures.neighbor(of: id, step: dx < 0 ? 1 : -1) else { return }
                tick += 1
                model.duoGestures.swiped(to: next)
                model.open(next)
            }
    }
}
