import XCTest
@testable import FusionhaKit

final class CalendarRailsTests: XCTestCase {
    private func owned(_ tier: QualityTier) -> (QualityTier, Rail) {
        (tier, Rail(state: .owned, progress: 100, fraction: nil, attention: false, deadLinkOnly: false))
    }

    func testConsolidatesOnlyCompletePairs() {
        let pair = [owned(.hd), owned(.uhd)]
        XCTAssertEqual(CalendarRails.units(pair, consolidate: false, comboFraction: nil).count, 2)
        let folded = CalendarRails.units(pair, consolidate: true, comboFraction: "6/6")
        XCTAssertEqual(folded.count, 1)
        XCTAssertTrue(folded[0].combo)
        XCTAssertEqual(folded[0].rail.fraction, "6/6")

        let wanted = (QualityTier.uhd, Rail(state: .wanted, progress: 0, fraction: nil, attention: false, deadLinkOnly: false))
        XCTAssertEqual(CalendarRails.units([owned(.hd), wanted], consolidate: true, comboFraction: nil).map(\.combo), [false, false])
    }

    func testSeasonStates() {
        let partial = CalendarRails.rail(season: SeasonTierAggregate(tier: .hd, done: 2, total: 3, grabbing: 0), upcoming: false)
        XCTAssertEqual(partial.state, .partial)
        XCTAssertEqual(partial.fraction, "2/3")
        XCTAssertEqual(partial.progress, 67)
        let soon = CalendarRails.rail(season: SeasonTierAggregate(tier: .hd, done: 0, total: 3, grabbing: 0), upcoming: true)
        XCTAssertEqual(soon.state, .upcoming)
        let grabbing = CalendarRails.rail(season: SeasonTierAggregate(tier: .uhd, done: 1, total: 3, grabbing: 1), upcoming: false)
        XCTAssertEqual(grabbing.state, .downloading)
    }
}
