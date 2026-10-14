import SwiftUI
import FusionhaKit

// The detail page's motion (kept local to the detail page): the reduced-motion
// switch, the web's curves, pulse / spin / reveal / shake, spinners, stripes
// and the animated coverage bar.

/// True when motion should be dropped: the system Reduce Motion setting, or the
/// server's "Animations" switch turned off (the web's ReduceMotionProvider).
private struct DetailReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var detailReduceMotion: Bool {
        get { self[DetailReduceMotionKey.self] }
        set { self[DetailReduceMotionKey.self] = newValue }
    }
}

/// The web's easing curves and durations.
enum DetailMotion {
    /// `REVEAL_EASE` (motion/Reveal.tsx).
    static func reveal(_ duration: Double = 0.5) -> Animation { .timingCurve(0.52, 0.01, 0.16, 1, duration: duration) }
    /// Coverage bar width (`width 0.4s cubic-bezier(.65,0,.35,1)`).
    static let barFill = Animation.timingCurve(0.65, 0, 0.35, 1, duration: 0.4)
    /// The flyout's `cubic-bezier(.32,.72,0,1)`.
    static let sheet = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.44)
    /// The overshooting pop of the search button (`cubic-bezier(.34,1.6,.5,1)`).
    static let pop = Animation.timingCurve(0.34, 1.6, 0.5, 1, duration: 0.25)
    static let quick = Animation.easeInOut(duration: 0.15)
}

extension View {
    /// `.animation(_:value:)` that turns off under reduced motion.
    func detailAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(DetailAnimationModifier(animation: animation, value: value))
    }

    /// Opacity breathing between `low` and `high` (`coverPulse`, `pausePulse`…). Static under reduced motion.
    func detailPulse(low: Double = 0.6, high: Double = 1, period: Double = 1.5, active: Bool = true) -> some View {
        modifier(PulseModifier(low: low, high: high, period: period, active: active))
    }

    /// A continuous rotation (spinners). Static under reduced motion.
    func detailSpin(period: Double = 0.9) -> some View {
        modifier(SpinModifier(period: period))
    }

    /// Fade-and-rise entrance (`Reveal`): from `y` below and transparent, once.
    func detailReveal(delay: Double = 0, y: CGFloat = 14, duration: Double = 0.5) -> some View {
        modifier(RevealModifier(delay: delay, y: y, duration: duration))
    }

    /// The horizontal `shake` keyframe, replayed whenever `trigger` changes.
    func detailShake(trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

private struct DetailAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let animation: Animation
    let value: V
    func body(content: Content) -> some View {
        content.animation(reduce ? nil : animation, value: value)
    }
}

private struct PulseModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let low: Double, high: Double, period: Double, active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .opacity(reduce || !active ? 1 : (on ? high : low))
            .onAppear {
                guard !reduce, active else { return }
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

private struct SpinModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let period: Double
    @State private var angle = 0.0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard !reduce else { return }
                withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) { angle = 360 }
            }
    }
}

private struct RevealModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let delay: Double, y: CGFloat, duration: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : y)
            .onAppear {
                guard !shown else { return }
                if reduce { shown = true; return }
                withAnimation(DetailMotion.reveal(duration).delay(delay)) { shown = true }
            }
    }
}

private struct ShakeEffect: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        // 0 → -3 → +3 → 0 over one cycle, like the web's `shake`.
        ProjectionTransform(CGAffineTransform(translationX: -3 * sin(progress * .pi * 2), y: 0))
    }
}

private struct ShakeModifier: ViewModifier {
    @Environment(\.detailReduceMotion) private var reduce
    let trigger: Int
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(progress: CGFloat(trigger)))
            .animation(reduce ? nil : .easeInOut(duration: 0.4), value: trigger)
    }
}

/// A spinning ring (`.spin` / `analysisSpin` / `download-pill-spin`).
struct DetailSpinner: View {
    var size: CGFloat = 15
    var color: Color = Theme.txt
    var period: Double = 0.65

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .background(Circle().stroke(DetailTokens.line2, lineWidth: 2))
            .frame(width: size, height: size)
            .detailSpin(period: period)
    }
}

/// Diagonal white stripes sliding along a downloading fill (`seasonBarStripe`, 18px period, 0.85s).
struct DetailStripes: View {
    @Environment(\.detailReduceMotion) private var reduce

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { timeline in
            let phase = reduce ? 0 : CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.85) / 0.85) * 18
            Canvas { context, size in
                var x = -size.height - 18 + phase
                while x < size.width + 18 {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height + 6, y: 0))
                    path.addLine(to: CGPoint(x: x + 6, y: size.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(.white.opacity(0.28)))
                    x += 18
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Bars

/// A rounded coverage bar with owned + grabbing segments that animate their width.
struct DetailCoverageBar: View {
    let total: Int
    let owned: Int
    var grabbing: Int = 0
    let color: Color
    var height: CGFloat = 8
    var track: Color = Theme.txt.opacity(0.09)
    @State private var shown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let ownedW = total > 0 ? w * CGFloat(owned) / CGFloat(total) : 0
            let grabW = total > 0 ? w * CGFloat(grabbing) / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                HStack(spacing: 0) {
                    Rectangle().fill(color).frame(width: shown ? ownedW : 0)
                    if grabbing > 0 {
                        Rectangle().fill(Theme.grab).frame(width: shown ? grabW : 0).detailPulse()
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .detailAnimation(DetailMotion.barFill, value: shown)
        .detailAnimation(DetailMotion.barFill, value: owned)
        .onAppear { shown = true }
    }
}
