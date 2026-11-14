import SwiftUI

extension V2ComingUpWideMetrics {
    /// The tabletop stage's carousel: 2:3 posters `height` tall, the focused
    /// one in the middle and one smaller neighbour each side, facing the
    /// viewer; anything further out is gone. Reduce Motion: no scaling or
    /// overlap, the row simply pages.
    init(tabletopHeight height: CGFloat, motion: Bool) {
        let h = height.rounded()
        let w = (h * 2 / 3).rounded()
        size = CGSize(width: w, height: h)
        spacing = motion ? -(w * 0.1).rounded() : 18
        scales = motion ? [1, 0.74, 0.5] : [1, 1]
        opacities = [1, 0.8, 0]
        pulls = motion ? [0, 0, 0] : [0, 0]
    }
}
