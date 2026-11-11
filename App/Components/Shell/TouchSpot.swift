import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

// MARK: - Where the last touch landed (for the arrow's pill)
//
// The tabs' arrow is a system bar item: SwiftUI's geometry for its label is
// in the bar's own space, not the window's (build 1137 opened the pill at
// the top-left of the display). The system also moves the item as the
// column's status items come and go, so no constant is right either. UIKit
// knows: a passive recognizer on the window notes the control under each
// touch, in window coordinates, and the arrow reads it when it is tapped.

@MainActor
enum TouchSpot {
    /// The control under the last touch, in window coordinates (a 46pt
    /// square on the touch when no control-sized view was under it).
    static var last: CGRect = .zero
}

/// Never recognises: it only looks at where touches begin.
private final class TouchSpotRecognizer: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        defer { state = .failed }
        guard let touch = touches.first, let window = touch.window else { return }
        let point = touch.location(in: window)
        var frame = CGRect(x: point.x - 23, y: point.y - 23, width: 46, height: 46)
        var view = touch.view
        while let candidate = view {
            let f = candidate.convert(candidate.bounds, to: window)
            if (36...72).contains(f.width), (36...72).contains(f.height) {
                frame = f
                break
            }
            view = candidate.superview
        }
        TouchSpot.last = frame
    }
}

/// Installs the recognizer on its window, and tells where this view's own
/// origin is in that window (`ColumnPillHost` draws from it).
struct TouchSpotProbe: UIViewRepresentable {
    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window, !(window.gestureRecognizers ?? []).contains(where: { $0 is TouchSpotRecognizer }) else { return }
            let recognizer = TouchSpotRecognizer()
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            window.addGestureRecognizer(recognizer)
        }

        /// This view's origin in its window.
        var windowOrigin: CGPoint { convert(CGPoint.zero, to: nil) }
    }

    let onMake: (ProbeView) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        onMake(view)
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {}
}
