import Foundation

/// Spinning the floating slab (tabletop plan, slice 6; the hinge-fix mock's
/// `spin` mode and `coast`): a sideways drag that starts on the slab turns
/// it about its upright axis, 0.011 rad a point. Let go, it keeps turning
/// at the finger's speed, slows by 0.955 a frame (at 60 a second), then
/// eases to the nearest whole turn so it ends facing the viewer. Pure
/// numbers as a function of time; the app draws them.
public enum TabletopSpin {
    /// Radians of turn per point dragged (in the scene's 669-pt design width).
    public static let perPoint = 0.011
    /// The frames the mock's coast counts in.
    public static let frameRate = 60.0
    /// The speed kept each frame while it coasts.
    public static let decay = 0.955
    /// Below this speed (radians a frame) it stops coasting and eases home.
    public static let restSpeed = 0.004
    /// The share of the way home it goes each frame.
    public static let homing = 0.09
    /// Closer to home than this (radians), it is home.
    public static let settled = 0.002

    /// The turn for a drag of `points` (design points).
    public static func turn(points: Double) -> Double { points * perPoint }

    /// The finger's speed (design points a second) as radians a frame.
    public static func velocity(pointsPerSecond: Double) -> Double {
        pointsPerSecond * perPoint / frameRate
    }

    /// The slab after the finger lets go at `start` (radians), turning
    /// `velocity` radians a frame.
    public struct Coast: Equatable, Sendable {
        public let start: Double
        public let velocity: Double

        public init(start: Double, velocity: Double) {
            self.start = start
            self.velocity = velocity
        }

        /// The frames it coasts before easing home.
        public var coastFrames: Double {
            let speed = abs(velocity)
            guard speed > TabletopSpin.restSpeed else { return 0 }
            return ceil(log(TabletopSpin.restSpeed / speed) / log(TabletopSpin.decay))
        }

        private func coasted(_ frames: Double) -> Double {
            start + velocity * (1 - pow(TabletopSpin.decay, frames)) / (1 - TabletopSpin.decay)
        }

        /// The whole turn it eases to (radians, a multiple of 2π).
        public var home: Double {
            let end = coasted(coastFrames)
            return (end / (2 * Double.pi)).rounded() * 2 * Double.pi
        }

        /// The turn `frames` after letting go (fractional frames are
        /// between), or nil once it is home (facing the viewer: no turn).
        public func angle(afterFrames frames: Double) -> Double? {
            let coasting = coastFrames
            if frames <= coasting { return coasted(max(frames, 0)) }
            let away = home - coasted(coasting)
            let left = away * pow(1 - TabletopSpin.homing, frames - coasting)
            return abs(left) < TabletopSpin.settled ? nil : home - left
        }

        /// The same, `seconds` after letting go.
        public func angle(after seconds: Double) -> Double? {
            angle(afterFrames: seconds * TabletopSpin.frameRate)
        }
    }
}
