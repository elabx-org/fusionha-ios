import SwiftUI
import FusionhaKit

// MARK: - The right page's leading edge (gestures 1 and 2, `DuoSwipe`)
//
// A strip down the page's leading edge, under its bar so the bar's buttons
// stay tappable:
// - swipe right: the page follows the finger and swings shut (gesture 1);
//   with the list hidden, the list comes back first (gesture 2);
// - swipe left: hides the list, flat open only, as the sidebar button does.
// Inside a preview's own stack the system Back owns the edge (`canClose`).
// A light tick when letting go would commit; let go early and it springs back.

/// Whether the page's own stack is at its root (a preview's "More like
/// this" pushes): only then does the edge close the page.
struct DuoPageAtRoot: PreferenceKey {
    static let defaultValue = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value && nextValue() }
}

/// The page under the finger: offset, and swung on its leading edge as it
/// goes (no swing under Reduce Motion; it still follows the finger).
struct DuoPageDragEffect: ViewModifier {
    let offset: CGFloat
    let width: CGFloat
    let motion: Bool

    func body(content: Content) -> some View {
        let progress = width > 0 ? min(1, max(0, offset / width)) : 0
        content
            .offset(x: offset)
            .rotation3DEffect(.degrees(motion ? Double(progress) * 14 : 0), axis: (x: 0, y: 1, z: 0),
                              anchor: .leading, perspective: 0.55)
            .opacity(1 - Double(progress) * 0.5)
    }
}

struct DuoPageEdge: View {
    let width: CGFloat
    let canClose: Bool
    let list: DuoListToggle?
    @Binding var offset: CGFloat
    let close: () -> Void

    @State private var armed = false
    /// How far the list moves before letting go hides or shows it.
    private static let listExtent: Double = 160

    var body: some View {
        Color.clear
            .frame(width: CGFloat(DuoSwipe.edgeWidth))
            .contentShape(Rectangle())
            .gesture(drag)
            .padding(.top, 64)
            .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, now in now }
            .accessibilityHidden(true)
    }

    private func action(_ dx: CGFloat) -> DuoSwipe.EdgeAction {
        DuoSwipe.edgeAction(dx: Double(dx), listHidden: list?.hidden ?? false,
                            canHideList: list != nil, canClose: canClose)
    }

    private func commits(_ value: DragGesture.Value, _ action: DuoSwipe.EdgeAction) -> Bool {
        let extent = action == .closePage ? Double(width) : Self.listExtent
        return DuoSwipe.commits(translation: abs(Double(value.translation.width)),
                                predicted: abs(Double(value.predictedEndTranslation.width)), extent: extent)
            && action != .none
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let dx = value.translation.width
                switch action(dx) {
                case .closePage: offset = max(0, dx)
                // The list moves on commit (its own slide); the page hints the way.
                case .showList, .hideList: offset = dx * 0.12
                case .none: offset = 0
                }
                armed = commits(value, action(dx))
            }
            .onEnded { value in
                let act = action(value.translation.width)
                let commit = commits(value, act)
                armed = false
                guard commit else {
                    withAnimation(.spring(duration: 0.3, bounce: 0)) { offset = 0 }
                    return
                }
                switch act {
                case .closePage:
                    withAnimation(.spring(duration: 0.26, bounce: 0)) { offset = width } completion: {
                        var instant = Transaction()
                        instant.disablesAnimations = true
                        withTransaction(instant) {
                            close()
                            offset = 0
                        }
                    }
                case .showList, .hideList:
                    list?.toggle()
                    withAnimation(.spring(duration: 0.3, bounce: 0)) { offset = 0 }
                case .none:
                    offset = 0
                }
            }
    }
}
