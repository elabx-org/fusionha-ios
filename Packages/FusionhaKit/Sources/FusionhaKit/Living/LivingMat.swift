import Foundation

/// A 2D affine matrix as in canvas `setTransform(a, b, c, d, e, f)`:
/// x' = a·x + c·y + e, y' = b·x + d·y + f (web `fusion-dance.ts` affine maths).
/// Same layout as `CGAffineTransform(a:b:c:d:tx:ty:)`.
public struct LivingMat: Equatable, Sendable {
    public var a, b, c, d, e, f: Double

    public init(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ e: Double, _ f: Double) {
        (self.a, self.b, self.c, self.d, self.e, self.f) = (a, b, c, d, e, f)
    }

    public static let identity = LivingMat(1, 0, 0, 1, 0, 0)

    /// `self · n`: `n` applies first.
    public func mul(_ n: LivingMat) -> LivingMat {
        LivingMat(a * n.a + c * n.b, b * n.a + d * n.b,
                  a * n.c + c * n.d, b * n.c + d * n.d,
                  a * n.e + c * n.f + e, b * n.e + d * n.f + f)
    }

    public static func translate(_ x: Double, _ y: Double) -> LivingMat { LivingMat(1, 0, 0, 1, x, y) }
    public static func scale(_ x: Double, _ y: Double? = nil) -> LivingMat { LivingMat(x, 0, 0, y ?? x, 0, 0) }

    public static func rotate(_ deg: Double) -> LivingMat {
        let r = deg * Double.pi / 180
        return LivingMat(cos(r), sin(r), -sin(r), cos(r), 0, 0)
    }

    /// `m` about the pivot `p`.
    public static func about(_ p: LivingPt, _ m: LivingMat) -> LivingMat {
        translate(p.x, p.y).mul(m.mul(translate(-p.x, -p.y)))
    }

    public func apply(_ q: LivingPt) -> LivingPt {
        LivingPt(a * q.x + c * q.y + e, b * q.x + d * q.y + f)
    }
}
