import SwiftUI
import UIKit

// The Living logo sign-in layout (components/login/living/*): the F cut into
// its three real blades on a dot field, tilting and bobbing, reacting to the
// password field like a lock's tumbler pins, and acting out what the app does
// between rests (the neutral moves: arrivals, fusion, quality, pride and the
// HD × 4K fusion; with `login_living_media`, TV, Anime and Movies × Series too).

// MARK: - Poses and keyframe animations (the web's WAAPI calls)

/// One element's animatable state. `light` is CSS `brightness()` minus 1,
/// `jam` the amber shudder tint, `rotY` a 3D turn.
struct LivingPose: Equatable {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var rot: Double = 0
    var scale: CGFloat = 1
    var rotY: Double = 0
    var light: Double = 0
    var jam: Double = 0
    var opacity: Double = 1

    static let identity = LivingPose()

    struct Fields: OptionSet {
        let rawValue: Int
        static let transform = Fields(rawValue: 1)
        static let filter = Fields(rawValue: 2)
        static let opacity = Fields(rawValue: 4)
        static let all: Fields = [.transform, .filter, .opacity]
    }

    static func mix(_ a: LivingPose, _ b: LivingPose, _ t: Double) -> LivingPose {
        let tf = CGFloat(t)
        func mf(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * tf }
        func md(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return LivingPose(dx: mf(a.dx, b.dx), dy: mf(a.dy, b.dy), rot: md(a.rot, b.rot), scale: mf(a.scale, b.scale),
                          rotY: md(a.rotY, b.rotY), light: md(a.light, b.light), jam: md(a.jam, b.jam),
                          opacity: md(a.opacity, b.opacity))
    }

    /// Copies the masked fields of `other` over this pose.
    func taking(_ fields: Fields, from other: LivingPose) -> LivingPose {
        var out = self
        if fields.contains(.transform) {
            out.dx = other.dx; out.dy = other.dy; out.rot = other.rot; out.scale = other.scale; out.rotY = other.rotY
        }
        if fields.contains(.filter) { out.light = other.light; out.jam = other.jam }
        if fields.contains(.opacity) { out.opacity = other.opacity }
        return out
    }

    /// `composite: 'add'`: the offset from identity added on top.
    func adding(_ other: LivingPose) -> LivingPose {
        var out = self
        out.dx += other.dx; out.dy += other.dy; out.rot += other.rot; out.rotY += other.rotY
        out.scale *= other.scale; out.light += other.light; out.jam += other.jam
        return out
    }
}

/// The web's easing strings.
enum LivingEase {
    static let ease = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.22, y: 1), endControlPoint: UnitPoint(x: 0.36, y: 1))
    static let snap = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.7, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1))
    static let turn = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.45, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1))
    static let glint = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.4, y: 0), endControlPoint: UnitPoint(x: 0.2, y: 1))
    static let dive = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.55, y: 0), endControlPoint: UnitPoint(x: 0.75, y: 0.2))
    static let rise = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.22, y: 1), endControlPoint: UnitPoint(x: 0.36, y: 1))
}

struct LivingAnim {
    var start: Double
    var duration: Double
    /// (offset 0–1, pose) keyframes.
    var frames: [(Double, LivingPose)]
    var curve: UnitCurve = .linear
    var fields: LivingPose.Fields = .all
    /// `fill: 'forwards'`: the last frame stays once it ends.
    var forwards = true
    var additive = false

    func value(at t: Double) -> LivingPose {
        let p = curve.value(at: min(1, max(0, (t - start) / max(duration, 0.001))))
        guard let first = frames.first else { return .identity }
        if p <= first.0 { return first.1 }
        for i in 1..<frames.count where p <= frames[i].0 {
            let a = frames[i - 1], b = frames[i]
            return LivingPose.mix(a.1, b.1, (p - a.0) / max(b.0 - a.0, 0.0001))
        }
        return frames[frames.count - 1].1
    }
}

/// A blade, the mark wrapper or the art wrapper: a held base pose plus the
/// animations running on it.
final class LivingElement {
    var base = LivingPose.identity
    var anims: [LivingAnim] = []

    func pose(at t: Double) -> LivingPose {
        var pose = base
        for a in anims where !a.additive && t >= a.start {
            pose = pose.taking(a.fields, from: a.value(at: t))
        }
        for a in anims where a.additive && t >= a.start && t < a.start + a.duration {
            pose = pose.adding(a.value(at: t))
        }
        return pose
    }

    /// Finished animations either hold their last frame (forwards) or vanish.
    func settle(at t: Double) {
        guard anims.contains(where: { t >= $0.start + $0.duration }) else { return }
        var keep: [LivingAnim] = []
        for a in anims {
            if t >= a.start + a.duration {
                if a.forwards && !a.additive { base = base.taking(a.fields, from: a.value(at: a.start + a.duration)) }
            } else {
                keep.append(a)
            }
        }
        anims = keep
    }
}
