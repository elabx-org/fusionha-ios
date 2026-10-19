import XCTest
@testable import FusionhaKit

/// Mirrors fusionha's `mono-status.test.tsx` / `mono-no-hue-only.test.tsx` /
/// `status-mono.test.ts`: under Monochrome no status relies on hue alone.
final class MonoStatusTests: XCTestCase {
    func testTokensMapToTheWebPatternsAndGlyphs() {
        XCTAssertEqual(EditionStatus.downloading.monoToken.pattern, .diag)
        XCTAssertEqual(EditionStatus.deadlink.monoToken.pattern, .horiz)
        XCTAssertEqual(EditionStatus.downloaded.monoToken.glyph, "✓")
        XCTAssertEqual(MonoToken.stuck.pattern, .anti)
        XCTAssertEqual(MonoToken.unaired.glyph, "…")
        XCTAssertEqual(MonoToken.danger.glyph, "✕")
        XCTAssertEqual(MonoToken.done.pattern, .none)
        XCTAssertEqual(MonoToken.danger.pattern, .none)
    }

    func testEveryTokenHasADistinctGlyphAndSymbol() {
        let all = MonoToken.allCases
        XCTAssertEqual(Set(all.map(\.glyph)).count, all.count)
        XCTAssertEqual(Set(all.map(\.symbol)).count, all.count)
    }

    func testPatternsAreDistinctApartFromThePlainFills() {
        let patterned = MonoToken.allCases.filter { $0.pattern != .none }
        XCTAssertEqual(Set(patterned.map(\.pattern)).count, patterned.count)
        XCTAssertEqual(Set(MonoToken.allCases.filter { $0.pattern == .none }), [.done, .danger])
    }

    /// The rule: any two statuses differ by something other than hue
    /// (shade, pattern or glyph).
    func testNoTwoTokensShareShadePatternAndGlyph() {
        let sigs = MonoToken.allCases.map { "\($0.monoShade)|\($0.pattern)|\($0.glyph)" }
        XCTAssertEqual(Set(sigs).count, sigs.count)
    }

    func testTheWebsEqualGreysAreToldApartByPatternOrGlyph() {
        let bright = MonoToken.allCases.filter { $0.monoShade == 0xF2 }
        XCTAssertEqual(Set(bright), [.done, .grab, .edition, .danger])
        XCTAssertEqual(Set(bright.map(\.pattern)).count, 3)
        XCTAssertEqual(Set(bright.map(\.glyph)).count, 4)
    }

    func testRailStatesEachHaveTheirOwnMarker() {
        let states: [RailState] = [.owned, .wanted, .downloading, .upgrading, .upcoming]
        XCTAssertEqual(Set(states.map(\.monoToken)).count, states.count)
        XCTAssertEqual(RailState.partial.monoToken, RailState.wanted.monoToken)
    }

    func testCardStatusesEachHaveTheirOwnMarker() {
        XCTAssertEqual(Set(CardStatus.allCases.map(\.monoToken)).count, CardStatus.allCases.count)
    }

    func testTierChipsDifferByShade() {
        XCTAssertNotEqual(QualityTier.hd.monoShade, QualityTier.uhd.monoShade)
        XCTAssertEqual(QualityTier.hd.monoToken, .edition)
        XCTAssertEqual(QualityTier.uhd.monoToken, .grab)
    }

    func testWantedStatesDiffer() {
        let tokens = ["missing", "cutoff_unmet", "upcoming"].map(WantedStateToken.token)
        XCTAssertEqual(tokens, [.miss, .edition, .unaired])
        XCTAssertEqual(Set(tokens.map(\.pattern)).count, 3)
        XCTAssertEqual(WantedStateToken.token("whatever"), .done)
    }

    func testDenseIsTheOnlyThreePointTile() {
        XCTAssertEqual(MonoPattern.allCases.filter { $0.cell == 3 }, [.dense])
    }
}
