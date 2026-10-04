import SwiftUI
import UIKit

// The Living logo sign-in layout (components/login/living/*): the F cut into
// its three real blades on a dot field, tilting and bobbing, reacting to the
// password field like a lock's tumbler pins, and acting out what the app does
// between rests (the neutral moves: arrivals, fusion, pride, quality). The
// media-themed morphs (`login_living_media`) are not ported yet.

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
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * CGFloat(t) }
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return LivingPose(dx: m(a.dx, b.dx), dy: m(a.dy, b.dy), rot: m(a.rot, b.rot), scale: m(a.scale, b.scale),
                          rotY: m(a.rotY, b.rotY), light: m(a.light, b.light), jam: m(a.jam, b.jam),
                          opacity: m(a.opacity, b.opacity))
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

// MARK: - Engine (living/engine.ts)

private struct LivingStop: Error {}

@MainActor
final class LivingEngine {
    /// Pin pattern per blade (px at the 170px reference size). Never reveals the characters.
    static let pin: [[CGFloat]] = [[4, -3, 5, -2, 3], [-3, 5, -2, 4, -4], [5, -4, 3, -3, 2]]
    /// The pins glide home this long after the last key.
    static let settleMs = 950
    /// The success choreography; sign-in enters the app once it has played.
    static let unlockMs = 1300
    static let refSize: CGFloat = 170
    /// Blade tips: (y, x) as fractions of the mark.
    static let tips: [(y: CGFloat, xr: CGFloat)] = [(0.211, 0.9), (0.509, 0.78), (0.808, 0.39)]
    static let springK = 700.0
    static let springC = 2 * 0.45 * sqrt(700.0)

    static func pinOffsets(_ n: Int) -> [CGFloat] {
        (0..<3).map { i in
            guard n > i else { return 0 }
            let k = (n - 1 - i) / 3 + 1
            return pin[i][(k - 1) % 5]
        }
    }

    var reduce = false
    let blades = [LivingElement(), LivingElement(), LivingElement()]
    let mark = LivingElement()
    let art = LivingElement()
    /// The mark's frame in the art panel.
    var markRect = CGRect(x: 0, y: 0, width: 118, height: 118)
    var panel = CGSize(width: 402, height: 370)
    private(set) var now: Double = Date().timeIntervalSinceReferenceDate
    private var last: Double = 0
    private var gen = 0
    private var busy = false
    private(set) var listening = false
    private(set) var posing = false
    private var unlocked = false
    private(set) var tilt = CGPoint.zero
    private var pinTarget: [CGFloat] = [0, 0, 0]
    private(set) var pinX: [CGFloat] = [0, 0, 0]
    private var pinV: [CGFloat] = [0, 0, 0]
    private(set) var ripples: [Double] = []
    private(set) var sparks: [Spark] = []
    private(set) var rings: [Ring] = []
    /// The quality move's clock start (it draws its own two copies on the fx canvas).
    private(set) var qualityStart: Double?
    private var qualityRings = [false, false]
    /// The unlock glint's start.
    private(set) var sheenStart: Double?
    private var idleTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var settleTask: Task<Void, Never>?
    private var started = false

    struct Spark {
        let blade: Int
        let from: CGPoint, mid: CGPoint, to: CGPoint
        let start: Double, duration: Double
        let color: Color
        var trail: [CGPoint] = []
    }

    struct Ring {
        let center: CGPoint
        let start: Double
        let color: Color
        let radius: CGFloat
    }

    static let sparkColors: [Color] = [Color(hex: 0x3B8CF2), Color(hex: 0x9D5DA7), Color(hex: 0xFDBA61),
                                       Color(hex: 0xC256B9), Color(hex: 0xFDAC65)]
    static let lilac = Color(hex: 0xC4B5FD)

    var size: CGFloat { markRect.width }
    var centre: CGPoint { CGPoint(x: markRect.midX, y: markRect.midY) }
    func tip(_ i: Int) -> CGPoint {
        CGPoint(x: markRect.minX + Self.tips[i].xr * size, y: markRect.minY + Self.tips[i].y * size)
    }

