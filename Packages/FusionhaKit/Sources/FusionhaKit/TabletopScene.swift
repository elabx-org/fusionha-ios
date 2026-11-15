import Foundation

/// The tabletop hologram's layout (the approved mock's `drawHolo`, with the
/// seat mock's changes, "tabletop-seat", 2026-11-15): the focused title
/// stands over the emitter as a slab of glass across the hinge, and the
/// others wait on the floor behind the hinge as small markers. Pure numbers
/// in the rig's coordinates (`TabletopVec`); the app projects them with
/// `TabletopProjection`.
///
/// A card across the hinge is the illusion: its foot is drawn on the table,
/// its head on the standing half, from the viewer's own eye (the seat,
/// `TabletopProjection.eye(elevation:)`). Seen from higher than 34° an
/// upright card looks squat, so it leans back toward the eye like a propped
/// picture frame (`lean(seat:)`). Only the focused card crosses; the waiting
/// titles stand behind the hinge, so a seat a little off shows on one
/// object, not five. The numbers below are the mock's, each one named so
/// it is easy to change.
public enum TabletopScene {
    /// The ring's centre: this far in FRONT of the hinge, on the bottom
    /// half. The slab stands over it.
    public static let ringZ = 130.0
    /// The emitter's rim. With the dial round it (`TabletopDial`), nothing
    /// of the ring comes within 20 pt of the hinge.
    public static let emitterRadius = 100.0
    /// The round track the waiting titles stood on before the hinge fix; it
    /// is no longer drawn (`V2HologramRing`).
    public static let trackRadius = 172.0
    /// How high the slab's foot floats over the floor.
    public static let slabLift = 22.0
    /// A title's size against the 230 x 345 card: a marker's, and the slab's.
    public static let markerScale = 0.34
    public static let slabScale = 0.96
    /// The slab leans back by `leanRate` degrees a degree of seat above
    /// `leanFrom` (none at or below it).
    public static let leanFrom = 34.0
    public static let leanRate = 0.9
    /// The waiting titles stand behind the hinge: across, `waitStep` a place
    /// for the nearest one either side, then `waitStepFar` a place; back,
    /// `waitDepth` plus `waitDepthStep` a place (held at `reach`).
    public static let waitStep = 196.0
    public static let waitStepFar = 104.0
    public static let waitDepth = 52.0
    public static let waitDepthStep = 44.0
    /// The idle loop's reach (`TabletopLift.sway`, `.bob`).
    public static let swayReach = 0.24
    public static let bobReach = 5.0
    /// The angle between neighbours on the ring (the waiting titles' turn).
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
    /// How far the floor behind the hinge runs on past each side of the
    /// display: three of the grid's twelve columns. As wide as the display,
    /// its sides closed in toward the back (perspective) and read on the
    /// wall as two slanted edges; this wide they stay off the display at
    /// every hinge angle (at 92° its back corners are 412 pt out).
    public static let floorOverhang = 3 * TabletopProjection.designWidth / 12
    /// The floor behind the hinge's width: the display and the overhang either side.
    public static var floorBehindWidth: Double { TabletopProjection.designWidth + 2 * floorOverhang }
    /// The square the beam and the halo are drawn in before projection.
    public static let lightSide = 200.0
    /// How far up its mirror image a title's reflection runs (0 its feet,
    /// 1 its head), so no image reaches the page dots and the controls.
    public static let reflectionReach = 0.31
    /// The beam's piece on the table, against its strength on the wall.
    public static let tableBeam = 1.0

    /// How far the slab leans back (radians) for a seat in degrees.
    public static func lean(seat: Double) -> Double {
        max(0, TabletopProjection.heldSeat(seat) - leanFrom) * leanRate * Double.pi / 180
    }

    /// 0 below 0, 1 above 1, eased between (the mock's `ss`).
    public static func smoothstep(_ t: Double) -> Double {
        t <= 0 ? 0 : t >= 1 ? 1 : t * t * (3 - 2 * t)
    }

    /// One title in the scene, `offset` places from the focus (fractional
    /// while the ring turns).
    public struct Card: Equatable, Sendable {
        public let offset: Double
        /// 1 focused (the slab), 0 a marker behind the hinge.
        public let focus: Double
        public let width: Double
        public let height: Double
        /// The turn about the upright axis.
        public let yaw: Double
        /// The foot's centre on the floor.
        public let centerX: Double
        public let centerZ: Double
        public let lift: Double
        /// How far it leans back toward the eye (radians, only as far as the
        /// card is focused): its foot stays, its head comes back.
        public let lean: Double
        public let opacity: Double

        /// How much of the focused title's light a marker takes (0 the slab).
        public var ghost: Double { 1 - focus }
        public var sliceOpacity: Double { opacity * focus }
        public var reflectionOpacity: Double { opacity * (0.22 + 0.6 * focus) }
        public var beamOpacity: Double { focus * 0.95 }
        public var haloOpacity: Double { focus * 0.85 }
        public var shadeOpacity: Double { focus }
        /// Slices are drawn only for a card that is nearly the slab.
        public var hasSlices: Bool { focus >= 0.05 }

