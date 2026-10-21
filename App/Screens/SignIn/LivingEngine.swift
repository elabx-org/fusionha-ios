import FusionhaKit
import SwiftUI
import UIKit

// MARK: - Engine (living/engine.ts)

struct LivingStop: Error {}

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
    var gen = 0
    var busy = false
    var listening = false
    var posing = false
    var unlocked = false
    private(set) var tilt = CGPoint.zero
    private var pinTarget: [CGFloat] = [0, 0, 0]
    private(set) var pinX: [CGFloat] = [0, 0, 0]
    private var pinV: [CGFloat] = [0, 0, 0]
    private(set) var ripples: [Double] = []
    private(set) var sparks: [Spark] = []
    private(set) var rings: [Ring] = []
    /// The quality move's clock start (it draws its own two copies on the fx canvas).
    var qualityStart: Double?
    var qualityRings = [false, false]
    /// The unlock glint's start.
    var sheenStart: Double?
    var idleTask: Task<Void, Never>?
    var restartTask: Task<Void, Never>?
    var settleTask: Task<Void, Never>?
    private var started = false
    /// `login_living_media`: the media morphs join the idle loop.
    var media = false
    /// The media move on stage (drawn by `LivingMark` with `LivingMedia`).
    var mediaShow: LivingMediaShow?
    /// The fusion move on stage (drawn by `LivingMark` with `LivingFusionFrame`).
    var fusionShow: LivingFusionShow?
    /// The server step's "connecting" sparks.
    var connectTask: Task<Void, Never>?

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

    func clock() -> Double { Date().timeIntervalSinceReferenceDate }

    func sleep(_ ms: Double, _ g: Int) async throws {
        try await Task.sleep(for: .milliseconds(Int(ms)))
        if g != gen { throw LivingStop() }
    }

    func animate(_ el: LivingElement, _ ms: Double, _ frames: [(Double, LivingPose)], curve: UnitCurve = .linear,
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
        advanceFusion(t)
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

    func setPins(_ n: Int) {
        let offsets = Self.pinOffsets(n)
        let scale = size / Self.refSize
        pinTarget = offsets.map { $0 * scale }
    }

    // MARK: fx: sparks and rings (living/fx-layer.ts)

    func ring(_ center: CGPoint, _ color: Color, _ radius: CGFloat) {
        rings.append(Ring(center: center, start: now, color: color, radius: radius))
        ripples.append(now)
    }

    func launch(_ i: Int) {
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

    func idle(_ g: Int) {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            var k = 0
            do {
                while let self, g == self.gen {
                    try await self.sleep(2600 + .random(in: 0...1200), g)
                    let order = LivingMoveName.order(media: self.media, playable: Self.playable)
                    try await self.play(order[k % order.count], g)
                    k += 1
                }
            } catch {}
        }
    }

    /// The moves this port plays: the neutral set, TV, Anime and both fusion
    /// moves. Movie, Dragon and Three kinds aren't ported (F2b); the rotation is
    /// the web's `buildMoveOrder` without them.
    static let playable: Set<LivingMoveName> = [.arrivals, .fusion, .quality, .pride, .fusionQuality,
                                                .tv, .anime, .fusionMedia]

    private func play(_ move: LivingMoveName, _ g: Int) async throws {
        busy = true
        defer { if g == gen { busy = false } }
        switch move {
        case .arrivals: try await Self.arrivals(self, g)
        case .fusion: try await Self.fusion(self, g)
        case .pride: try await Self.pride(self, g)
        case .quality: try await Self.quality(self, g)
        case .tv: try await perform(.tv, g)
        case .anime: try await perform(.anime, g)
        case .fusionMedia: try await fusionMove(.media, g)
        case .fusionQuality: try await fusionMove(.quality, g)
        case .kinds2, .movie, .dragon: break
        }
        await home(320)
    }

    /// From wherever the blades are, glide back to the exact logo.
    func home(_ ms: Double) async {
        posing = false
        qualityStart = nil
        mediaShow = nil
        fusionShow = nil
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

    func interrupt(_ ms: Double) async {
        gen += 1
        busy = false
        idleTask?.cancel()
        await home(ms)
    }

    func restartIdleSoon() {
        restartTask?.cancel()
        guard !reduce, !unlocked else { return }
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, !self.unlocked, !self.listening else { return }
            self.gen += 1
            self.idle(self.gen)
        }
    }
}
