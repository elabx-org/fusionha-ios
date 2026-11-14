import Foundation

/// The tabletop hologram's layout (the approved mock's `drawHolo`): titles
/// wait on a ring as small markers and the focused one stands over the
/// emitter as a slab of glass. Pure numbers in the rig's coordinates
/// (`TabletopVec`); the app projects them with `TabletopProjection`.
public enum TabletopScene {
    /// The ring's centre: this far in FRONT of the hinge, on the bottom half.
    public static let ringZ = 110.0
    public static let emitterRadius = 120.0
    public static let trackRadius = 172.0
    /// How high the focused slab floats over the ring.
    public static let lift = 22.0
    /// The angle between neighbours on the ring.
    public static let spread = 58 * Double.pi / 180
    public static let posterWidth = 230.0
    public static let posterHeight = 345.0
    public static let sliceCount = 4
    public static let sliceGap = 8.5
    /// Cards further than this from the focus are not drawn.
    public static let reach = 2.6
    /// The slab's resting turn (radians), so its thickness shows while still.
    public static let restingSway = 0.17
    /// How far behind the hinge the floor is drawn on the top half.
    public static let floorDepth = 440.0
    /// The square the beam and the halo are drawn in before projection.
    public static let lightSide = 200.0

    /// 0 below 0, 1 above 1, eased between (the mock's `ss`).
    public static func smoothstep(_ t: Double) -> Double {
        t <= 0 ? 0 : t >= 1 ? 1 : t * t * (3 - 2 * t)
    }

    /// One title in the scene, `offset` places from the focus (fractional
    /// while the ring turns).
    public struct Card: Equatable, Sendable {
        public let offset: Double
        /// 1 focused (the slab), 0 a marker on the ring.
        public let focus: Double
        public let width: Double
        public let height: Double
        /// The turn about the upright axis.
        public let yaw: Double
        /// The foot's centre on the floor.
        public let centerX: Double
        public let centerZ: Double
        public let lift: Double
        public let opacity: Double

        /// How much of the focused title's light a marker takes (0 the slab).
        public var ghost: Double { 1 - focus }
        public var sliceOpacity: Double { opacity * focus }
        public var reflectionOpacity: Double { opacity * (0.22 + 0.6 * focus) }
        public var beamOpacity: Double { focus * 0.95 }
        public var haloOpacity: Double { focus * 0.85 }
        /// Slices are drawn only for a card that is nearly the slab.
        public var hasSlices: Bool { focus >= 0.05 }

        /// The poster's corners [top-left, top-right, bottom-right,
        /// bottom-left], `depth` along its facing (negative = behind it).
        /// `mirrored` is its image under the floor.
        public func corners(depth: Double = 0, mirrored: Bool = false) -> [TabletopVec] {
            let sn = sin(yaw), cs = cos(yaw), m = mirrored ? -1.0 : 1.0
            let x0 = centerX - cs * width / 2 + sn * depth, z0 = centerZ + sn * width / 2 + cs * depth
            let x1 = centerX + cs * width / 2 + sn * depth, z1 = centerZ - sn * width / 2 + cs * depth
            let top = m * (lift + height), bottom = m * lift
            return [TabletopVec(x0, -top, z0), TabletopVec(x1, -top, z1),
                    TabletopVec(x1, -bottom, z1), TabletopVec(x0, -bottom, z0)]
        }

        /// The `index`-th glass slice behind the poster (0 the nearest);
        /// `thickness` 0 lays them all on the poster (the lift grows it).
        public func slice(_ index: Int, thickness: Double = 1) -> [TabletopVec] {
            corners(depth: -Double(index + 1) * TabletopScene.sliceGap * focus * thickness)
        }

        /// The print-in's scan bar across the slab, `reveal` of the way up
        /// it (0 its foot, 1 its top), `half` tall either side of the line.
        public func scanBar(reveal: Double, half: Double) -> [TabletopVec] {
            let sn = sin(yaw), cs = cos(yaw), y = lift + height * reveal
            let hx = cs * width / 2, hz = -sn * width / 2
            return [TabletopVec(centerX - hx, -y - half, centerZ - hz + 2), TabletopVec(centerX + hx, -y - half, centerZ + hz + 2),
                    TabletopVec(centerX + hx, -y + half, centerZ + hz + 2), TabletopVec(centerX - hx, -y + half, centerZ - hz + 2)]
        }

        /// The beam: from the emitter's rim up to the slab's lower fifth.
        public var beam: [TabletopVec] {
            let half = width * 0.46, top = lift + height * 0.2, rim = TabletopScene.emitterRadius * 0.9
            return [TabletopVec(centerX - half, -top, centerZ), TabletopVec(centerX + half, -top, centerZ),
                    TabletopVec(rim, 0, TabletopScene.ringZ), TabletopVec(-rim, 0, TabletopScene.ringZ)]
        }

        /// The soft light behind the slab.
        public var halo: [TabletopVec] {
            let top = -(lift + height + 90), z = centerZ - 46
            return [TabletopVec(centerX - 300, top, z), TabletopVec(centerX + 300, top, z),
                    TabletopVec(centerX + 300, 20, z), TabletopVec(centerX - 300, 20, z)]
        }
    }

    /// The card `offset` places from the focus, or nil when it is out of
    /// reach. `sway` turns the slab and `bob` raises it (both only as far as
    /// the card is focused).
    public static func card(offset: Double, sway: Double = restingSway, bob: Double = 0) -> Card? {
        let away = abs(offset)
        guard away < reach else { return nil }
        let f = smoothstep(1 - away), angle = offset * spread, k = 0.34 + 0.62 * f
        return Card(
            offset: offset,
            focus: f,
            width: posterWidth * k,
            height: posterHeight * k,
            yaw: angle * 0.5 * (1 - f) + sway * f,
            centerX: trackRadius * sin(angle) * (1 - f),
            centerZ: (ringZ - trackRadius * cos(angle)) * (1 - f) + ringZ * f,
            lift: (lift + bob) * f,
            opacity: min(1, max(0, (reach - away) / 0.5)) * (0.6 + 0.4 * f))
    }

    /// The floor behind the hinge, as wide as the display, `floorDepth` deep.
    public static var floorBehind: [TabletopVec] {
        let half = TabletopProjection.designWidth / 2
        return [TabletopVec(-half, 0, -floorDepth), TabletopVec(half, 0, -floorDepth),
                TabletopVec(half, 0, 0), TabletopVec(-half, 0, 0)]
    }
}
