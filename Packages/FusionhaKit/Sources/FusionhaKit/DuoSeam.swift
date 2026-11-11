import Foundation

/// v2's split handle on the flat open Duo (owner-approved 2026-11-05, mock
/// https://claude.ai/artifact/8FMR9KrECRveDDvqn3xUBi): a pill on the seam
/// between the list and the open title. Dragged, the seam follows the
/// finger; let go, it snaps to one of three places (the title full width,
/// the split, the title closed). The thresholds and the spring are the
/// mock's, kept here so they are unit-tested. Every `x` is the seam's
/// distance from the display's leading edge, in points.
public enum DuoSeam {
    /// Where letting go can land.
    public enum Stop: Equatable, Sendable {
        /// The list hidden, the title across the display.
        case fullWidth
        /// The list beside the title.
        case split
        /// The title closed, the list across the display.
        case closed
    }

    /// A release faster than this (points per second) goes to the next stop
    /// in its direction, wherever the seam is.
    public static let flick = 500.0
    /// Short of this share of the split, letting go goes full width.
    public static let fullZone = 0.5
    /// Past this share of the display, letting go closes the title.
    public static let closeZone = 0.66
    /// Past either end the seam moves as the overshoot to this power.
    public static let rubberPower = 0.7
    /// How far the list slides as it is squeezed: this share of the squeeze.
    public static let listSlide = 0.35
    /// The list's dim at the leading edge (none at the split).
    public static let listDim = 0.55
    /// The share of the display past the split over which the title fully
    /// takes on its closing look.
    public static let closeReach = 0.45
    /// The title's shrink at its full closing look.
    public static let closeScale = 0.05
    /// The title's dim at its full closing look.
    public static let closeShade = 0.45
    /// The labels ("Close", "Full width") wait this far from the split,
    /// then fade in over `labelFade`.
    public static let labelDeadZone = 60.0
    public static let labelFade = 150.0
    /// A touch that moves less than this is a tap.
    public static let tapSlop = 3.0
    /// Within this of the split the seam counts as at it.
    public static let atSplit = 2.0
    /// The snap spring's stiffness and damping ratio (a little under critical).
    public static let stiffness = 170.0
    public static let dampingRatio = 0.82

    /// The list's shares of the display the split can rest at (owner,
    /// 2026-11-11): a third (the title three quarters-ish wide, as it always
    /// was) and a half (two phone-width pages side by side).
    public static let splitShares = [1.0 / 3, 0.5]

    /// The split share nearest a seam let go at `x`.
    public static func splitShare(x: Double, width: Double) -> Double {
        guard width > 0 else { return splitShares[0] }
        return splitShares.min { abs($0 * width - x) < abs($1 * width - x) } ?? splitShares[0]
    }

    /// The seam's place at `stop`. `split`: the seam's place in the split.
    public static func position(of stop: Stop, width: Double, split: Double) -> Double {
        switch stop {
        case .fullWidth: return 0
        case .split: return split
        case .closed: return width
        }
    }

    /// The finger's seam `x` past either end, slowed down.
    public static func rubberBand(_ x: Double, width: Double) -> Double {
        if x < 0 { return -pow(-x, rubberPower) }
        if x > width { return width + pow(x - width, rubberPower) }
        return x
    }

    /// The stop a slow release at `x` goes to.
    public static func zone(_ x: Double, width: Double, split: Double) -> Stop {
        if x < split * fullZone { return .fullWidth }
        if x > width * closeZone { return .closed }
        return .split
    }

    /// Where letting go at `x` lands. `velocity`: the finger's speed at
    /// release, points per second (positive = toward closing).
    public static func target(x: Double, velocity: Double, width: Double, split: Double) -> Stop {
        guard abs(velocity) > flick else { return zone(x, width: width, split: split) }
        if velocity > 0 { return x < split ? .split : .closed }
        return x > split ? .split : .fullWidth
    }

    /// A tap on the handle: at the split it goes full width, else back to the split.
    public static func tapTarget(x: Double, split: Double) -> Stop {
        abs(x - split) < atSplit ? .fullWidth : .split
    }

    /// One stop over from `stop` (VoiceOver's adjust, the arrow keys).
    public static func next(from stop: Stop, towardClose: Bool) -> Stop {
        switch (stop, towardClose) {
        case (.fullWidth, true): return .split
        case (.split, true), (.closed, true): return .closed
        case (.closed, false): return .split
        case (.split, false), (.fullWidth, false): return .fullWidth
        }
    }

    /// How far into its closing look the title is, 0...1: none up to the split.
    public static func closeProgress(x: Double, width: Double, split: Double) -> Double {
        guard x > split, width > 0 else { return 0 }
        return min(1, (x - split) / (width * closeReach))
    }

    /// The "Close" label's opacity while dragging, 0...1.
    public static func closeLabel(x: Double, split: Double) -> Double {
        clamp((x - split - labelDeadZone) / labelFade)
    }

    /// The "Full width" label's opacity while dragging, 0...1.
    public static func fullLabel(x: Double, split: Double) -> Double {
        clamp((split - labelDeadZone - x) / labelFade)
    }

    /// The list's dim as the seam squeezes it, 0...`listDim`.
    public static func listShade(x: Double, split: Double) -> Double {
        guard split > 0, x < split else { return 0 }
        return listDim * (1 - max(0, x) / split)
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }

    /// The snap: a damped spring stepped frame by frame from the release.
    public struct Spring: Equatable, Sendable {
        public var x: Double
        public var velocity: Double

        public init(x: Double, velocity: Double) {
            self.x = x
            self.velocity = velocity
        }

        /// One frame of `dt` seconds (capped, so a stalled frame never jumps).
        public mutating func step(toward target: Double, dt: Double, dampingRatio: Double = DuoSeam.dampingRatio) {
            let dt = min(0.032, max(0, dt))
            let damping = 2 * stiffness.squareRoot() * dampingRatio
            let force = -stiffness * (x - target) - damping * velocity
            velocity += force * dt
            x += velocity * dt
        }

        /// Close enough and slow enough to stop on `target`.
        public func settled(at target: Double) -> Bool {
            abs(x - target) < 0.4 && abs(velocity) < 4
        }
    }
}
