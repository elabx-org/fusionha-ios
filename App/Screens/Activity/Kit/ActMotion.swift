import SwiftUI
import FusionhaKit

// MARK: Motion (components/motion/Reveal + the queue/tasks @keyframes)

struct ActReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when the OS asks for reduced motion OR the server's `animations_enabled`
    /// setting is off — the web's `useReduceMotion()`.
    var actReduceMotion: Bool {
        get { self[ActReduceMotionKey.self] }
        set { self[ActReduceMotionKey.self] = newValue }
    }
}

enum ActMotion {
    /// The web's `REVEAL_EASE` cubic-bezier(.52,.01,.16,1).
    static func reveal(_ duration: Double = 0.5) -> Animation { .timingCurve(0.52, 0.01, 0.16, 1, duration: duration) }
    /// Progress-fill width transition: cubic-bezier(.3,.7,.3,1) 0.5s.
    static let fill = Animation.timingCurve(0.3, 0.7, 0.3, 1, duration: 0.5)
    /// Row insert/remove.
    static let rows = Animation.timingCurve(0.52, 0.01, 0.16, 1, duration: 0.35)

    /// CSS `ease-in-out` on a 0...1 phase.
    static func easeInOut(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
}

// The looping effects below are SwiftUI repeat-forever animations of a
// transform/opacity, which the render loop interpolates without re-running any
// view body. They used to be `TimelineView(.animation)` loops that re-evaluated
// (and re-laid out) every bar, dot and spinner 30 times a second, which kept the
// main thread ~50% busy on an idle Queue tab (`RepeatForever`). All of them
// are static under reduced motion.

/// `queue-sweep` / `activity-sweep`: a translucent solid band crossing a
/// progress fill, 1.35s ease-in-out (no gradient on progress, web 0.4.218).
struct ActShimmer: View {
    var duration = 1.35
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        if !reduce {
            GeometryReader { geo in
                RepeatForever(animation: .easeInOut(duration: duration).repeatForever(autoreverses: false)) { on in
                    Theme.i1.opacity(0.22)
                        .frame(width: geo.size.width * 0.3)
                        .offset(x: geo.size.width * (on ? 1 : -0.3))
                }
            }
            .clipped()
            .allowsHitTesting(false)
        }
    }
}

/// `queue-indet`: an indeterminate 36%-wide band sliding from -36% to 100%.
struct ActIndeterminateBar: View {
    var color: Color = Theme.indigo
    var height: CGFloat = 5
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.txt.opacity(0.09))
                if reduce {
                    Capsule().fill(color.opacity(0.6)).frame(width: geo.size.width * 0.36)
                } else {
                    RepeatForever(animation: .easeInOut(duration: 1.35).repeatForever(autoreverses: false)) { on in
                        Capsule()
                            .fill(color.opacity(0.85))
                            .frame(width: geo.size.width * 0.36)
                            .offset(x: geo.size.width * (on ? 1 : -0.36))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

/// `queue-pulse-dot` / `tasks-livepulse` / `queue-hold-breathe`: a dot with an
/// expanding ring that fades out.
struct ActPulseDot: View {
    let color: Color
    var size: CGFloat = 7
    var spread: CGFloat = 7
    var duration = 1.8
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background {
                if !reduce {
                    RepeatForever(animation: .easeOut(duration: duration).repeatForever(autoreverses: false)) { on in
                        Circle()
                            .fill(color.opacity(0.55))
                            .frame(width: size, height: size)
                            .scaleEffect(on ? (size + 2 * spread) / size : 1)
                            .opacity(on ? 0 : 1)
                    }
                }
            }
    }
}

/// `processspin` / `task-spin`: a continuous rotation (static under reduced motion).
struct ActSpin: ViewModifier {
    let active: Bool
    var duration = 0.8
    @Environment(\.actReduceMotion) private var reduce

    func body(content: Content) -> some View {
        if active && !reduce {
            RepeatForever(animation: .linear(duration: duration).repeatForever(autoreverses: false)) { on in
                content.rotationEffect(.degrees(on ? 360 : 0))
            }
        } else {
            content
        }
    }
}

/// `Reveal` / `RevealItem`: fade + 16pt rise on first appearance, staggered.
struct ActReveal: ViewModifier {
    /// Only the first screenful staggers in. Rows further down appear as they
    /// are, so a fast scroll neither shows blank space nor keeps several rows
    /// mid-animation (each animating row is re-rendered every frame).
    static let staggered = 12

    var index = 0
    var stagger = 0.04
    @Environment(\.actReduceMotion) private var reduce
    @State private var shown: Bool

    init(index: Int = 0, stagger: Double = 0.04) {
        self.index = index
        self.stagger = stagger
        _shown = State(initialValue: index >= Self.staggered)
    }

    func body(content: Content) -> some View {
        content
            .opacity(reduce || shown ? 1 : 0)
            .offset(y: reduce || shown ? 0 : 16)
            .onAppear {
                guard !reduce, !shown else { return }
                withAnimation(ActMotion.reveal(0.5).delay(Double(index) * stagger)) { shown = true }
            }
    }
}

extension View {
    func actReveal(_ index: Int = 0, stagger: Double = 0.04) -> some View { modifier(ActReveal(index: index, stagger: stagger)) }
    func actSpin(_ active: Bool, duration: Double = 0.8) -> some View { modifier(ActSpin(active: active, duration: duration)) }

    /// List insert/remove: fade + slight slide, no motion under reduce.
    func actRowTransition(_ reduce: Bool) -> some View {
        transition(reduce ? .identity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 12)),
                                                     removal: .opacity.combined(with: .scale(scale: 0.97))))
    }
}

/// A solid progress fill (no gradients, owner rule) with the width
/// transition and the shimmer sweep.
struct ActProgressBar: View {
    let fraction: Double
    var height: CGFloat = 5
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.grab)
    var shimmer = true
    /// Under Monochrome the fill is this status' solid shade and pattern instead.
    var mono: MonoToken? = nil
    @Environment(\.actReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.txt.opacity(0.09))
                fillShape
                    .overlay { if shimmer { ActShimmer() } }
                    .clipShape(Capsule())
                    .frame(width: max(0, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(reduce ? nil : ActMotion.fill, value: fraction)
    }

    @ViewBuilder
    private var fillShape: some View {
        if Theme.isMono, let mono {
            StatusSwatch(token: mono, shape: Capsule())
        } else {
            Capsule().fill(fill)
        }
    }
}
