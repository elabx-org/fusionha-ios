import SwiftUI
import FusionhaKit

/// The title's column as v2's split handle pushes it toward closing: it
/// shrinks a little from its leading edge and dims, with a soft shadow on
/// the list (the mock's closing look, `DuoSeam.closeProgress`). Nothing
/// under Reduce Motion; it still moves with the seam.
///
/// `enabled` is fixed for the product (v2's handle is offered or not), so
/// the column's identity never changes with it: v1 gets the column as is.
struct DuoSeamCloseEffect: ViewModifier {
    let enabled: Bool
    let progress: CGFloat
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        if enabled {
            let p = motion ? min(1, max(0, progress)) : 0
            content
                // Opaque: the list squeezed under the title never shows through.
                .background(Theme.bg.ignoresSafeArea())
                .overlay {
                    Color.black.opacity(Double(p) * DuoSeam.closeShade)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .leading) {
                    LinearGradient(colors: [.clear, .black.opacity(0.4 * Double(p))],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: 30)
                        .offset(x: -30)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
                .scaleEffect(1 - p * CGFloat(DuoSeam.closeScale), anchor: .leading)
        } else {
            content
        }
    }
}
