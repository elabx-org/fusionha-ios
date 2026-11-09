import Foundation

/// The book-pose gutter's numbers (owner 2026-11-09, option 3c of the hinge
/// mock): how deep the book reads at a hinge angle, and the shading's
/// sizes at that depth. Drawing only; layout never reads the angle.
public enum BookGutter {
    /// Gutter depth for a hinge angle in degrees: 0 opened almost flat
    /// (170° and up), 1 a deep book (95° and below), in between linear.
    /// `steps`: Reduce Motion, three levels instead of a continuous change.
    public static func depth(degrees: Double, steps: Bool = false) -> Double {
        let k = min(1, max(0, (170 - degrees) / 75))
        guard steps else { return k }
        return k < 0.25 ? 0 : (k < 0.75 ? 0.5 : 1)
    }

    /// Before the first hinge reading: a middling book.
    public static let initialDepth = 0.5

    /// The soft shadow's reach onto each page, in points.
    public static func shadowReach(_ depth: Double) -> Double { 50 + 55 * depth }
    /// The shadow's strength at the crease (multiplied out of the page).
    public static func shadowDepth(_ depth: Double) -> Double { 0.16 + 0.30 * depth }
    /// The crease's dark line strength.
    public static func crease(_ depth: Double) -> Double { 0.25 + 0.35 * depth }
    /// The binding thread's opacity.
    public static func thread(_ depth: Double) -> Double { 0.45 + 0.40 * depth }
    /// One stitch every this many points down the crease.
    public static let stitchPitch = 46.0

    /// The shadow's opacity at `distance` points from the crease; the right
    /// page sits a touch darker (light from the upper left).
    public static func shadow(at distance: Double, rightPage: Bool, depth: Double) -> Double {
        let reach = shadowReach(depth)
        let t = max(0, 1 - abs(distance) / reach)
        return shadowDepth(depth) * pow(t, 2.2) + (rightPage ? (0.02 + 0.06 * depth) * t : 0)
    }

    /// A page ground's luminance below which it is lifted, so the fold never
    /// reads as a black gap (a poster that is mostly black).
    public static let darkFloor = 0.08

    /// How much to brighten a ground of relative luminance `lum` (0…1).
    public static func lift(luminance lum: Double) -> Double {
        lum >= darkFloor ? 0 : 0.10 * (darkFloor - lum) / darkFloor
    }
}
