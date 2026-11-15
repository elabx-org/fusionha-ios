import Foundation

/// The tabletop hologram's layout (the approved mock's `drawHolo`, with the
/// hinge fix's `FL` branches, mock "tabletop-float", 2026-11-15): the
/// focused title floats over the emitter as a slab of glass and the others
/// wait on the floor behind the hinge as small markers. Pure numbers in the
/// rig's coordinates (`TabletopVec`); the app projects them with
/// `TabletopProjection`.
///
/// Nothing solid crosses the hinge (owner, on the device, 2026-11-15): a
/// thing drawn on both halves from one fixed eye only lines up from that
/// eye, and from where a person really sits it creases at the hinge. So
/// the slab floats high enough to be seen wholly on the standing half, the
/// waiting titles stand behind the hinge, and only the floor's own things
/// (the ring, the grid, the contact shadow) and soft light are on the table.
/// The numbers below are the mock's, each one named so it is easy to change.
public enum TabletopScene {
    /// The ring's centre: this far in FRONT of the hinge, on the bottom
    /// half. The slab floats over it.
    public static let ringZ = 110.0
    public static let emitterRadius = 120.0
    /// The round track the waiting titles stood on before the hinge fix; it
    /// is no longer drawn (`V2HologramRing`).
    public static let trackRadius = 172.0
    /// How high the slab's foot floats over the floor (the mock's 22 before
    /// the hinge fix): seen 26.8–31.4 pt over the hinge at the bob's lowest and
    /// the sway's widest, 36–41 at rest, across the hinge range.
    public static let slabLift = 125.0
    /// A title's size against the 230 x 345 card: a marker's, and the
    /// slab's (0.96 before the hinge fix).
    public static let markerScale = 0.34
    public static let slabScale = 0.86
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
    /// How far up its mirror image a waiting title's reflection runs (0 its
    /// feet, 1 its head), so no image reaches the controls on the table.
    /// The slab has none (`Card.reflectionOpacity`).
    public static let reflectionReach = 0.31
    /// The contact shadow under the slab: its width against the slab's,
    /// its height against its width, and how it breathes with the bob.
    public static let contactWidth = 1.12
    public static let contactAspect = 0.34
    /// The beam's piece on the table, against its strength on the wall.
    public static let tableBeam = 0.55

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
        /// The idle bob in it (points, only as far as the card is focused).
        public let bob: Double
        public let opacity: Double

        /// How much of the focused title's light a marker takes (0 the slab).
        public var ghost: Double { 1 - focus }
        public var sliceOpacity: Double { opacity * focus }
        /// The slab has no reflection: a floating card's would land under
        /// the title and Open. The waiting titles keep theirs.
        public var reflectionOpacity: Double { opacity * (0.22 + 0.6 * focus) * (1 - focus) }
        public var beamOpacity: Double { focus * 0.95 }
        public var haloOpacity: Double { focus * 0.85 }
        public var shadeOpacity: Double { focus }
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

        /// The contact shadow on the table: an ellipse centred under the
        /// ring's centre, a little smaller as the slab bobs up.
        public var contact: Contact {
            let across = width * (TabletopScene.contactWidth - bob * 0.012)
            return Contact(centerX: centerX, centerZ: TabletopScene.ringZ, width: across,
                           depth: across * TabletopScene.contactAspect)
        }

        public var contactOpacity: Double { focus * (0.9 - bob * 0.02) }

        /// The soft light behind the slab.
        public var halo: [TabletopVec] {
            let top = -(lift + height + 90), z = centerZ - 46
            return [TabletopVec(centerX - 300, top, z), TabletopVec(centerX + 300, top, z),
                    TabletopVec(centerX + 300, 20, z), TabletopVec(centerX - 300, 20, z)]
        }

        /// The pool of shadow behind the slab, on the halo's plane and wider
        /// and taller than it: it keeps the slab's edge against a room that
        /// has taken the poster's own colours.
        public var shade: [TabletopVec] {
            let top = -(lift + height + 210), z = centerZ - 46
            return [TabletopVec(centerX - 470, top, z), TabletopVec(centerX + 470, top, z),
                    TabletopVec(centerX + 470, 150, z), TabletopVec(centerX - 470, 150, z)]
        }
    }

    /// The contact shadow, in the floor's plane (`centerZ` in front of the
    /// hinge, `depth` its extent toward the viewer).
    public struct Contact: Equatable, Sendable {
        public let centerX: Double
        public let centerZ: Double
        public let width: Double
        public let depth: Double
    }

    /// Where a waiting title stands, `offset` places from the focus: behind
    /// the hinge, x across and z (negative) back.
    public static func waiting(_ offset: Double) -> (x: Double, z: Double) {
        let away = abs(offset), side: Double = offset < 0 ? -1 : 1
        let x = away <= 1 ? offset * waitStep : side * (waitStep + waitStepFar * (away - 1))
        return (x, -(waitDepth + waitDepthStep * min(away, reach)))
    }

    /// The card `offset` places from the focus, or nil when it is out of
    /// reach. `sway` turns the slab and `bob` raises it (both only as far as
    /// the card is focused). Between a waiting place and the slab's, a card
    /// moves and grows with its focus.
    public static func card(offset: Double, sway: Double = restingSway, bob: Double = 0) -> Card? {
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
            bob: bob * f,
            opacity: min(1, max(0, (reach - away) / 0.5)) * (0.6 + 0.4 * f))
    }

    /// The floor behind the hinge, `floorBehindWidth` wide and `floorDepth` deep.
    public static var floorBehind: [TabletopVec] {
        let half = floorBehindWidth / 2
        return [TabletopVec(-half, 0, -floorDepth), TabletopVec(half, 0, -floorDepth),
                TabletopVec(half, 0, 0), TabletopVec(-half, 0, 0)]
    }
}