    // MARK: Lifecycle

    func start(reduce: Bool) {
        self.reduce = reduce
        guard !started else { return }
        started = true
        guard !reduce else { return }
        let t = clock()
        // `.artin { animation: livingIn 0.6s }`
        art.anims.append(LivingAnim(start: t, duration: 0.6,
                                    frames: [(0, LivingPose(dy: 6, scale: 0.98, opacity: 0)), (1, .identity)],
                                    curve: LivingEase.rise, forwards: false))
        gen += 1
        idle(gen)
    }

    func stop() {
        gen += 1
        idleTask?.cancel(); restartTask?.cancel(); settleTask?.cancel()
        started = false
    }

    private func clock() -> Double { Date().timeIntervalSinceReferenceDate }

    private func sleep(_ ms: Double, _ g: Int) async throws {
        try await Task.sleep(for: .milliseconds(Int(ms)))
        if g != gen { throw LivingStop() }
    }

    private func animate(_ el: LivingElement, _ ms: Double, _ frames: [(Double, LivingPose)], curve: UnitCurve = .linear,
                         fields: LivingPose.Fields = .all, delay: Double = 0, forwards: Bool = true, additive: Bool = false) {
        el.anims.append(LivingAnim(start: clock() + delay / 1000, duration: ms / 1000, frames: frames, curve: curve,
                                   fields: fields, forwards: forwards, additive: additive))
    }

    // MARK: Frame (one per display refresh)

    func advance(to date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        let dt = min(0.05, last == 0 ? 0 : max(0, t - last))
        last = t
        now = t
        // Tilt: no pointer on a phone, so the mark faces front unless it is listening.
        let target: CGPoint = listening ? CGPoint(x: 0, y: 0.7) : .zero
        let k = 1 - exp(-dt * 1000 / 160)
        tilt.x += (target.x - tilt.x) * k
        tilt.y += (target.y - tilt.y) * k
        stepSprings(dt * 1000)
        for el in blades + [mark, art] { el.settle(at: t) }
        ripples.removeAll { t - $0 > 1.5 }
        rings.removeAll { t - $0.start >= 0.56 }
        advanceSparks(t)
        advanceQuality(t)
    }

    /// The bob (`sin(now × 0.0014) × 3`), still while listening or posing.
    var bob: CGFloat { listening || posing ? 0 : CGFloat(sin(now * 1000 * 0.0014) * 3) }

    private func stepSprings(_ dtMs: Double) {
        var rem = dtMs
        while rem > 0 {
            let h = min(4, rem) / 1000
            for i in 0..<3 {
                let a = -Self.springK * Double(pinX[i] - pinTarget[i]) - Self.springC * Double(pinV[i])
                pinV[i] += CGFloat(a * h)
                pinX[i] += pinV[i] * CGFloat(h)
            }
            rem -= 4
        }
        for i in 0..<3 where abs(pinX[i] - pinTarget[i]) < 0.01 && abs(pinV[i]) < 0.01 {
            pinX[i] = pinTarget[i]
            pinV[i] = 0
        }
    }

    private func setPins(_ n: Int) {
        let offsets = Self.pinOffsets(n)
        let scale = size / Self.refSize
        pinTarget = offsets.map { $0 * scale }
    }

    // MARK: fx: sparks and rings (living/fx-layer.ts)

    func ring(_ center: CGPoint, _ color: Color, _ radius: CGFloat) {
        rings.append(Ring(center: center, start: now, color: color, radius: radius))
        ripples.append(now)
    }

