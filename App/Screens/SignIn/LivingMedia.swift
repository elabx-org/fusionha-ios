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
    var duration: Double { kind == .tv ? 3500 : 3400 }
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

    static let brand = Gradient(stops: [.init(color: Color(hex: 0x3B8CF2), location: 0),
                                        .init(color: Color(hex: 0xC256B9), location: 0.55),
                                        .init(color: Color(hex: 0xFDBA61), location: 1)])

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

    /// TV: shrinks onto the screen, switches off to a line and a dot, and back on.
    private static func tvPose(_ t: Double, _ s: CGFloat) -> LivingMediaPose {
        let a = sstep(0, 600, t) * (1 - sstep(3050, 3500, t))
        let sc = 1 - 0.36 * a
        var sx = 1.0, sy = 1.0, br = 1.0
        if t > 1700 && t <= 2000 {
            sy = 1 - 0.98 * easeOut((t - 1700) / 300); br = 1.8
        } else if t > 2000 && t <= 2200 {
            sy = 0.02; sx = 1 - easeOut((t - 2000) / 200); br = 2
        } else if t > 2200 && t <= 2500 {
            sx = 0; sy = 0.02
        } else if t > 2500 && t <= 2950 {
            let k = (t - 2500) / 450
            sx = easeOut(k * 1.6)
            sy = k < 0.4 ? 0.02 : 0.02 + 0.98 * easeOut((k - 0.4) / 0.6) * (1 + 0.08 * sin((k - 0.4) * 9) * (1 - k))
            br = 1.4
        }
        return LivingMediaPose(sx: CGFloat(sc * sx), sy: CGFloat(sc * sy), dy: 0.05 * s * CGFloat(a),
                               light: br > 1 ? br - 1 : 0)
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
