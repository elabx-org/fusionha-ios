import SwiftUI

// The Living logo's media morphs (living/media-moves.ts, `login_living_media`).
// Ported: TV and Anime, which pose the whole mark and draw lines of light on
// the fx canvas. Movie, Dragon and Three kinds morph each blade's vector outline
// into a silhouette; the blades here are masks of the logo image, so those
// three are not ported.

/// A media move on stage: what it is, when it started, and its seeded petals.
struct LivingMediaShow {
    enum Kind { case tv, anime }

    struct Petal {
        var origin: CGPoint
        var velocity: CGVector
        var radius: CGFloat
        var angle: Double
        var spin: Double
        var life: Double
        var fade: Double
    }

    let kind: Kind
    let start: Double
    var petals: [Petal] = []

    /// How long the director waits before gliding home (Anime's petals outlive the pose).
    var duration: Double { kind == .tv ? LivingTVArt.ms : 3400 }
}

/// The mark's pose during a media move: a non-uniform scale, a nudge and a flash.
struct LivingMediaPose {
    var sx: CGFloat = 1, sy: CGFloat = 1
    var dx: CGFloat = 0, dy: CGFloat = 0
    var light: Double = 0
}

enum LivingMedia {
    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double { LivingQuality.sstep(a, b, x) }
    static func easeOut(_ k: Double) -> Double { 1 - pow(1 - max(0, min(1, k)), 3) }

    static func seed(_ kind: LivingMediaShow.Kind, at start: Double, mark: CGRect) -> LivingMediaShow {
        var show = LivingMediaShow(kind: kind, start: start)
        guard kind == .anime else { return show }
        let s = mark.width
        show.petals = (0..<12).map { _ in
            .init(origin: CGPoint(x: mark.minX - 0.6 * s + CGFloat.random(in: 0...1.8) * s,
                                  y: mark.minY - 0.5 * s - CGFloat.random(in: 0...0.4) * s),
                  velocity: CGVector(dx: .random(in: 0.05...0.09), dy: .random(in: 0.05...0.08)),
                  radius: .random(in: 4...7), angle: .random(in: 0...6), spin: .random(in: -0.004...0.004),
                  life: .random(in: 2600...3400), fade: 600)
        }
        return show
    }

    // MARK: Poses

    static func pose(_ show: LivingMediaShow, ms t: Double, size s: CGFloat) -> LivingMediaPose {
        switch show.kind {
        case .tv: return tvPose(t, s)
        case .anime: return animePose(t, s)
        }
    }

    /// TV: shrinks onto the screen, switches off to a line and a dot, and back on
    /// (the shared `LivingTVArt` pose).
    private static func tvPose(_ t: Double, _ s: CGFloat) -> LivingMediaPose {
        let p = LivingTVArt.pose(t)
        return LivingMediaPose(sx: CGFloat(p.kx), sy: CGFloat(p.ky), dy: s * CGFloat(p.ty),
                               light: p.br > 1 ? p.br - 1 : 0)
    }

    /// Anime: a dash in on speed lines and a squash on impact.
    private static func animePose(_ t: Double, _ s: CGFloat) -> LivingMediaPose {
        guard t < 3000 else { return LivingMediaPose() }
        let k = min(1, t / 360)
        let dash = CGFloat(1 - easeOut(k)) * -0.45 * s
        let stretch = 1 + 0.28 * (1 - k)
        let scl = t > 360 && t < 560 ? 1 + 0.1 * sin((t - 360) / 200 * .pi) : 1
        let flash = t > 360 && t < 660 ? 0.8 * (1 - (t - 360) / 300) : 0
        return LivingMediaPose(sx: CGFloat(stretch * scl), sy: CGFloat(scl / stretch.squareRoot()), dx: dash, light: flash)
    }
}
