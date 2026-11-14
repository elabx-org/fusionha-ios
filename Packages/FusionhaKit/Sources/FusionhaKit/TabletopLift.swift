import Foundation

/// The tabletop hologram's motion (the approved mock's `holo` action,
/// Replay and idle loop): the lift between the flat carousel and the scene,
/// the print-in when the scene first appears, and the slab's idle sway and
/// bob. Pure numbers; the app draws them.
public enum TabletopLift {
    /// The lift runs this long, linear in time; its stages ease inside it.
    public static let duration = 1.3
    /// The print-in runs this long, eased out (`easeOut`).
    public static let printDuration = 2.2

    /// 0 below 0, 1 above 1, a cubic ease-out between (the mock's `ease`).
    public static func easeOut(_ t: Double) -> Double {
        t < 0 ? 0 : t > 1 ? 1 : 1 - pow(1 - t, 3)
    }

    public static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// Corner by corner from quad `a` to quad `b`.
    public static func mix(_ a: [TabletopPoint], _ b: [TabletopPoint], _ t: Double) -> [TabletopPoint] {
        zip(a, b).map { TabletopPoint(mix($0.x, $1.x, t), mix($0.y, $1.y, t)) }
    }

    /// The lift at `progress` (0 the flat carousel, 1 the hologram): how far
    /// each stage has come.
    public struct Stages: Equatable, Sendable {
        public let progress: Double
        /// The floor and the ring draw in from the hinge (0…0.42).
        public let floor: Double
        /// The posters' corners go from the carousel to the scene (0.1…0.84).
        public let corners: Double
        /// The slab's thickness, its turn and bob, the beam and the halo (0.58…1).
        public let depth: Double
        /// The pieces seen against the bottom half (0.7…1).
        public let twins: Double
        /// The reflections on the table (0.5…1).
        public let reflection: Double

        public init(_ progress: Double) {
            let p = min(max(progress, 0), 1)
            self.progress = p
            floor = TabletopScene.smoothstep(p / 0.42)
            corners = TabletopScene.smoothstep((p - 0.1) / 0.74)
            depth = TabletopScene.smoothstep((p - 0.58) / 0.42)
            twins = TabletopScene.smoothstep((p - 0.7) / 0.3)
            reflection = TabletopScene.smoothstep((p - 0.5) / 0.5)
        }

        /// The hologram, standing.
        public static let done = Stages(1)

        /// Until the corners are half way the posters keep the carousel's
        /// order (the focused one in front); after, the scene's.
        public var keepsCarouselOrder: Bool { corners < 0.5 }
    }

    /// The print-in at `rise` (0 nothing, 1 printed).
    public struct Print: Equatable, Sendable {
        public let rise: Double
        /// The ring and the track come on first.
        public let ring: Double
        public let beam: Double
        /// How much of the slab is printed, from its foot up.
        public let slab: Double

        public init(_ rise: Double) {
            self.rise = rise
            ring = TabletopLift.easeOut(rise / 0.25)
            beam = TabletopLift.easeOut((rise - 0.12) / 0.3)
            slab = TabletopLift.easeOut((rise - 0.28) / 0.72)
        }

        public static let done = Print(1)

        /// How much of a card shows, from its foot up: the markers come one
        /// after another outward from the focus (`away` places from it), the
        /// slab last (`focus` 1).
        public func reveal(away: Double, focus: Double) -> Double {
            let marker = TabletopLift.easeOut((rise - 0.2 - away * 0.12) / 0.5)
            let shown = marker * (1 - focus) + slab * focus
            return shown >= 0.999 ? 1 : shown
        }
    }

    /// The flat carousel the lift starts from and ends at: its centre in the
    /// page, the focused poster's size, the distance between neighbours and
    /// the scale and opacity at 0, 1, 2… places from the centre (linear
    /// between, the last holding).
    public struct Flat: Equatable, Sendable {
        public let centerX: Double
        public let centerY: Double
        public let width: Double
        public let height: Double
        public let step: Double
        public let scales: [Double]
        public let opacities: [Double]

        public init(centerX: Double, centerY: Double, width: Double, height: Double, step: Double,
                    scales: [Double], opacities: [Double]) {
            self.centerX = centerX
            self.centerY = centerY
            self.width = width
            self.height = height
            self.step = step
            self.scales = scales
            self.opacities = opacities
        }

        public func scale(_ offset: Double) -> Double { Self.at(scales, abs(offset)) }
        public func opacity(_ offset: Double) -> Double { Self.at(opacities, abs(offset)) }

        /// The poster `offset` places from the focus: [top-left, top-right,
        /// bottom-right, bottom-left] in the page.
        public func quad(_ offset: Double) -> [TabletopPoint] {
            let k = scale(offset), x = centerX + offset * step
            let w = width * k / 2, h = height * k / 2
            return [TabletopPoint(x - w, centerY - h), TabletopPoint(x + w, centerY - h),
                    TabletopPoint(x + w, centerY + h), TabletopPoint(x - w, centerY + h)]
        }

        private static func at(_ stops: [Double], _ x: Double) -> Double {
            guard stops.count > 1 else { return stops.first ?? 0 }
            let x = min(max(x, 0), Double(stops.count - 1))
            let i = min(Int(x), stops.count - 2)
            return stops[i] + (stops[i + 1] - stops[i]) * (x - Double(i))
        }
    }

    // MARK: Idle

    /// The slab's turn (radians) `seconds` into the idle loop: ±0.24 at 0.75 rad/s.
    public static func sway(at seconds: Double) -> Double { sin(seconds * 0.75) * 0.24 }
    /// The slab's rise and fall (points): ±5 at 1.15 rad/s.
    public static func bob(at seconds: Double) -> Double { sin(seconds * 1.15) * 5 }
    /// The dashed inner ring's turn (radians): once round every 26 s.
    public static func spin(at seconds: Double) -> Double {
        (seconds / 26).truncatingRemainder(dividingBy: 1) * 2 * Double.pi
    }
}
