import SwiftUI
import UIKit
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
            .gesture(SidewaysSwipe(enabled: active) { dx, flung in swiped(dx: dx, flung: flung) })
            .sensoryFeedback(.selection, trigger: tick)
    }

    private func swiped(dx: Double, flung: Double) {
        guard abs(dx) >= 70 || abs(flung) >= 180 else { return }
        guard let next = model.duoGestures.neighbor(of: id, step: dx < 0 ? 1 : -1) else { return }
        tick += 1
        model.duoGestures.swiped(to: next)
        model.open(next)
    }
}

/// A pan that only ever begins on a sideways drag, and recognises alongside
/// the page's scroll. A SwiftUI `DragGesture` on the art took part in every
/// drag that started there, and the poster-led hero fills the right page:
/// at times the page then would not scroll (owner, build 1115). This one
/// never starts for a vertical drag, so scrolling is the scroll view's alone.
private struct SidewaysSwipe: UIGestureRecognizerRepresentable {
    var enabled: Bool
    /// The drag's sideways travel and its fling (travel plus a short coast), in points.
    var onEnd: (Double, Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.isEnabled = enabled
        return pan
    }

    func updateUIGestureRecognizer(_ pan: UIPanGestureRecognizer, context: Context) {
        pan.isEnabled = enabled
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        guard pan.state == .ended else { return }
        let t = pan.translation(in: pan.view), v = pan.velocity(in: pan.view)
        guard DuoSwipe.isHorizontal(dx: Double(t.x), dy: Double(t.y)) else { return }
        onEnd(Double(t.x), Double(t.x + v.x * 0.25))
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return abs(v.x) > abs(v.y) * 1.5
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}
