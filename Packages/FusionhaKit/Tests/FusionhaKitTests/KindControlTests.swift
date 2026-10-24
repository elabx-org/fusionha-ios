import XCTest
@testable import FusionhaKit

/// The Library kind control on the owner's real library: All 3,785 ·
/// Movies 2,629 · Series 734 · Anime 37 · Animation 385.
final class KindControlTests: XCTestCase {
    private let real: [LibraryKind: Int] = [.movie: 2629, .series: 734, .anime: 37, .animation: 385]

    func testRealLibraryShowsFiveSegments() {
        XCTAssertEqual(KindControl.kinds(titles: real, active: nil), [.movie, .series, .anime, .animation])
    }

    func testAnimationOnlyWhenPresentOrActive() {
        let none: [LibraryKind: Int] = [.movie: 5, .series: 4, .anime: 5]
        XCTAssertEqual(KindControl.kinds(titles: none, active: nil), [.movie, .series, .anime])
        XCTAssertEqual(KindControl.kinds(titles: none, active: .animation).last, .animation)
    }

    func testFallbackOrderWidestFirst() {
        XCTAssertEqual(KindControl.Fit.allCases, [.counts, .labels, .scroll])
        XCTAssertTrue(KindControl.Fit.counts.showsBar)
        XCTAssertTrue(KindControl.Fit.labels.showsBar)
        XCTAssertFalse(KindControl.Fit.scroll.showsBar, "the capsule row drops the bar")
        XCTAssertEqual(KindControl.Fit.allCases.filter(\.countsInSummary), [.labels])
    }

    func testBarSpansFromFirstToLastKindSegment() throws {
        // All 0–80, then four kind segments of unequal widths.
        let kinds: [(x: Double, width: Double)] = [(83, 120), (203, 100), (303, 90), (393, 125)]
        let span = try XCTUnwrap(KindControl.barSpan(segments: kinds, inset: 3))
        XCTAssertEqual(span.x, 86)
        XCTAssertEqual(span.x + span.width, 518 - 3)
        XCTAssertNil(KindControl.barSpan(segments: [], inset: 3))
    }

    func testBarPiecesFillTheSpanInProportion() {
        let counts = [2629, 734, 37, 385]
        let pieces = KindControl.barPieces(width: 406, counts: counts, gap: 2)
        XCTAssertEqual(pieces.count, 4)
        XCTAssertEqual(pieces.reduce(0, +) + 3 * 2, 406, accuracy: 0.001)
        XCTAssertEqual(pieces[0] / pieces[3], 2629.0 / 385.0, accuracy: 0.001)
    }
}
