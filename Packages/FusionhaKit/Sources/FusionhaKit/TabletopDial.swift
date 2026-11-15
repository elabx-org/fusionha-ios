import Foundation

/// The hologram's emitter ring as a dial (tabletop plan, slice 6; the
/// hinge-fix mock's `dial` mode and `DET`): a finger on the band round the
/// ring's rim turns it, 40° a title, clockwise to the next. While the
/// finger is down the scene follows the fractional position; the nearest
/// title is committed as it changes and the ring settles on it on release.
/// Pure numbers; the app reads the finger and draws.
public enum TabletopDial {
    /// One title per this much turn (radians).
    public static let detent = 40 * Double.pi / 180
    /// The notches on the rim, every 20°.
    public static let notchStep = 20 * Double.pi / 180
    /// The band that takes the finger: this far either side of the rim.
    public static let band = 24.0
    /// Nothing takes touches this close to the fold.
    public static let foldClearance = 20.0
    /// How far past the first and last title the ring follows the finger.
    public static let overrun = 0.3

    /// A change of angle (radians) taken the short way round, in -π…π: the
    /// finger's angle jumps by 2π where atan2 wraps.
    public static func unwrap(_ delta: Double) -> Double {
        var d = delta.truncatingRemainder(dividingBy: 2 * Double.pi)
        if d > Double.pi { d -= 2 * Double.pi }
        if d < -Double.pi { d += 2 * Double.pi }
        return d
    }

    /// The notches' turn (radians) for a ring position: they turn with the
    /// focus, 40° a title, however it is turned.
    public static func turn(at position: Double) -> Double { position * detent }

    /// Whether a finger at `point` takes the dial: within `band` of the rim
    /// (radius `TabletopScene.emitterRadius`, both times `scale` on this
    /// display) round `centre`, and at least `foldClearance` below the fold's
    /// lower edge (`foldBottom`). Display points, y down.
    public static func accepts(_ point: TabletopPoint, centre: TabletopPoint, scale: Double, foldBottom: Double) -> Bool {
        guard point.y >= foldBottom + foldClearance else { return false }
        let r = hypot(point.x - centre.x, point.y - centre.y)
        let rim = TabletopScene.emitterRadius * scale, reach = band * scale
        return r >= rim - reach && r <= rim + reach
    }

    /// The finger's angle round `centre` (radians; y down, so clockwise on
    /// the display is increasing).
    public static func angle(of point: TabletopPoint, centre: TabletopPoint) -> Double {
        atan2(point.y - centre.y, point.x - centre.x)
    }

    /// One turn of the dial, from the finger going down to its release.
    public struct Drag: Equatable, Sendable {
        /// The ring's position when the finger went down.
        public let start: Double
        public let count: Int
        /// The finger's last angle and the turn so far (unwrapped).
        public private(set) var angle: Double
        public private(set) var turned = 0.0

        public init(position: Double, count: Int, angle: Double) {
            start = position
            self.count = count
            self.angle = angle
        }

        /// The finger moved to `angle`.
        public mutating func move(to next: Double) {
            turned += TabletopDial.unwrap(next - angle)
            angle = next
        }

        /// The ring's fractional position: it follows the finger a little
        /// past the first and last title.
        public var position: Double {
            let raw = start + turned / TabletopDial.detent
            return min(max(raw, -TabletopDial.overrun), Double(count - 1) + TabletopDial.overrun)
        }

        /// The title the ring is nearest: committed as it changes, settled
        /// on at release.
        public var nearest: Int {
            guard count > 0 else { return 0 }
            return min(max(Int(position.rounded()), 0), count - 1)
        }
    }
}