    private func launch(_ i: Int) {
        let to = tip(i)
        let angle = Double.random(in: 0..<(2 * .pi))
        let from = CGPoint(x: to.x + cos(angle) * .random(in: 220...360), y: to.y + sin(angle) * .random(in: 160...250))
        let mid = CGPoint(x: (from.x + to.x) / 2 + .random(in: -70...70), y: min(from.y, to.y) - 60 - .random(in: 0...60))
        sparks.append(Spark(blade: i, from: from, mid: mid, to: to, start: now, duration: .random(in: 0.9...1.2),
                            color: Self.sparkColors.randomElement()!))
    }

    private func advanceSparks(_ t: Double) {
        var landed: [Spark] = []
        sparks = sparks.compactMap { spark in
            var s = spark
            let u = min(1, (t - s.start) / s.duration)
            let e = u * u * (3 - 2 * u) * 0.4 + u * u * 0.6
            let q = 1 - e
            let x = q * q * s.from.x + 2 * q * e * s.mid.x + e * e * s.to.x
            let y = q * q * s.from.y + 2 * q * e * s.mid.y + e * e * s.to.y
            s.trail.append(CGPoint(x: x, y: y))
            if s.trail.count > 16 { s.trail.removeFirst() }
            if u >= 1 { landed.append(s); return nil }
            return s
        }
        for s in landed {
            animate(blades[s.blade], 380, [(0, .identity), (0.5, LivingPose(dx: -0.025 * size, light: 0.35)), (1, .identity)],
                    curve: LivingEase.ease, forwards: false, additive: true)
            ring(s.to, s.color, 18)
        }
    }

    // MARK: Director

