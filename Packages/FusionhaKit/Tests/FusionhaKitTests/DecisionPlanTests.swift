import XCTest
@testable import FusionhaKit

final class DecisionPlanTests: XCTestCase {
    func testAddsInOneVersion() {
        let t = RequestTriage(requestId: 1, versions: [.init(tier: .hd, configured: true, rootPath: "/mnt/plex/movies")])
        let s = DecisionPlan.sentence(title: "Burning", tiers: [.hd], triage: t, requester: "eafx", own: false)
        XCTAssertEqual(s.approve, "Approve adds Burning in HD-1080p to /mnt/plex/movies and searches now.")
        XCTAssertEqual(s.overrides, "Not yet tells eafx it isn’t available yet and keeps it on their list. Decline asks for a reason.")
        XCTAssertFalse(s.blocked)
    }

    func testTwoVersionsTwoRoots() {
        let t = RequestTriage(requestId: 1, versions: [
            .init(tier: .hd, configured: true, rootPath: "/movies"),
            .init(tier: .uhd, configured: true, rootPath: "/movies-4k"),
        ])
        let s = DecisionPlan.sentence(title: "Cure", tiers: [.hd, .uhd], triage: t, requester: "Sam Smith", own: false)
        XCTAssertEqual(s.approve, "Approve adds Cure in HD-1080p and UHD-2160p to /movies and /movies-4k and searches now.")
        XCTAssertTrue(s.overrides?.hasPrefix("Not yet tells Sam ") == true)
    }

    func testAlreadyTracked() {
        let t = RequestTriage(requestId: 1, versions: [.init(tier: .hd, configured: true, existing: true, rootPath: "/tv")])
        let s = DecisionPlan.sentence(title: "Chime", tiers: [.hd], triage: t, requester: "eafx", own: false)
        XCTAssertEqual(s.approve, "Approve monitors Chime in HD-1080p in /tv and searches now.")
    }

    func testMissingSetupBlocks() {
        let t = RequestTriage(requestId: 1, versions: [.init(tier: .uhd, configured: false)])
        let s = DecisionPlan.sentence(title: "Bound", tiers: [.uhd], triage: t, requester: "eafx", own: false)
        XCTAssertTrue(s.blocked)
        XCTAssertTrue(s.approve.hasPrefix("Approve needs an Add default for UHD-2160p"))
    }

    func testLoadingAndOwn() {
        XCTAssertTrue(DecisionPlan.sentence(title: "X", tiers: [.hd], triage: nil, requester: "a", own: false).blocked)
        let own = DecisionPlan.sentence(title: "X", tiers: [.hd], triage: nil, requester: "a", own: true)
        XCTAssertNil(own.overrides)
        XCTAssertEqual(own.approve, TriageFacts.ownRequestNote)
    }

    func testList() {
        XCTAssertEqual(DecisionPlan.list(["a", "b", "c"]), "a, b and c")
    }
}
