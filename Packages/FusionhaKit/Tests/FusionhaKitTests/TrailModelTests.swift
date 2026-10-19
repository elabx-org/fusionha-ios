import XCTest
@testable import FusionhaKit

final class TrailModelTests: XCTestCase {
    private func candidate(action: String, quality: String? = "WEBDL_1080P", score: Int = 500,
                           reason: String = "") throws -> RunCandidate {
        let quality = quality.map { "\"\($0)\"" } ?? "null"
        let json = #"{"id": 1, "release_title": "X", "quality": \#(quality), "cf_score": \#(score), "matched": [{"name": "HDR", "score": 400}, {"name": "x265", "score": -100}], "version_id": 9, "action": "\#(action)", "reason": "\#(reason)"}"#
        return try APIClient.decoder.decode(RunCandidate.self, from: Data(json.utf8))
    }

    private let profile = TrailProfile(id: 1, floor: 0, ceiling: 1000, cutoffQuality: "BLURAY_1080P",
                                       upgradeAllowed: true, allowed: ["WEBDL_1080P", "BLURAY_1080P"])

    func testDecodesMatched() throws {
        let c = try candidate(action: "GRAB")
        XCTAssertEqual(c.matched?.count, 2)
        XCTAssertEqual(c.versionId, 9)
    }

    func testGrabChain() throws {
        let c = try candidate(action: "GRAB", reason: "No file for this version yet")
        let keys = TrailModel.chain(c, profile: profile, considered: 4).map(\.key)
        XCTAssertEqual(keys, ["quality", "first", "floor", "best", "upgrade"])
    }

    func testRejectChain() throws {
        let c = try candidate(action: "REJECT", quality: "SDTV", score: -50, reason: "Below minimum")
        let steps = TrailModel.chain(c, profile: profile, considered: 4)
        XCTAssertEqual(steps.map(\.key), ["quality", "floor", "lost"])
        XCTAssertTrue(steps.allSatisfy { $0.state == .no })
        XCTAssertEqual(steps.last?.text, "Below minimum")
    }

    func testNoProfileStillExplainsLoss() throws {
        let c = try candidate(action: "SKIP")
        XCTAssertEqual(TrailModel.chain(c, profile: nil, considered: 1).map(\.text), ["Passed over"])
    }

    func testTrackAndLabels() {
        XCTAssertEqual(TrailModel.track(total: 1500, profile: profile)?.totalPct, 100)
        XCTAssertEqual(TrailModel.track(total: 250, profile: profile)?.totalPct, 25)
        XCTAssertEqual(TrailModel.signed(5), "+5")
        XCTAssertEqual(TrailModel.signed(-5), "-5")
        XCTAssertEqual(TrailModel.verdictLabel("UPGRADE"), "Upgraded")
        XCTAssertEqual(TrailModel.tier(forQuality: "WEBDL_2160P"), .uhd)
        XCTAssertEqual(TrailModel.tier(forQuality: nil), .hd)
    }
}
