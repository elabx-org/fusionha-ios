import SwiftUI
import UIKit

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
        let k = CGFloat(1 - exp(-dt * 1000 / 160))
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
        let from = CGPoint(x: to.x + CGFloat(cos(angle)) * CGFloat.random(in: 220...360),
                           y: to.y + CGFloat(sin(angle)) * CGFloat.random(in: 160...250))
        let mid = CGPoint(x: (from.x + to.x) / 2 + CGFloat.random(in: -70...70),
                          y: min(from.y, to.y) - 60 - CGFloat.random(in: 0...60))
        sparks.append(Spark(blade: i, from: from, mid: mid, to: to, start: now, duration: .random(in: 0.9...1.2),
                            color: Self.sparkColors.randomElement()!))
    }

    private func advanceSparks(_ t: Double) {
        var landed: [Spark] = []
        sparks = sparks.compactMap { spark in
            var s = spark
            let u = min(1, (t - s.start) / s.duration)
            let e = CGFloat(u * u * (3 - 2 * u) * 0.4 + u * u * 0.6)
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
