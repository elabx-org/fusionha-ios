import FusionhaKit
import SwiftUI

/// A fusion move on stage: which pair, when it started, the layout for the
/// current mark size, and which one-shot rings have fired.
struct LivingFusionShow {
    let pair: FusionPair
    let start: Double
    var s: Double
    var geo: FusionDance.Layout
    var fired: Set<String> = []
}

// The two fusion moves (web `living/fusion-moves.ts`, v0.4.224): the F splits
// into two shipped Living objects that dance toward each other, touch on the
// centre line with a spark, then slide back into one F and land with the
// `fusion` move's flash. fusionMedia: the clapper and the `tv` move's TV;
// fusionQuality: the `quality` move's HD copy and its mirrored 4K copy.

extension LivingEngine {
    /// The `fusion` move's landing: a ring and a bright flash on the mark.
    func fuseFlash() {
        ring(centre, Self.lilac, size * 0.9)
        animate(mark, 600, [(0, .identity), (0.5, LivingPose(light: 0.5)), (1, .identity)], curve: .easeOut,
                fields: .filter)
    }

    /// The dance's timeline time this frame.
    var fusionTime: Double {
        guard let show = fusionShow else { return FusionDance.start }
        return FusionDance.start + (now - show.start)
    }

    /// Plays one fusion move: the mark hides while the fx canvas draws the dance,
    /// whose last frame is the F at rest; the mark comes back even if interrupted.
    func fusionMove(_ pair: FusionPair, _ g: Int) async throws {
        let s = Double(size) / 100
        let start = clock()
        posing = true
        fusionShow = LivingFusionShow(pair: pair, start: start, s: s, geo: FusionDance.layout(pair, s))
        defer { if fusionShow?.start == start { fusionShow = nil } }
        try await sleep((FusionDance.end - FusionDance.start) * 1000, g)
        fusionShow = nil
        fuseFlash()
        try await sleep(800, g)
    }

    /// Per frame: follow the mark's size, and fire the clap and contact rings once.
    func advanceFusion(_ t: Double) {
        guard var show = fusionShow else { return }
        let s = Double(size) / 100
        if abs(s - show.s) > 1e-6 {
            show.s = s
            show.geo = FusionDance.layout(show.pair, s)
        }
        let ft = FusionDance.start + (t - show.start)
        let origin = markRect.origin
        func px(_ q: LivingPt) -> CGPoint { CGPoint(x: origin.x + q.x * s, y: origin.y + q.y * s) }
        func once(_ key: String, _ at: Double, _ fire: () -> Void) {
            guard ft >= at, !show.fired.contains(key) else { return }
            show.fired.insert(key)
            fire()
        }
        if show.pair == .media {
            once("clap", FusionDance.clapHits[0]) {
                let m = FusionDance.pose(ft, .left, .media, show.geo).m
                    .mul(.about(FusionDance.movPiv, .scale(FusionDance.kMovie)))
                ring(px(m.apply(LivingPt(88, 33))), .white, 0.3 * size)
            }
        }
        let touch = px(LivingPt(FusionDance.cx, show.geo.yTouch))
        once("touch", FusionDance.T.touch) { ring(touch, .white, 0.34 * size) }
        once("touch2", FusionDance.T.touch + 0.08) { ring(touch, Self.lilac, 0.22 * size) }
        fusionShow = show
    }
}
