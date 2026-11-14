import Foundation

/// A point in the tabletop rig: origin at the hinge's centre, x to the right,
/// y DOWN, z toward the viewer. The floor is y = 0; the bottom half lies on it
/// at z >= 0. Lengths are points on a 669-pt-wide display.
public struct TabletopVec: Equatable, Sendable {
    public var x: Double, y: Double, z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// A point on one half of the display. On the top half: x from the centre
/// and the distance UP the half from the hinge. On the bottom half: x from
/// the centre and the distance from the hinge toward the viewer.
public struct TabletopPoint: Equatable, Sendable {
    public var x: Double, y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// The tabletop hologram's projection (the approved mock's `onScreen`,
/// `onFloor` and `quad`): where one fixed eye sees a point of the scene on
/// the standing top half and on the bottom half lying on the table. A thing
/// standing in front of the hinge is drawn on both halves from the same
/// eye, so its two pieces meet at the hinge.
public enum TabletopProjection {
    /// The display width every length is given for.
    public static let designWidth = 669.0
    /// The eye: 34° above the table, 2400 pt from the hinge.
    public static let eye: TabletopVec = {
        let alpha = 34 * Double.pi / 180, distance = 2400.0
        return TabletopVec(0, -distance * sin(alpha), distance * cos(alpha))
    }()

    /// The hinge angle the picture is drawn for when the device gives none.
    public static let restingHinge = 105.0
    /// The hinge angles the picture follows; outside them it holds the end.
    public static let hingeRange = 92.0...135.0

    /// A hinge reading in degrees (180 = flat open) held inside `hingeRange`;
    /// the resting angle when it is not a number.
    public static func heldHinge(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return restingHinge }
        return min(max(degrees, hingeRange.lowerBound), hingeRange.upperBound)
    }

    /// How far the top half leans back from upright, in radians, for a hinge
    /// angle in degrees.
    public static func phi(hingeDegrees: Double) -> Double {
        (heldHinge(hingeDegrees) - 90) * Double.pi / 180
    }

    /// Where the eye sees `p` on the top half, leaning back by `phi`.
    public static func onScreen(_ p: TabletopVec, phi: Double) -> TabletopPoint {
        let ny = -sin(phi), nz = cos(phi)
        let t = -(ny * eye.y + nz * eye.z) / (ny * (p.y - eye.y) + nz * (p.z - eye.z))
        let qx = eye.x + t * (p.x - eye.x)
        let qy = eye.y + t * (p.y - eye.y)
        let qz = eye.z + t * (p.z - eye.z)
        return TabletopPoint(qx, -qy * cos(phi) - qz * sin(phi))
    }

    /// Where the eye sees `p` on the table (the bottom half).
    public static func onFloor(_ p: TabletopVec) -> TabletopPoint {
        let t = eye.y / (eye.y - p.y)
        return TabletopPoint(eye.x + t * (p.x - eye.x), eye.z + t * (p.z - eye.z))
    }

    /// The eight coefficients [a, b, c, d, e, f, g, h] that map a
    /// `width` x `height` box (origin top-left) onto `quad` = [top-left,
    /// top-right, bottom-right, bottom-left]:
    /// u = (a·x + b·y + c) / (g·x + h·y + 1), v = (d·x + e·y + f) / (g·x + h·y + 1).
    public static func homography(width: Double, height: Double, quad: [TabletopPoint]) -> [Double] {
        precondition(quad.count == 4, "a quad has four corners")
        let source = [(0.0, 0.0), (width, 0.0), (width, height), (0.0, height)]
        var rows: [[Double]] = []
        var rhs: [Double] = []
        for (corner, target) in zip(source, quad) {
            let (x, y) = corner
            rows.append([x, y, 1, 0, 0, 0, -target.x * x, -target.x * y])
            rhs.append(target.x)
            rows.append([0, 0, 0, x, y, 1, -target.y * x, -target.y * y])
            rhs.append(target.y)
        }
        return solve(rows, rhs)
    }

    /// Whether `p` is inside the convex `quad` (corners in order, either way round).
    public static func contains(_ quad: [TabletopPoint], _ p: TabletopPoint) -> Bool {
        guard quad.count == 4 else { return false }
        var sign = 0.0
        for i in 0..<4 {
            let a = quad[i], b = quad[(i + 1) % 4]
            let cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
            if cross == 0 { continue }
            if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false }
        }
        return true
    }

    /// Gaussian elimination with partial pivoting (the mock's `solve`).
    private static func solve(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        var a = matrix, b = vector
        let n = b.count
        for i in 0..<n {
            var pivot = i
            for r in (i + 1)..<n where abs(a[r][i]) > abs(a[pivot][i]) { pivot = r }
            a.swapAt(i, pivot)
            b.swapAt(i, pivot)
            let p = a[i][i] == 0 ? 1e-9 : a[i][i]
            for r in (i + 1)..<n {
                let f = a[r][i] / p
                for c in i..<n { a[r][c] -= f * a[i][c] }
                b[r] -= f * b[i]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var s = b[i]
            for c in (i + 1)..<n { s -= a[i][c] * x[c] }
            x[i] = s / (a[i][i] == 0 ? 1e-9 : a[i][i])
        }
        return x
    }
}
