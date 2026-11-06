import SwiftUI
import UIKit

/// Our own minimize of the iPhone Duo's vertical tab column (S14, mock
/// minimize.js "scrolled"). `.tabBarMinimizeBehavior(.onScrollDown)` shrinks
/// the iPhone's bar but left the Duo's column as it was on device (build
/// 838), so the shell hides every tab but the current one and Search while
/// the content scrolls down, and brings them back scrolling up, on tapping
/// the current tab, or when the tab changes.
@MainActor
@Observable
final class ColumnMinimize {
    private(set) var minimized = false
    /// Off where the column isn't vertical (iPhone, iPad): the system's own
    /// minimize applies there.
    @ObservationIgnored var enabled = false
    @ObservationIgnored var reduceMotion = false

    /// A vertical drag in a tab's content: `down` is the content scrolling down.
    func scrolled(down: Bool) {
        guard enabled, minimized != down else { return }
        set(down)
    }

    func expand() {
        if minimized { set(false) }
    }

    private func set(_ value: Bool) {
        if reduceMotion {
            minimized = value
        } else {
            withAnimation(.smooth(duration: 0.3)) { minimized = value }
        }
    }
}

extension EnvironmentValues {
    /// The shell's column minimize, for tab roots to report their scroll; nil in v1.
    @Entry var columnMinimize: ColumnMinimize?
}

/// A pan that watches vertical drags without taking them from the scroll
/// view under it (it recognizes alongside every other gesture and never
/// cancels touches). Reports each 24pt of mostly vertical travel.
struct VerticalScrollWatch: UIGestureRecognizerRepresentable {
    /// `true` when the finger moves up, so the content scrolls down.
    var onScroll: (Bool) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        guard pan.state == .changed else { return }
        let t = pan.translation(in: pan.view)
        guard abs(t.y) >= 24, abs(t.y) > abs(t.x) * 1.5 else { return }
        onScroll(t.y < 0)
        pan.setTranslation(.zero, in: pan.view)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

extension View {
    /// Reports this tab's vertical scrolling to the shell's column minimize
    /// (`ColumnMinimize`); unchanged in v1, which has none.
    func reportsColumnScroll(_ minimize: ColumnMinimize?) -> some View {
        modifier(ColumnScrollReport(minimize: minimize))
    }
}

private struct ColumnScrollReport: ViewModifier {
    let minimize: ColumnMinimize?

    func body(content: Content) -> some View {
        if let minimize {
            content.gesture(VerticalScrollWatch { down in minimize.scrolled(down: down) })
        } else {
            content
        }
    }
}
