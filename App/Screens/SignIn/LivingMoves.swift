import SwiftUI

// The neutral moves (living/moves.ts): each acts out something the app does
// with the F's own blades; the director glides it home afterwards.

extension LivingEngine {
    /// Arrivals: sparks in the logo's colours drift in and are taken in.
    static func arrivals(_ st: LivingEngine, _ g: Int) async throws {
        for k in 0..<7 {
            st.launch(k % 3)
            try await st.sleep(260 + .random(in: 0...220), g)
        }
        try await st.sleep(1100, g)
    }

    /// Fusion: the F splits into two groups that drift apart, then rush back
    /// together with a flash. Two apps become one.
    static func fusion(_ st: LivingEngine, _ g: Int) async throws {
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
        st.fuseFlash()
        try await st.sleep(800, g)
    }

    /// Pride: a full 3D turn with a sheen across the blades, a lift, a settle.
    static func pride(_ st: LivingEngine, _ g: Int) async throws {
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
    static func quality(_ st: LivingEngine, _ g: Int) async throws {
        st.posing = true
        st.qualityRings = [false, false]
        st.qualityStart = st.clock()
        defer { st.qualityStart = nil }
        try await st.sleep(4300, g)
    }

    func advanceQuality(_ t: Double) {
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
