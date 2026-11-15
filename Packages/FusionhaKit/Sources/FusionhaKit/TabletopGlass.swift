import Foundation

/// The hologram's "At the fold" style (2026-11-15): the upright half is
/// black, and black glass mirrors what is bright on the table half at its
/// true depth behind it, so the scene draws no reflection of its own. The
/// focused title stands on the glass itself: in the upright screen's plane
/// (depth 0), tipped back with it, its foot `footHeight` up the screen from
/// the hinge, at `slabScale`, upright (no lean). Nothing of it is drawn on
/// the table half. Its sway, bob and a finger's spin turn it about its own
/// upright axis; a turn brings one edge out in front of the glass, which
/// the eye sees lower, so the foot rises just enough that nothing of the
/// card or its slices is seen below `foldClearance`. The waiting titles
/// stand where they do in "Across the fold".
public enum TabletopGlass {
    /// The centre of the slab's foot: this far up the standing half from
    /// the hinge, facing straight out.
    public static let footHeight = 22.0
    /// Nothing of the slab is seen lower than this up the standing half.
    public static let foldClearance = 20.0
    public static let slabScale = 0.96

    /// The card `offset` places from the focus in this style, for an eye
    /// `seat` degrees up and a `hinge` angle in degrees, or nil out of
    /// reach. Between a waiting place and the glass it moves, grows and
    /// tips back with its focus.
    public static func card(offset: Double, seat: Double, hinge: Double = TabletopProjection.restingHinge,
                            sway: Double = TabletopScene.restingSway, bob: Double = 0) -> TabletopScene.Card? {
        let away = abs(offset)
        guard away < TabletopScene.reach else { return nil }
        let f = TabletopScene.smoothstep(1 - away), angle = offset * TabletopScene.spread
        let k = TabletopScene.markerScale + (slabScale - TabletopScene.markerScale) * f
        let wait = TabletopScene.waiting(offset)
        let width = TabletopScene.posterWidth * k, height = TabletopScene.posterHeight * k
        let yaw = angle * 0.5 * (1 - f) + sway * f
        let phi = TabletopProjection.phi(hingeDegrees: hinge)
        let foot = f > 0 ? footRise(yaw: yaw, width: width, height: height, seat: seat, hinge: hinge, bob: bob) : 0
        return TabletopScene.Card(
            offset: offset,
            focus: f,
            width: width,
            height: height,
            yaw: yaw,
            centerX: wait.x * (1 - f),
            centerZ: wait.z * (1 - f) - foot * sin(phi) * f,
            lift: foot * cos(phi) * f,
            lean: 0,
            opacity: min(1, max(0, (TabletopScene.reach - away) / 0.5)) * (0.6 + 0.4 * f),
            tilt: phi * f)
    }

    /// How far up the standing half the slab's foot stands at turn `yaw`:
    /// `footHeight` (plus the bob), or just high enough that its lowest
    /// corner, slices included, is seen `foldClearance` up the half.
    public static func footRise(yaw: Double, width: Double, height: Double,
                                seat: Double, hinge: Double, bob: Double = 0) -> Double {
        let base = footHeight + bob
        func clears(_ s: Double) -> Bool {
            lowest(foot: s, yaw: yaw, width: width, height: height, seat: seat, hinge: hinge) >= foldClearance
        }
        guard !clears(base) else { return base }
        var low = base, high = base + 40
        while !clears(high), high < base + 4000 { high += (high - low) * 2 }
        for _ in 0..<32 {
            let mid = (low + high) / 2
            if clears(mid) { high = mid } else { low = mid }
        }
        return high
    }

    /// How far up the standing half the lowest corner of the slab (its
    /// slices too) is seen, with its foot `foot` up the half.
    public static func lowest(foot: Double, yaw: Double, width: Double, height: Double,
                              seat: Double, hinge: Double) -> Double {
        let phi = TabletopProjection.phi(hingeDegrees: hinge), eye = TabletopProjection.eye(elevation: seat)
        let card = TabletopScene.Card(offset: 0, focus: 1, width: width, height: height, yaw: yaw, centerX: 0,
                                      centerZ: -foot * sin(phi), lift: foot * cos(phi), lean: 0, opacity: 1, tilt: phi)
        var low = Double.infinity
        for depth in 0...TabletopScene.sliceCount {
            for v in card.corners(depth: -Double(depth) * TabletopScene.sliceGap) {
                low = min(low, TabletopProjection.onScreen(v, phi: phi, eye: eye).y)
            }
        }
        return low
    }

    /// The card for a style `amount` of the way from "Across the fold" (0)
    /// to "At the fold" (1): the change of style moves it between the two.
    public static func card(offset: Double, seat: Double, hinge: Double, sway: Double, bob: Double,
                            amount: Double) -> TabletopScene.Card? {
        let across = amount < 1 ? TabletopScene.card(offset: offset, seat: seat, hinge: hinge, sway: sway, bob: bob) : nil
        let glass = amount > 0 ? card(offset: offset, seat: seat, hinge: hinge, sway: sway, bob: bob) : nil
        guard let across else { return glass }
        guard let glass else { return across }
        return .mix(across, glass, amount)
    }
}

extension TabletopScene.Card {
    /// `a` to `b`, `t` of the way (the change of style).
    public static func mix(_ a: Self, _ b: Self, _ t: Double) -> Self {
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return Self(offset: m(a.offset, b.offset), focus: m(a.focus, b.focus), width: m(a.width, b.width),
                    height: m(a.height, b.height), yaw: m(a.yaw, b.yaw), centerX: m(a.centerX, b.centerX),
                    centerZ: m(a.centerZ, b.centerZ), lift: m(a.lift, b.lift), lean: m(a.lean, b.lean),
                    opacity: m(a.opacity, b.opacity), tilt: m(a.tilt, b.tilt))
    }
}
