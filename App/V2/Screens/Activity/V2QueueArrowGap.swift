import SwiftUI
import UIKit

/// The queue's content coordinate space: positions in it don't move with the scroll.
let v2QueueContentSpace = "v2QueueContent"

extension View {
    /// Folded with collapsed tabs the queue runs the full width, under the
    /// Duo's column. At rest, the block after this header must start below
    /// the column's arrow, so no count or button sits under it (owner's pick
    /// E, 2026-11-19: pinned scopes, cards full width). Pads the header's
    /// bottom by what it takes; zero when the arrow is above the content
    /// anyway, at the bottom of the column, or `column` is zero.
    /// `contentTop` is where the content starts at rest, in global space
    /// (the pinned scopes' bottom edge).
    func v2ClearsColumnArrow(column: CGFloat, contentTop: CGFloat?, spacing: CGFloat) -> some View {
        modifier(V2ColumnArrowGap(active: column > 0, column: column, contentTop: contentTop, spacing: spacing))
    }
}

private struct V2ColumnArrowGap: ViewModifier {
    let active: Bool
    let column: CGFloat
    let contentTop: CGFloat?
    let spacing: CGFloat
    /// The header's bottom in the content's space (it doesn't scroll there).
    @State private var headerBottom: CGFloat = 0
    /// The arrow's bottom, in the window.
    @State private var arrowBottom: CGFloat?

    private var gap: CGFloat {
        guard active, let contentTop, let arrowBottom else { return 0 }
        return max(0, (arrowBottom + 8) - (contentTop + headerBottom + spacing))
    }

    func body(content: Content) -> some View {
        content
            // Measured before the padding: the gap never feeds its own measure.
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(v2QueueContentSpace)).maxY } action: {
                headerBottom = $0
            }
            .padding(.bottom, gap)
            .task(id: column) {
                guard active else { arrowBottom = nil; return }
                // The system places the bar item once the column has settled.
                try? await Task.sleep(for: .milliseconds(400))
                arrowBottom = Self.arrowBottom(column: column)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                if active { arrowBottom = Self.arrowBottom(column: column) }
            }
    }

    /// The bottom of the lowest button in the column's top third: the tabs'
    /// arrow, under the clock. A system bar item: SwiftUI gives no window
    /// frame for it and UIKit doesn't carry its label (`TouchSpot`), so it is
    /// found by shape: a square, button-sized view wholly inside the column.
    @MainActor
    private static func arrowBottom(column: CGFloat) -> CGFloat? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = scene?.keyWindow, column > 0 else { return nil }
        let bounds = window.bounds
        var bottom: CGFloat?
        func visit(_ view: UIView) {
            guard !view.isHidden, view.alpha > 0.01 else { return }
            let f = view.convert(view.bounds, to: window)
            if bounds.contains(f), f.minX >= bounds.width - column - 1, f.minY < bounds.height / 3,
               (30...64).contains(f.width), abs(f.width - f.height) < 4 {
                bottom = max(bottom ?? 0, f.maxY)
            }
            view.subviews.forEach(visit)
        }
        visit(window)
        return bottom
    }
}
