import XCTest
@testable import FusionhaKit

final class ApproveCostTests: XCTestCase {
    private let gib = 1024.0 * 1024 * 1024

    private func triage(estimate: Double?, free: Double?, existing: Bool = false) -> RequestTriage {
        RequestTriage(requestId: 1,
                      versions: [.init(tier: .hd, configured: true, existing: existing, rootPath: "/movies",
                                       estimateBytes: estimate)],
                      disks: [.init(rootPaths: ["/movies"], totalBytes: 1000 * gib, freeBytes: free)])
    }

    func testSizeFreeAndSearch() {
        let s = ApproveCost.sentence(title: "Burning", tiers: [.hd], triage: triage(estimate: 12 * gib, free: 500 * gib),
                                     search: true, requester: "eafx")
        XCTAssertEqual(s, "Adds Burning in HD-1080p, ~12 GB, leaving 488 GB free, and searches now. eafx is told.")
    }

    func testNoSearch() {
        let s = ApproveCost.sentence(title: "Burning", tiers: [.hd], triage: triage(estimate: 12 * gib, free: 500 * gib),
                                     search: false, requester: "Sam Smith")
        XCTAssertEqual(s, "Adds Burning in HD-1080p, ~12 GB, leaving 488 GB free. It doesn’t search yet. Sam is told.")
    }

    func testAddedVersionHasNoEstimate() {
        let s = ApproveCost.sentence(title: "Cure", tiers: [.hd, .uhd], triage: triage(estimate: 12 * gib, free: 500 * gib),
                                     search: true, requester: "eafx")
        XCTAssertEqual(s, "Adds Cure in HD-1080p and UHD-2160p and searches now. eafx is told.")
    }

    func testNotEnoughRoomAndTracked() {
        let s = ApproveCost.sentence(title: "Chime", tiers: [.hd], triage: triage(estimate: 12 * gib, free: 10 * gib, existing: true),
                                     search: true, requester: "eafx")
        XCTAssertEqual(s, "Monitors Chime in HD-1080p, ~12 GB, more than the 10 GB free, and searches now. eafx is told.")
    }

    func testNothingOn() {
        XCTAssertEqual(ApproveCost.sentence(title: "X", tiers: [], triage: nil, search: true, requester: "a"),
                       "Turn on a version to approve.")
    }

    func testAskedLine() {
        XCTAssertEqual(ApproveCost.askedLine(requester: "eafx", asked: [.hd]),
                       "eafx asked for HD only. Change anything here before it is added.")
        XCTAssertEqual(ApproveCost.askedLine(requester: "eafx", asked: [.hd, .uhd]),
                       "eafx asked for HD and 4K. Change anything here before it is added.")
    }
}