    private func idle(_ g: Int) {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            var k = 0
            do {
                while let self, g == self.gen {
                    try await self.sleep(2600 + .random(in: 0...1200), g)
                    try await self.play(Move.allCases[k % Move.allCases.count], g)
                    k += 1
                }
            } catch {}
        }
    }

    /// The neutral moves, in the idle order (`NEUTRAL_MOVES`).
    enum Move: CaseIterable { case arrivals, fusion, pride, quality }

    private func play(_ move: Move, _ g: Int) async throws {
        busy = true
        defer { if g == gen { busy = false } }
        switch move {
        case .arrivals: try await Self.arrivals(self, g)
        case .fusion: try await Self.fusion(self, g)
        case .pride: try await Self.pride(self, g)
        case .quality: try await Self.quality(self, g)
        }
        await home(320)
    }

    /// From wherever the blades are, glide back to the exact logo.
    private func home(_ ms: Double) async {
        posing = false
        qualityStart = nil
        let t = clock()
        for el in blades + [mark] {
            let current = el.pose(at: t)
            el.anims = []
            el.base = .identity
            if current != .identity {
                el.anims.append(LivingAnim(start: t, duration: ms / 1000, frames: [(0, current), (1, .identity)],
                                           curve: LivingEase.ease, forwards: false))
            }
        }
        try? await Task.sleep(for: .milliseconds(Int(ms)))
    }

    private func interrupt(_ ms: Double) async {
        gen += 1
        busy = false
        idleTask?.cancel()
        await home(ms)
    }

    private func restartIdleSoon() {
        restartTask?.cancel()
        guard !reduce, !unlocked else { return }
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, !self.unlocked, !self.listening else { return }
            self.gen += 1
            self.idle(self.gen)
        }
    }

    // MARK: Sign-in reactions (living/signin.ts)

    /// Password focused: pause the moves and turn toward the form.
    func listen() {
        guard !reduce, !listening, !unlocked else { return }
        listening = true
        restartTask?.cancel()
        Task { await interrupt(260) }
    }

    /// Password blurred: pins home, resume the idle loop soon.
    func unlisten() {
        guard !reduce, !unlocked else { return }
        listening = false
        settleTask?.cancel()
        setPins(0)
        restartIdleSoon()
    }

    /// Password length changed: each key nudges the next blade out of line.
    func typing(_ n: Int) {
        guard !reduce, !unlocked else { return }
        listen()
        setPins(n)
        settleTask?.cancel()
        guard n > 0 else { return }
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.settleMs))
            guard !Task.isCancelled else { return }
            self?.setPins(0)
        }
        animate(blades[(n - 1) % 3], 220, [(0, .identity), (0.5, LivingPose(light: 0.35)), (1, .identity)],
                fields: .filter, forwards: false)
    }

    /// A wrong password: the pins jam (an amber shudder), then reset.
    func fail() {
        guard !reduce, !unlocked else { return }
        listening = false
        settleTask?.cancel()
        setPins(0)
        Task {
            await interrupt(200)
            let a: [CGFloat] = [8, -6, 10], b: [CGFloat] = [-5, 4, -6], c: [CGFloat] = [3, -2, 3]
            for (i, blade) in blades.enumerated() {
                animate(blade, 1000, [(0, .identity), (0.18, LivingPose(dx: a[i], scale: 0.94)),
                                      (0.36, LivingPose(dx: b[i], scale: 0.94)), (0.52, LivingPose(dx: c[i], scale: 0.95)),
                                      (1, .identity)],
                        curve: .easeOut, fields: .transform, forwards: false)
                animate(blade, 1000, [(0, .identity), (0.18, LivingPose(light: 0.05, jam: 1)), (1, .identity)],
                        curve: .easeOut, fields: .filter, forwards: false)
            }
        }
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            self?.restartIdleSoon()
        }
    }

    /// The right password: the pins line up, a glint, a proud spin, then the
    /// mark dives into the app (~1.24s; sign-in waits `unlockMs`).
    func unlock() {
        guard !reduce, !unlocked else { return }
        unlocked = true
        listening = false
        idleTask?.cancel(); restartTask?.cancel(); settleTask?.cancel()
        setPins(0)
        let wasBusy = busy
        gen += 1
        busy = false
        if wasBusy { Task { await home(160) } }
        sheenStart = clock() + 0.1
        animate(mark, 420, [(0, .identity), (0.5, LivingPose(light: 0.35)), (1, .identity)],
                fields: .filter, delay: 100, forwards: false)
        animate(mark, 620, [(0, .identity), (1, LivingPose(dy: -10, scale: 1.08, rotY: 360))],
                curve: LivingEase.turn, fields: .transform, delay: 380)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }
            self.ring(self.centre, Self.lilac, self.size)
        }
        animate(art, 420, [(0, .identity), (1, LivingPose(scale: 1.35, opacity: 0))], curve: LivingEase.dive, delay: 820)
    }

    // MARK: Neutral moves (living/moves.ts)

    /// Arrivals: sparks in the logo's colours drift in and are taken in.
    private static func arrivals(_ st: LivingEngine, _ g: Int) async throws {
        for k in 0..<7 {
            st.launch(k % 3)
            try await st.sleep(260 + .random(in: 0...220), g)
        }
        try await st.sleep(1100, g)
    }

    /// Fusion: the F splits into two groups that drift apart, then rush back
    /// together with a flash. Two apps become one.
    private static func fusion(_ st: LivingEngine, _ g: Int) async throws {
        let s = st.size
        let apart: [(CGFloat, CGFloat, Double)] = [(-0.42, -0.04, -9), (0.46, 0.02, 7), (-0.42, 0.05, 8)]
        func at(_ i: Int, _ dy: CGFloat = 0, _ rot: Double = 1) -> LivingPose {
            LivingPose(dx: apart[i].0 * s, dy: (apart[i].1 + dy) * s, rot: apart[i].2 * rot)
        }
        for i in 0..<3 {
            st.animate(st.blades[i], 700, [(0, .identity), (1, at(i))], curve: LivingEase.ease, fields: .transform)
        }
        try await st.sleep(700, g)
        for i in 0..<3 {
            st.animate(st.blades[i], 650, [(0, at(i)), (1, at(i, -0.03, 0.7))], curve: .easeInOut, fields: .transform)
        }
        try await st.sleep(650, g)
        for i in 0..<3 {
            st.animate(st.blades[i], 560, [(0, at(i, -0.03, 0.7)), (0.78, LivingPose(dx: -apart[i].0 * 0.05 * s, scale: 0.97)),
                                           (1, .identity)], curve: LivingEase.snap, fields: .transform)
        }
        try await st.sleep(430, g)
        st.ring(st.centre, lilac, s * 0.9)
        st.animate(st.mark, 600, [(0, .identity), (0.5, LivingPose(light: 0.5)), (1, .identity)], curve: .easeOut,
                   fields: .filter)
        try await st.sleep(800, g)
    }

    /// Pride: a full 3D turn with a sheen across the blades, a lift, a settle.
    private static func pride(_ st: LivingEngine, _ g: Int) async throws {
        st.animate(st.mark, 1700, [(0, .identity), (0.5, LivingPose(dy: -8, scale: 1.04, rotY: 180)),
                                   (0.82, LivingPose(dy: -8, scale: 1.06, rotY: 360)), (1, .identity)],
                   curve: LivingEase.turn, fields: .transform)
        for i in 0..<3 {
            st.animate(st.blades[i], 1700, [(0, .identity), (0.6 + Double(i) * 0.06, LivingPose(light: 0.4)), (1, .identity)],
                       fields: .filter)
        }
        try await st.sleep(1900, g)
    }

    /// Quality tiers: the F splits in two; one settles soft (HD), the other steps
    /// up to razor-crisp (4K); each fills its own progress, then they merge.
    private static func quality(_ st: LivingEngine, _ g: Int) async throws {
        st.posing = true
        st.qualityRings = [false, false]
        st.qualityStart = st.clock()
        defer { st.qualityStart = nil }
        try await st.sleep(4300, g)
    }

    private func advanceQuality(_ t: Double) {
        guard let start = qualityStart else { return }
        let ms = (t - start) * 1000
        guard let q = LivingQuality.frame(ms: ms, size: size, centre: centre) else { return }
        if !qualityRings[0], ms >= 2500, q.split > 0.6 {
            qualityRings[0] = true
            ring(CGPoint(x: centre.x - q.offset, y: centre.y), Color(hex: 0x93C5FD), 0.55 * size)
        }
        if !qualityRings[1], ms >= 3150, q.split > 0.6 {
            qualityRings[1] = true
            ring(CGPoint(x: centre.x + q.offset, y: centre.y), Color(hex: 0xA5F3FC), 0.65 * size)
        }
    }
}

