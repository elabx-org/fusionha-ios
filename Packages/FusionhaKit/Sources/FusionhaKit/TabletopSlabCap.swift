import Foundation

/// The cap on the slab's size in "Across the fold" (2026-11-15): seen from a
/// high seat the full-size card's head is drawn far up the standing half
/// (about 632 pt at seat 68, hinge 92) and runs under the top bar. So the
/// slab is drawn just small enough that its head, the glass slices behind
/// it included, at its resting turn and the top of its bob, stays at most
/// `slabTopCap` up the standing half. Up to a seat of about 47 it fits at
/// every hinge angle and keeps `slabScale` (0.96); at the default seat 50 it
/// keeps it from a hinge of 95 open.
extension TabletopScene {
    /// How far up the standing half the slab's head may be drawn.
    public static let slabTopCap = 420.0

    /// The slab's size for an eye `seat` degrees up and a `hinge` angle in
    /// degrees: `slabScale`, or the largest size under it whose head stays
    /// `slabTopCap` up the standing half, never below `markerScale`.
    public static func cappedSlabScale(seat: Double, hinge: Double) -> Double {
        guard slabHead(scale: slabScale, seat: seat, hinge: hinge) > slabTopCap else { return slabScale }
        var low = markerScale, high = slabScale
        for _ in 0..<32 {
            let mid = (low + high) / 2
            if slabHead(scale: mid, seat: seat, hinge: hinge) > slabTopCap { high = mid } else { low = mid }
        }
        return low
    }

    /// How far up the standing half the head of a slab drawn at `scale` is
    /// seen (its highest corner, slices included), at rest and bob up.
    public static func slabHead(scale: Double, seat: Double, hinge: Double) -> Double {
        guard let card = card(offset: 0, seat: seat, sway: restingSway, bob: bobReach, scale: scale) else { return 0 }
        let eye = TabletopProjection.eye(elevation: seat), phi = TabletopProjection.phi(hingeDegrees: hinge)
        var head = -Double.infinity
        for depth in 0...sliceCount {
            for v in card.corners(depth: -Double(depth) * sliceGap)[0...1] {
                head = max(head, TabletopProjection.onScreen(v, phi: phi, eye: eye).y)
            }
        }
        return head
    }
}
