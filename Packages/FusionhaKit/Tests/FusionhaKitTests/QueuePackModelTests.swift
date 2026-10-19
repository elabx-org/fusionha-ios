import XCTest
@testable import FusionhaKit

final class QueuePackModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func ranges() throws -> QueuePackRanges {
        try decode(QueuePackRanges.self, #"""
        {"done": {"start_label": "S03E01", "end_label": "S03E04", "count": 4},
         "current": {"start_label": "S03E05", "end_label": "S03E05", "count": 1},
         "waiting": {"start_label": "S03E06", "end_label": "S03E13", "count": 8}}
        """#)
    }

    func testLinkingHeadlineThenAndSummary() throws {
        let stages = try decode(QueueStages.self, #"""
        {"mode": "phase", "current": "linking", "linking_done": 4, "linking_total": 13,
         "steps": [{"key": "queued", "runs": true}, {"key": "linking", "runs": true},
                   {"key": "caching", "runs": true}, {"key": "probing", "runs": false},
                   {"key": "validating", "runs": true}, {"key": "complete", "runs": true}]}
        """#)
        let m = QueuePackModel(fileCount: 13, ranges: try ranges(), stages: stages)
        XCTAssertEqual(m.headline, "Linking 4 of 13")
        XCTAssertEqual(m.then, "then caching and validating")
        XCTAssertEqual(m.summary, "S03E01–S03E04 ✓ · S03E05 · S03E06–S03E13")
        XCTAssertFalse(m.decided)
        XCTAssertEqual(m.ranges.map(\.kind), [.done, .current, .waiting])
        XCTAssertEqual(m.fraction, 4.0 / 13, accuracy: 0.0001)
    }

    func testHeadlineWithoutLinkingCount() throws {
        XCTAssertEqual(QueuePackModel(fileCount: 13, ranges: try ranges(), stages: nil).headline, "4 of 13 files linked")
        let none = try decode(QueuePackRanges.self, #"{"waiting": {"start_label": "001", "end_label": "012", "count": 12}}"#)
        let waiting = QueuePackModel(fileCount: 12, ranges: none, stages: nil)
        XCTAssertEqual(waiting.headline, "12 files waiting")
        XCTAssertEqual(waiting.absoluteWidth, 3)
        let all = try decode(QueuePackRanges.self, #"{"done": {"start_label": "001", "end_label": "012", "count": 12}}"#)
        XCTAssertEqual(QueuePackModel(fileCount: 12, ranges: all, stages: nil).headline, "12 files linked")
    }

    func testDecidedUsesOutcomeRuns() throws {
        let summary = QueuePackSummary(imported: 0, ready: 9, held: 3, owned: 1, unmatched: 0)
        let runs = [QueuePackOutcomeRange(outcome: .ready, startLabel: "S01E01", endLabel: "S01E09", count: 9),
                    QueuePackOutcomeRange(outcome: .held, startLabel: "S01E10", endLabel: "S01E12", count: 3)]
        let m = QueuePackModel(fileCount: 13, ranges: try ranges(), stages: nil, summary: summary, outcomeRanges: runs)
        XCTAssertTrue(m.decided)
        XCTAssertNil(m.then)
        XCTAssertEqual(m.summary, "9 import-ready · 3 held · 1 already owned")
        XCTAssertEqual(m.ranges.map(\.kind), [.outcome(.ready), .outcome(.held)])
        XCTAssertEqual(m.ranges[0].kind.label, "Import-ready")
    }

    func testSplitAndEpisodeLabels() throws {
        let m = QueuePackModel(fileCount: 13, ranges: try ranges(), stages: nil)
        let eps = try decode([QueuePackEpisode].self, "[" + (1...13).map {
            #"{"episode_id": \#($0), "season": 3, "episode": \#($0), "absolute": \#($0 + 20)}"#
        }.joined(separator: ",") + "]")
        let groups = m.split(eps)
        XCTAssertEqual(groups.map(\.count), [4, 1, 8])
        XCTAssertEqual(groups[1].first?.episode, 5)
        XCTAssertEqual(QueuePackModel.episodeLabel(eps[0], absoluteWidth: nil), "S03E01")
        XCTAssertEqual(QueuePackModel.episodeLabel(eps[0], absoluteWidth: 3), "021")
        XCTAssertEqual(m.split(Array(eps.prefix(2))).map(\.count), [2, 0, 0])
    }

    func testStageLabel() {
        XCTAssertEqual(QueueStageLabel.label("validating"), "Validating")
        XCTAssertEqual(QueueStageLabel.label("weird"), "Weird")
        XCTAssertEqual(QueueStageLabel.label(nil), "Working")
    }

    func testMislabelFacts() throws {
        let d = try decode(HeldDetail.self, #"""
        {"kind": "mislabeled_resolution", "claimed_quality": "WEBDL-1080p", "release_group": "TSRG",
         "probed_resolution": {"w": 640, "h": 480}, "probed_resolution_bucket": 480, "claimed_resolution": 1080,
         "mislabeled": true, "current_quality": "Bluray-1080p", "current_group": "FUZ", "current_cf": -9245,
         "current_formats": ["A", "B", "C", "D"], "candidate_cf": 1075}
        """#)
        let rows = MislabelFacts.rows(d, indexer: "NZBgeek")
        XCTAssertEqual(rows.map(\.label), ["Release says", "Measured", "On disk now", "Release CF", "Outcome"])
        XCTAssertEqual(rows[0].value, "WEBDL-1080p · group TSRG · NZBgeek")
        XCTAssertEqual(rows[1].value, "640×480 (480p, 4:3) · probed after download")
        XCTAssertEqual(rows[2].value, "Bluray-1080p · FUZ · CF −9245 (matches A, B, C +1 more)")
        XCTAssertTrue(rows[3].value.hasPrefix("+1075, "))
        XCTAssertEqual(rows[4].value, "Not imported. Your existing file is untouched.")
        XCTAssertEqual(MislabelFacts.aspectRatio(w: 1920, h: 1080), "16:9")
        XCTAssertNil(MislabelFacts.aspectRatio(w: 1000, h: 1000))
        XCTAssertEqual(MislabelFacts.proofSentence(group: "TSRG", count: 1), "TSRG has now mislabelled 1 release here.")
    }
}