/// The quality move's per-frame layout (moves.ts `quality`).
enum LivingQuality {
    struct Frame {
        var split: Double
        var offset: CGFloat
        var scaleL: CGFloat, scaleR: CGFloat
        var resL: Int, resR: Int
        var glowR: Double
        var fade: Double
        var fillL: Double, fillR: Double
        var flashL: Double, flashR: Double
    }

    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    static func frame(ms t: Double, size s: CGFloat, centre: CGPoint) -> Frame? {
        guard t >= 0, t <= 4300 else { return nil }
        let steps = [10, 16, 24, 36, 56, 0]
        let split = sstep(150, 750, t) * (1 - sstep(3500, 4100, t))
        let coarse = t > 250 && t < 3700
        var resL = 0, resR = 0
        if coarse {
            resL = t < 900 ? 10 : t < 1150 ? 16 : t < 1400 ? 24 : 40
            let k = Int(max(0, t - 900) / 170)
            resR = t < 900 ? 10 : steps[min(steps.count - 1, k)]
        }
        if t > 3550 { resL = 0 }
        let glowR = resR == 0 && t > 1700 && t < 3700 ? min(1, (t - 1700) / 300) * (1 - sstep(3400, 3700, t)) : 0
        let fade = t < 150 ? t / 150 : t > 4150 ? max(0, (4300 - t) / 150) : 1
        return Frame(split: split, offset: 0.64 * s * CGFloat(split), scaleL: 1 - 0.18 * CGFloat(split),
                     scaleR: 1 - 0.06 * CGFloat(split), resL: resL, resR: resR, glowR: glowR, fade: fade,
                     fillL: sstep(1100, 2500, t), fillR: sstep(1100, 3150, t),
                     flashL: t > 2500 && t < 2900 ? 1 - (t - 2500) / 400 : 0,
                     flashR: t > 3150 && t < 3550 ? 1 - (t - 3150) / 400 : 0)
    }