        /// How high its head is over its foot, and how far back from it
        /// (toward the hinge), leaned.
        public var rise: Double { height * cos(lean) }
        public var setBack: Double { height * sin(lean) }

        /// The poster's corners [top-left, top-right, bottom-right,
        /// bottom-left], `depth` along its facing (negative = behind it).
        /// `mirrored` is its image under the floor.
        public func corners(depth: Double = 0, mirrored: Bool = false) -> [TabletopVec] {
            let sn = sin(yaw), cs = cos(yaw), m = mirrored ? -1.0 : 1.0
            let x0 = centerX - cs * width / 2 + sn * depth, z0 = centerZ + sn * width / 2 + cs * depth
            let x1 = centerX + cs * width / 2 + sn * depth, z1 = centerZ - sn * width / 2 + cs * depth
            let top = m * (lift + rise), bottom = m * lift, back = setBack
            return [TabletopVec(x0, -top, z0 - back), TabletopVec(x1, -top, z1 - back),
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
            let sn = sin(yaw), cs = cos(yaw), y = lift + rise * reveal, z = centerZ + 2 - setBack * reveal
            let hx = cs * width / 2, hz = -sn * width / 2
            return [TabletopVec(centerX - hx, -y - half, z - hz), TabletopVec(centerX + hx, -y - half, z + hz),
                    TabletopVec(centerX + hx, -y + half, z + hz), TabletopVec(centerX - hx, -y + half, z - hz)]
        }

        /// The beam: from the emitter's rim up to the slab's lower fifth.
        public var beam: [TabletopVec] {
            let half = width * 0.46, top = lift + rise * 0.2, z = centerZ - setBack * 0.2
            let rim = TabletopScene.emitterRadius * 0.9
            return [TabletopVec(centerX - half, -top, z), TabletopVec(centerX + half, -top, z),
                    TabletopVec(rim, 0, TabletopScene.ringZ), TabletopVec(-rim, 0, TabletopScene.ringZ)]
        }

        /// The upright plane the halo and the shade are drawn on: behind
        /// the slab's head, however far it leans.
        private var backZ: Double { centerZ - 46 - setBack }

        /// The soft light behind the slab.
        public var halo: [TabletopVec] {
            let top = -(lift + rise + 90), z = backZ
            return [TabletopVec(centerX - 300, top, z), TabletopVec(centerX + 300, top, z),
                    TabletopVec(centerX + 300, 20, z), TabletopVec(centerX - 300, 20, z)]
        }

        /// The pool of shadow behind the slab, on the halo's plane and wider
        /// and taller than it: it keeps the slab's edge against a room that
        /// has taken the poster's own colours.
        public var shade: [TabletopVec] {
            let top = -(lift + rise + 210), z = backZ
            return [TabletopVec(centerX - 470, top, z), TabletopVec(centerX + 470, top, z),
                    TabletopVec(centerX + 470, 150, z), TabletopVec(centerX - 470, 150, z)]
        }
    }

    /// Where a waiting title stands, `offset` places from the focus: behind
    /// the hinge, x across and z (negative) back.
    public static func waiting(_ offset: Double) -> (x: Double, z: Double) {
        let away = abs(offset), side: Double = offset < 0 ? -1 : 1
        let x = away <= 1 ? offset * waitStep : side * (waitStep + waitStepFar * (away - 1))
        return (x, -(waitDepth + waitDepthStep * min(away, reach)))
    }

    /// The card `offset` places from the focus, or nil when it is out of
    /// reach, for an eye `seat` degrees up. `sway` turns the slab and `bob`
    /// raises it (both, and the lean, only as far as the card is focused).
    /// Between a waiting place and the slab's, a card moves and grows with
    /// its focus.
    public static func card(offset: Double, seat: Double, sway: Double = restingSway, bob: Double = 0) -> Card? {
        let away = abs(offset)
        guard away < reach else { return nil }
        let f = smoothstep(1 - away), angle = offset * spread
        let k = markerScale + (slabScale - markerScale) * f
        let wait = waiting(offset)
        return Card(
            offset: offset,
            focus: f,
            width: posterWidth * k,
            height: posterHeight * k,
            yaw: angle * 0.5 * (1 - f) + sway * f,
            centerX: wait.x * (1 - f),
            centerZ: wait.z * (1 - f) + ringZ * f,
            lift: (slabLift + bob) * f,
            lean: lean(seat: seat) * f,
            opacity: min(1, max(0, (reach - away) / 0.5)) * (0.6 + 0.4 * f))
    }

    /// The floor behind the hinge, `floorBehindWidth` wide and `floorDepth` deep.
    public static var floorBehind: [TabletopVec] {
        let half = floorBehindWidth / 2
        return [TabletopVec(-half, 0, -floorDepth), TabletopVec(half, 0, -floorDepth),
                TabletopVec(half, 0, 0), TabletopVec(-half, 0, 0)]
    }
}
