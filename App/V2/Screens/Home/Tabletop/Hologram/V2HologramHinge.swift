import SwiftUI
import FusionhaKit

extension View {
    /// Keeps `degrees` on the device's hinge angle (iOS 27.1's
    /// `onHingeChange`), held inside the range the scene is drawn for. The
    /// angle only re-draws the picture, never the layout (the pose does
    /// that, `FoldInfo`). Without a hinge, before iOS 27.1, or with CI's
    /// fixed angle, `degrees` is left as it is.
    func readsTabletopHinge(_ degrees: Binding<Double>) -> some View {
        modifier(V2HologramHinge(degrees: degrees))
    }
}

private struct V2HologramHinge: ViewModifier {
    @Binding var degrees: Double
    @Environment(\.motionEnabled) private var motion

    /// Readings closer than this to the angle shown are jitter.
    private static let deadBand = 0.25

    func body(content: Content) -> some View {
        if V2TabletopHologram.fixedHinge != nil {
            content
        } else if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                guard let hinge = context.hinge else { return }
                let next = TabletopProjection.heldHinge(hinge.angle.degrees)
                guard abs(next - degrees) >= Self.deadBand else { return }
                // Lightly smoothed: the scene eases to each reading (the
                // system doesn't promise how often they come).
                withAnimation(motion ? .easeOut(duration: 0.12) : nil) { degrees = next }
            }
        } else {
            content
        }
    }
}
