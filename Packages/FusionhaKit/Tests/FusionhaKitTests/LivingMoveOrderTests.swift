import XCTest
@testable import FusionhaKit

/// The web's `living/fusion-moves.test.tsx` rotation tests (v0.4.224), plus the
/// same rule on the iOS rotation (the web's order without the unported morphs).
final class LivingMoveOrderTests: XCTestCase {
    typealias M = LivingMoveName

    func testNeutralHasHDx4KWithPrideBetweenItAndQualityTiers() {
        XCTAssertEqual(M.order(media: false), [.arrivals, .fusion, .quality, .pride, .fusionQuality])
        XCTAssertFalse(M.order(media: false).contains(.fusionMedia))
    }

    func testMediaOnBothFusionMovesJoinTheInterleavedRotation() {
        XCTAssertEqual(M.order(media: true), [
            .arrivals, .kinds2, .fusion, .movie, .pride, .tv, .quality, .anime, .fusionQuality, .dragon, .fusionMedia,
        ])
        // every move of both lists, once
        XCTAssertEqual(M.order(media: true).map(\.rawValue).sorted(), (M.neutral + M.media).map(\.rawValue).sorted())
    }

    func testNoFusionMoveSitsNextToAMoveShowingTheSameObject() {
        let clash: [M: [M]] = [.fusionMedia: [.movie, .tv, .kinds2], .fusionQuality: [.quality]]
        for media in [false, true] {
            let order = M.order(media: media)
            for (i, m) in order.enumerated() {
                let next = order[(i + 1) % order.count]
                for (f, objs) in clash {
                    for o in objs {
                        let pair = [m, next]
                        XCTAssertFalse(pair.contains(f) && pair.contains(o), "\(m) → \(next)")
                    }
                }
            }
            XCTAssertTrue(M.keepsFusionApart(order))
        }
    }

    /// iOS hasn't ported Movie, Dragon or Three kinds (F2b): the rotation it plays
    /// keeps the web's order without them, and the same rule.
    func testIOSRotationKeepsTheWebOrderAndTheRule() {
        let playable: Set<M> = [.arrivals, .fusion, .quality, .pride, .fusionQuality, .tv, .anime, .fusionMedia]
        XCTAssertEqual(M.order(media: false, playable: playable), M.order(media: false))
        let media = M.order(media: true, playable: playable)
        XCTAssertEqual(media, [.arrivals, .fusion, .pride, .tv, .quality, .anime, .fusionQuality, .fusionMedia])
        XCTAssertTrue(M.keepsFusionApart(media))
        XCTAssertFalse(M.keepsFusionApart([.arrivals, .quality, .fusionQuality]))
        XCTAssertFalse(M.keepsFusionApart([.fusionMedia, .arrivals, .tv]))
    }
}
