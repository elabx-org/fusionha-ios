import XCTest
@testable import FusionhaKit

final class QueuePackDecisionsTests: XCTestCase {
    func testSummaryTextSkipsZeroParts() {
        let s = QueuePackSummary(imported: 0, ready: 9, held: 3, owned: 1, unmatched: 0)
        XCTAssertEqual(s.text, "9 import-ready · 3 held · 1 already owned")
        XCTAssertNil(QueuePackSummary(imported: 0, ready: 0, held: 0, owned: 0, unmatched: 0).text)
    }

    func testRunLabels() {
        XCTAssertEqual(PackDecisions.shortLabel("S02E03"), "E03")
        XCTAssertEqual(PackDecisions.shortLabel("001"), "001")
        XCTAssertEqual(PackDecisions.runLabel("S02E01", "S02E09"), "E01–E09")
        XCTAssertEqual(PackDecisions.runLabel("S02E10", "S02E10"), "E10")
        let r = QueuePackOutcomeRange(outcome: .ready, startLabel: "S02E01", endLabel: "S02E09", count: 9)
        XCTAssertEqual(r.text, "E01–E09 import-ready")
    }

    func testDecodesOutcomesAndUnknownFallsBack() throws {
        let json = #"""
        [{"outcome":"held","start_label":"S01E03","end_label":"S01E05","count":3},
         {"outcome":"something_new","start_label":"S01E06","end_label":"S01E06","count":1}]
        """#
        let ranges = try APIClient.decoder.decode([QueuePackOutcomeRange].self, from: Data(json.utf8))
        XCTAssertEqual(ranges.map(\.outcome), [.held, .unmatched])
        XCTAssertEqual(ranges[0].outcome.style, .hold)
    }

    func testMixedResolutionBreakdown() throws {
        let json = #"""
        {"resolution":["720p","1080p"],"codec":null,"hdr":null,
         "breakdown":[
           {"fact":"resolution","value":"1080p","count":10,"episodes":[{"start_label":"S01E01","end_label":"S01E02","count":2},{"start_label":"S01E06","end_label":"S01E13","count":8}],"probe":"1920×1080"},
           {"fact":"resolution","value":"720p","count":3,"episodes":[{"start_label":"S01E03","end_label":"S01E05","count":3}],"probe":"1280×720"}]}
        """#
        let mixed = try APIClient.decoder.decode(QueuePackMixed.self, from: Data(json.utf8))
        let facts = PackDecisions.mixedFacts(mixed, parsed: nil)
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts[0].text, "1080p · Mixed")
        XCTAssertEqual(facts[0].detail, "Mixed inside this pack: E03–E05 probe 1280×720, the other 10 probe 1920×1080")
        XCTAssertEqual(facts[0].accessibilityLabel, "Mixed inside this pack (720p, 1080p)")
    }

    func testUniformPackHasNoMixedFacts() {
        let mixed = QueuePackMixed(resolution: ["1080p"], codec: nil, hdr: nil, breakdown: [])
        XCTAssertTrue(PackDecisions.mixedFacts(mixed, parsed: nil).isEmpty)
        XCTAssertTrue(PackDecisions.mixedFacts(nil, parsed: nil).isEmpty)
    }
}
