import SwiftUI
import FusionhaKit

// MARK: Motion (web `components/motion/Reveal` + the Calendar keyframes)

/// Motion is off under the system Reduce Motion setting OR the server's
/// `animations_enabled = false` (the web's ReduceMotionProvider "always" mode).
private struct CalMotionOffKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var calMotionOff: Bool {
        get { self[CalMotionOffKey.self] }
        set { self[CalMotionOffKey.self] = newValue }
    }
}

enum CalMotion {
    /// framer-motion `REVEAL_EASE` [0.52, 0.01, 0.16, 1].
    static func reveal(duration: Double = 0.5) -> Animation {
        .timingCurve(0.52, 0.01, 0.16, 1, duration: duration)
    }
}

/// `Reveal` / `RevealItem`: fades up from 16pt with a per-item stagger, on mount.
/// Instant when motion is off.
private struct CalReveal: ViewModifier {
    let index: Int
    let stagger: Double
    var y: CGFloat = 16
    @Environment(\.calMotionOff) private var motionOff
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let off = motionOff || reduceMotion
        content
            .opacity(off || shown ? 1 : 0)
            .offset(y: off || shown ? 0 : y)
            .onAppear {
                guard !off, !shown else { return }
                // Long lists cap the stagger so late items don't wait seconds.
                let delay = Double(min(index, 40)) * stagger
                withAnimation(CalMotion.reveal().delay(delay)) { shown = true }
            }
    }
}

extension View {
    func calReveal(_ index: Int, stagger: Double, y: CGFloat = 16) -> some View {
        modifier(CalReveal(index: index, stagger: stagger, y: y))
    }
}

/// A live grab's background: a static grab wash over the base (C3: the wash no
/// longer exists only as a pulse, so it survives Reduce Motion).
private struct CalLivePulse: ViewModifier {
    let live: Bool
    let shape: RoundedRectangle
    var base: Color = Theme.mut.opacity(0.10)

    func body(content: Content) -> some View {
        content.background {
            shape.fill(base).overlay {
                if live { shape.fill(Theme.grab.opacity(0.12)) }
            }
        }
    }
}

extension View {
    func calLivePulse(_ live: Bool, shape: RoundedRectangle, base: Color = Theme.mut.opacity(0.10)) -> some View {
        modifier(CalLivePulse(live: live, shape: shape, base: base))
    }
}