    /// The logo redrawn at `res`×`res` (nearest-neighbour when scaled back up).
    @MainActor static func pixelated(_ res: Int) -> UIImage? {
        if let hit = cache[res] { return hit }
        guard let logo = UIImage(named: "BrandLogo") else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: res, height: res), format: format).image { _ in
            logo.draw(in: CGRect(x: 0, y: 0, width: res, height: res))
        }
        cache[res] = image
        return image
    }

    @MainActor private static var cache: [Int: UIImage] = [:]
}

// MARK: - View (living/LivingMark.tsx)

/// The Living logo art panel: the dot field behind, the F's three blades inside
/// a tilt wrapper (with the unlock glint), a soft floor shadow, the optional
/// wordmark/tagline caption, and the fx canvas in front. Reduce Motion paints
/// the plain logo on a still dot field.
struct LivingMark<Caption: View>: View {
    let engine: LivingEngine
    let reduce: Bool
    @ViewBuilder var caption: Caption

    /// Where the three blades are cut from the logo (fraction of its height).
    private static var seams: [CGFloat] { [0.356, 0.658] }
    private static var feather: CGFloat { 0.03 }
    private static var space: String { "living-art" }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduce)) { context in
            let _ = engine.advance(to: context.date)
            ZStack {
                Canvas { ctx, size in drawDots(ctx, size) }
                VStack(spacing: 0) {
                    markView
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { engine.markRect = $0 }
                    Ellipse()
                        .fill(RadialGradient(colors: [.black.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 50))
                        .frame(width: 100, height: 18)
                        .padding(.top, 10)
                    caption
                }
                .modifier(PoseEffect(pose: engine.art.pose(at: engine.now)))
                if !reduce {
                    Canvas { ctx, _ in drawFx(ctx) }
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x08090D))
        .clipped()
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { engine.panel = $0 }
        .onAppear { engine.start(reduce: reduce) }
        .onDisappear { engine.stop() }
    }

    // MARK: Mark

    @ViewBuilder
    private var markView: some View {
        let mark = engine.mark.pose(at: engine.now)
        let hidden = engine.qualityStart != nil
        Group {
            if reduce {
                Image("BrandLogo").resizable().scaledToFit()
            } else {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        blade(i)
                    }
                    sheen
                }
            }
        }
        .frame(width: 118, height: 118)
        .brightness(mark.light * 0.45)
        .rotation3DEffect(.degrees(mark.rotY), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .scaleEffect(mark.scale)
        .offset(y: mark.dy)
        .opacity(hidden ? 0 : 1)
        // The tilt wrapper: a gentle bob, turned toward the form while listening.
        .rotation3DEffect(.degrees(Double(-engine.tilt.y) * 9), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(Double(engine.tilt.x) * 14), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .offset(y: engine.bob)
        .accessibilityElement()
        .accessibilityLabel("fusionha")
        .accessibilityAddTraits(.isImage)
    }

    private func blade(_ i: Int) -> some View {
        let pose = engine.blades[i].pose(at: engine.now)
        let anchor = UnitPoint(x: 0.2, y: 0.5)
        return Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .mask(bladeMask(i))
            .colorMultiply(pose.jam > 0 ? Color(red: 1, green: 1 - 0.32 * pose.jam, blue: 1 - 0.7 * pose.jam) : .white)
            .brightness(pose.light * 0.45)
            .scaleEffect(pose.scale, anchor: anchor)
            .rotationEffect(.degrees(pose.rot), anchor: anchor)
            .offset(x: pose.dx + engine.pinX[i], y: pose.dy)
    }

    /// `bladeMask`: blade 0 is the top band; each lower band feathers in over the one above.
    private func bladeMask(_ i: Int) -> LinearGradient {
        let seams = Self.seams, f = Self.feather
        let stops: [Gradient.Stop]
        switch i {
        case 0:
            stops = [.init(color: .black, location: 0), .init(color: .black, location: seams[0]),
                     .init(color: .clear, location: seams[0]), .init(color: .clear, location: 1)]
        case 1:
            stops = [.init(color: .clear, location: 0), .init(color: .clear, location: seams[0] - f),
                     .init(color: .black, location: seams[0]), .init(color: .black, location: seams[1]),
                     .init(color: .clear, location: seams[1]), .init(color: .clear, location: 1)]
        default:
            stops = [.init(color: .clear, location: 0), .init(color: .clear, location: seams[1] - f),
                     .init(color: .black, location: seams[1]), .init(color: .black, location: 1)]
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// The "unlocked" glint: a bright band sweeping across, masked to the logo.
    @ViewBuilder
    private var sheen: some View {
        if let start = engine.sheenStart, engine.now >= start, engine.now <= start + 0.42 {
            let p = LivingEase.glint.value(at: (engine.now - start) / 0.42)
            GeometryReader { geo in
                let w = geo.size.width
                LinearGradient(stops: [.init(color: .clear, location: 0.4), .init(color: .white.opacity(0.6), location: 0.5),
                                       .init(color: .clear, location: 0.6)],
                               startPoint: UnitPoint(x: 0, y: 0.4), endPoint: UnitPoint(x: 1, y: 0.6))
                    .frame(width: w * 2.5)
                    // background-position 130% → -30% over a 250%-wide band.
                    .offset(x: -(1.3 - 1.6 * p) * w * 1.5)
            }
            .mask(Image("BrandLogo").resizable().scaledToFit())
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }

    // MARK: Canvases

    /// The dot field (dot-field.ts): faint dots, brighter near the mark, with a
    /// ripple running out through them whenever a move lands.
    private func drawDots(_ ctx: GraphicsContext, _ size: CGSize) {
        let spacing: CGFloat = 16
        let c = engine.centre
        let t = engine.now
        let ripples = reduce ? [] : engine.ripples
        var y = spacing / 2
        while y < size.height {
            var x = spacing / 2
            while x < size.width {
                let d2 = Double((x - c.x) * (x - c.x) + (y - c.y) * (y - c.y))
                var alpha = 0.05 + 0.2 * exp(-d2 / (2 * 160 * 160))
                if !ripples.isEmpty {
                    let d = d2.squareRoot()
                    for r in ripples {
                        let age = (t - r) * 1000
                        let radius = age * 0.32
                        alpha += 0.55 * exp(-((d - radius) * (d - radius)) / (2 * 12 * 12)) * max(0, 1 - age / 1500)
                    }
                }
                ctx.fill(Path(CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)),
                         with: .color(Color(red: 170 / 255, green: 180 / 255, blue: 1).opacity(min(0.9, alpha))))
                x += spacing
            }
            y += spacing
        }
    }

    /// The fx canvas: spark trails, landing rings and the quality move's two copies.
    private func drawFx(_ ctx: GraphicsContext) {
        var ctx = ctx
        ctx.blendMode = .plusLighter
        drawQuality(&ctx)
        for spark in engine.sparks {
            let n = spark.trail.count
            for j in 1..<max(n, 1) where n > 1 {
                var p = Path()
                p.move(to: spark.trail[j - 1])
                p.addLine(to: spark.trail[j])
                let k = Double(j) / Double(n)
                ctx.stroke(p, with: .color(spark.color.opacity(k * 200 / 255)), lineWidth: 2.2 * k)
            }
            if let head = spark.trail.last {
                let glow = Path(ellipseIn: CGRect(x: head.x - 7, y: head.y - 7, width: 14, height: 14))
                ctx.fill(glow, with: .radialGradient(Gradient(colors: [spark.color.opacity(0.7), .clear]),
                                                    center: head, startRadius: 0, endRadius: 7))
                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.2, y: head.y - 2.2, width: 4.4, height: 4.4)), with: .color(.white))
            }
        }
        for ring in engine.rings {
            let u = (engine.now - ring.start) / 0.56
            guard u < 1 else { continue }
            let r = 4 + ring.radius * CGFloat(1 - pow(1 - u, 3))
            ctx.stroke(Path(ellipseIn: CGRect(x: ring.center.x - r, y: ring.center.y - r, width: r * 2, height: r * 2)),
                       with: .color(ring.color.opacity((1 - u) * 200 / 255)), lineWidth: 1.6)
        }
    }

    private func drawQuality(_ ctx: inout GraphicsContext) {
        guard let start = engine.qualityStart,
              let q = LivingQuality.frame(ms: (engine.now - start) * 1000, size: engine.size, centre: engine.centre)
        else { return }
        let s = engine.size, c = engine.centre
        var plain = ctx
        plain.blendMode = .normal
        func copy(_ cx: CGFloat, _ size: CGFloat, _ res: Int, _ glow: Double) {
            let rect = CGRect(x: cx - size / 2, y: c.y - size / 2, width: size, height: size)
            let image: Image
            if res > 0, let px = LivingQuality.pixelated(res) {
                image = Image(uiImage: px).interpolation(.none)
            } else {
                image = Image("BrandLogo")
            }
            plain.drawLayer { layer in
                layer.opacity = q.fade
                if glow > 0 { layer.addFilter(.shadow(color: Color(hex: 0xA5F3FC).opacity(0.55 * glow), radius: 11 * glow)) }
                layer.draw(image.resizable(), in: rect)
            }
        }
        copy(c.x - q.offset, s * q.scaleL, q.resL, 0)
        copy(c.x + q.offset, s * q.scaleR, q.resR, q.glowR)
        guard q.split > 0.6 else { return }
        let alpha = min(1, (q.split - 0.6) / 0.4)
        func bar(_ cx: CGFloat, _ y: CGFloat, _ w: CGFloat, _ fill: Double, _ flash: Double) {
            plain.drawLayer { layer in
                layer.opacity = alpha
                let track = Path(roundedRect: CGRect(x: cx - w / 2, y: y, width: w, height: 4), cornerRadius: 2)
                layer.fill(track, with: .color(.white.opacity(0.08)))
                if fill > 0 {
                    let bar = Path(roundedRect: CGRect(x: cx - w / 2, y: y, width: max(4, w * CGFloat(fill)), height: 4), cornerRadius: 2)
                    layer.fill(bar, with: .linearGradient(Gradient(stops: [.init(color: Color(hex: 0x3B8CF2), location: 0),
                                                                          .init(color: Color(hex: 0xC256B9), location: 0.55),
                                                                          .init(color: Color(hex: 0xFDBA61), location: 1)]),
                                                          startPoint: CGPoint(x: cx - w / 2, y: 0), endPoint: CGPoint(x: cx + w / 2, y: 0)))
                }
                if flash > 0 {
                    layer.addFilter(.shadow(color: .white, radius: 6))
                    layer.fill(track, with: .color(.white.opacity(flash)))
                }
            }
        }
        bar(c.x - q.offset, c.y + s * q.scaleL / 2 + 16, s * 0.62 * q.scaleL, q.fillL, q.flashL)
        bar(c.x + q.offset, c.y + s * q.scaleR / 2 + 16, s * 0.62 * q.scaleR, q.fillR, q.flashR)
    }
}

/// Applies a pose to the art wrapper (entrance + the unlock dive).
private struct PoseEffect: ViewModifier {
    let pose: LivingPose
    func body(content: Content) -> some View {
        content
            .scaleEffect(pose.scale)
            .offset(x: pose.dx, y: pose.dy)
            .opacity(pose.opacity)
    }
}
