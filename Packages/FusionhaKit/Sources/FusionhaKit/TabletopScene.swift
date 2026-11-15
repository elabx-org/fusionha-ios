import Foundation

/// The tabletop hologram's layout (the approved mock's `drawHolo`, with the
/// seat mock's and the stage bench's changes, "tabletop-seat" and
/// "tabletop-stage", 2026-11-15): the focused title floats as a slab of
/// glass in the beam over the emitter, and the others wait on the floor
/// behind the hinge as small markers. Pure numbers in the rig's coordinates
/// (`TabletopVec`); the app projects them with `TabletopProjection`.
///
/// Nothing with an edge crosses the fold. Seen with two eyes 6 cm apart, a
/// hard edge standing across it kinks in opposite directions for each eye,
/// whatever seat it is drawn for (build 1221: "a bent card over the
/// hinge"). What holds for both eyes is what lies flat on the table, what is
/// wholly on the upright half, and soft light. So the slab's foot floats
/// `slabZ` in front of the hinge, lifted just enough to be seen above the
/// fold from the seat (`slabLift(seat:)`), and only the beam crosses. Seen
/// from higher than 34° an upright card looks squat, so it leans back
/// toward the eye like a propped picture frame (`lean(seat:)`). The numbers
/// below are the mock's, each one named so it is easy to change.
public enum TabletopScene {
    /// The ring's centre: this far in FRONT of the hinge, on the bottom
    /// half. The beam rises from it to the slab's foot (`slabZ`).
    public static let ringZ = 130.0
    /// The emitter's rim. With the dial round it (`TabletopDial`), nothing
    /// of the ring comes within 20 pt of the hinge.
    public static let emitterRadius = 100.0
    /// The round track the waiting titles stood on before the hinge fix; it
    /// is no longer drawn (`V2HologramRing`).
    public static let trackRadius = 172.0
    /// The slab's foot: this far in front of the hinge (its nearest point,
    /// however it turns: `forward`).
    public static let slabZ = 40.0
    /// How far over the line from the eye through the hinge the slab's foot
    /// floats (`slabLift(seat:)`): the least that keeps every corner of the
    /// card and its slices 20 pt above the hinge on the standing half, at
    /// every seat, hinge angle, turn and bob (`TabletopSceneTests`). The
    /// tightest case is seat 68 at hinge 135, where a point of lift moves
    /// the foot only 0.43 pt up the screen; the bench's 34 left it 12 pt.
    public static let slabClearance = 52.0
    /// A title's size against the 230 x 345 card: a marker's, and the slab's
    /// (held lower at the far seats, `heldSlabScale(seat:)`).
    public static let markerScale = 0.34
    public static let slabScale = 0.86
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
    /// The idle loop's reach and rate (`TabletopLift.sway`, `.bob`).
    public static let swayReach = 0.62
    public static let swayRate = 0.5
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
    /// How far behind the hinge the floor is drawn on the top half: to the
    /// room's back wall (`TabletopRoom.depth`). It is as wide as the room,
    /// so its sides are the side walls' feet.
    public static let floorDepth = TabletopRoom.depth
    /// The floor behind the hinge's width: the display's.
    public static let floorBehindWidth = TabletopProjection.designWidth
    /// The square the beam and the halo are drawn in before projection.
    public static let lightSide = 200.0
    /// How far up its mirror image a title's reflection runs (0 its feet,
    /// 1 its head), so no image reaches the page dots and the controls.
    public static let reflectionReach = 0.31
    /// The beam's piece on the table, against its strength on the wall.
    public static let tableBeam = 1.0

    /// How high the slab's foot floats for a seat in degrees: on the line
    /// from the eye through the hinge (`slabZ`·tan seat), and
    /// `slabClearance` over it.
    public static func slabLift(seat: Double) -> Double {
        slabZ * tan(TabletopProjection.heldSeat(seat) * Double.pi / 180) + slabClearance
    }

    /// The slab's size for a seat in degrees: `slabScale` from 30° to 36°,
    /// smaller either side so its top (at rest, bob up) stays at most 400 pt
    /// up the standing half at every hinge angle (0.65 at 50°, 0.39 at 68°,
    /// 0.83 at 26°). Higher seats see a card further back drawn higher.
    public static func heldSlabScale(seat: Double) -> Double {
        let s = TabletopProjection.heldSeat(seat)
        return slabScale - 0.0148 * max(0, s - 36) - 0.008 * max(0, 30 - s)
    }

    /// How far the slab's nearest point comes forward of its centre at turn
    /// `yaw` (radians): its near edge by halfWidth·|sin yaw|, and past a
    /// quarter turn its glass slices (`sliceDepth` deep) by
    /// sliceDepth·(−cos yaw). The slab stands that much further back, so it
    /// never comes nearer than `slabZ` through the sway and a finger's spin.
    public static func forward(yaw: Double, halfWidth: Double, sliceDepth: Double) -> Double {
        halfWidth * abs(sin(yaw)) + sliceDepth * max(0, -cos(yaw))
    }

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

        /// The beam: from the emitter's rim up to the slab's foot, as wide
        /// as the slab there. The light crosses the fold, not the poster.
        public var beam: [TabletopVec] {
            let half = width * 0.5, top = lift + rise * 0.03, z = centerZ - setBack * 0.03
            let rim = TabletopScene.emitterRadius * 0.9
            return [TabletopVec(centerX - half, -top, z), TabletopVec(centerX + half, -top, z),
                    TabletopVec(rim, 0, TabletopScene.ringZ), TabletopVec(-rim, 0, TabletopScene.ringZ)]
        }

        /// The soft light behind the slab, on an upright plane behind its
        /// head, however far it leans.
        public var halo: [TabletopVec] {
            let top = -(lift + rise + 90), z = centerZ - 46 - setBack
            return [TabletopVec(centerX - 300, top, z), TabletopVec(centerX + 300, top, z),
                    TabletopVec(centerX + 300, 20, z), TabletopVec(centerX - 300, 20, z)]
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
    /// its focus. The slab stands back by what its turn brings it forward
    /// (`forward`), so its nearest point stays at `slabZ`.
    public static func card(offset: Double, seat: Double, sway: Double = restingSway, bob: Double = 0) -> Card? {
        let away = abs(offset)
        guard away < reach else { return nil }
        let f = smoothstep(1 - away), angle = offset * spread
        let k = markerScale + (heldSlabScale(seat: seat) - markerScale) * f
        let wait = waiting(offset)
        let width = posterWidth * k, yaw = angle * 0.5 * (1 - f) + sway * f
        let ahead = forward(yaw: yaw, halfWidth: width / 2, sliceDepth: Double(sliceCount) * sliceGap * f)
        return Card(
            offset: offset,
            focus: f,
            width: width,
            height: posterHeight * k,
            yaw: yaw,
            centerX: wait.x * (1 - f),
            centerZ: wait.z * (1 - f) + (slabZ - ahead) * f,
            lift: (slabLift(seat: seat) + bob) * f,
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
