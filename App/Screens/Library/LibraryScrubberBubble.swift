import SwiftUI

/// The scroll thumb's letter bubble: a 56pt light disc beside the finger with
/// the letter the grid jumped to, replaying a small "tick" pulse per letter.
///
/// The pulse snaps to 1.14 and eases back to 1 with no overshoot. It used to
/// be a 1ms `LinearKeyframe` into a `CubicKeyframe`: the cubic inherits the
/// linear segment's end velocity (140 units/s), so one tick swelled the disc
/// to about 4x, and a tick landing mid-swell restarted the 1ms segment from
/// there, so the next cubic started even faster. A fast scrub compounded it
/// until the light disc covered the whole screen for a frame (the
/// "white flash" while scrubbing).
struct ScrubberBubble: View {
    /// The letter shown; nil hides the bubble.
    let letter: String?
    /// Bumped once per new letter.
    let tick: Int

    @Environment(\.motionEnabled) private var motion

    static let pulse: CGFloat = 1.14

    var body: some View {
        let shown = letter != nil
        Text(letter ?? " ")
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Theme.bg)
            .frame(width: 56, height: 56)
            .background(Theme.txt, in: Circle())
            .overlay(Circle().strokeBorder(Theme.i1.opacity(0.6), lineWidth: 3).padding(-3))
            .shadow(color: .black.opacity(0.45), radius: 13, y: 10)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: motion ? tick : 0) { content, scale in
                // Clamped as well, so no curve can ever blow the disc up.
                content.scaleEffect(min(max(scale, 1), Self.pulse))
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(Self.pulse)
                    LinearKeyframe(1, duration: 0.16, timingCurve: .easeOut)
                }
            }
            .scaleEffect(shown ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .animation(motion ? .easeOut(duration: 0.15) : nil, value: shown)
            .allowsHitTesting(false)
    }
}
