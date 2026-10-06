import SwiftUI

// The web's shared motion vocabulary (components/motion/*, the CSS keyframes in
// the library/shell modules), as small SwiftUI helpers every screen can use.
// Everything goes still when Reduce Motion is on or the admin turned
// animations off (`animations_enabled`), like the web's `useReduceMotion`.

enum Motion {
    /// `REVEAL_EASE` cubic-bezier(0.52, 0.01, 0.16, 1).
    static func reveal(_ duration: Double = 0.5) -> Animation {
        .timingCurve(0.52, 0.01, 0.16, 1, duration: duration)
    }
    /// The springy indicator slide (segments, method pill, nav pill).
    static let indicator = Animation.spring(duration: 0.32, bounce: 0.3)
    /// Press feedback (`:active { transform: scale(.92) }`).
    static let press = Animation.spring(duration: 0.22, bounce: 0.35)
}

private struct MotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False when Reduce Motion is on or the server's `animations_enabled` is off.
    /// Set once at the root (RootView / SignInView).
    var motionEnabled: Bool {
        get { self[MotionEnabledKey.self] }
        set { self[MotionEnabledKey.self] = newValue }
    }
}

/// `<Reveal>`: fade up from `y` on first appearance, staggered by `index`.
private struct RevealModifier: ViewModifier {
    let index: Int
    let y: CGFloat
    let duration: Double
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(motion && !shown ? 0 : 1)
            .offset(y: motion && !shown ? y : 0)
            .onAppear {
                guard motion, !shown else { return }
                withAnimation(Motion.reveal(duration).delay(Double(min(index, 8)) * 0.06)) { shown = true }
            }
    }
}

/// Skeleton shimmer (`skshimmer` 1.4s): a light band sweeping across.
private struct ShimmerModifier: ViewModifier {
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        content.overlay {
            if motion {
                GeometryReader { geo in
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                        let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                        LinearGradient(colors: [.clear, .white.opacity(0.09), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width)
                            .offset(x: (-1 + 2 * eased) * geo.size.width)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .clipped()
    }
}

/// A breathing opacity (`attn-pulse`: .72 ↔ 1 over 2.2s).
private struct PulseOpacityModifier: ViewModifier {
    var low: Double = 0.72
    var period: Double = 2.2
    @Environment(\.motionEnabled) private var motion

    func body(content: Content) -> some View {
        if motion {
            content.phaseAnimator([false, true]) { view, phase in
                view.opacity(phase ? 1 : low)
            } animation: { _ in .easeInOut(duration: period / 2) }
        } else {
            content
        }
    }
}

extension View {
    func reveal(_ index: Int = 0, y: CGFloat = 16, duration: Double = 0.5) -> some View {
        modifier(RevealModifier(index: index, y: y, duration: duration))
    }

    func shimmer() -> some View { modifier(ShimmerModifier()) }

    func pulseOpacity(low: Double = 0.72, period: Double = 2.2) -> some View {
        modifier(PulseOpacityModifier(low: low, period: period))
    }
}

/// A dot whose halo breathes (`pulse-dot` / `trig-dot-pulse`).
struct PulsingDot: View {
    let color: Color
    var size: CGFloat = 9
    var ring: Color? = nil
    var period: Double = 1.8
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay { if let ring { Circle().strokeBorder(ring, lineWidth: 2).padding(-2) } }
            .background {
                if motion {
                    Circle().fill(color)
                        .phaseAnimator([false, true]) { view, phase in
                            view.scaleEffect(phase ? 2.2 : 1.3).opacity(phase ? 0.05 : 0.3)
                        } animation: { _ in .easeInOut(duration: period / 2) }
                } else {
                    Circle().fill(color.opacity(0.3)).scaleEffect(1.3)
                }
            }
    }
}

/// `:active { transform: scale(.92) }` for custom buttons.
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.motionEnabled) private var motion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(motion && configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed && !motion ? 0.8 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

/// A placeholder bar for skeletons (`.skeleton`).
struct SkeletonBar: View {
    var height: CGFloat = 12
    var radius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(height: height)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
