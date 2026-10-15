import XCTest
@testable import FusionhaKit

final class RequestLifecycleTests: XCTestCase {
    typealias E = RequestLifecycleEntry

    func testLeadIsTheMostAdvancedVersion() {
        let hd = E(tier: .hd, step: .downloading, progressPct: 40)
        let uhd = E(tier: .uhd, step: .searching)
        XCTAssertEqual(RequestLifecycle.lead([uhd, hd]), hd)
        let hd2 = E(tier: .hd, step: .downloading, progressPct: 80)
        XCTAssertEqual(RequestLifecycle.lead([hd, hd2]), hd2)
        XCTAssertEqual(RequestLifecycle.lagging([uhd, hd], lead: hd), [uhd])
    }

    func testStopLabelsAndWords() {
        let unreleased = E(tier: .hd, step: .unreleased, availableFrom: "2030-01-01")
        XCTAssertEqual(RequestLifecycle.stopIndex(.unreleased), 2)
        XCTAssertEqual(RequestLifecycle.stopLabel(2, entry: unreleased, auto: false), "Waiting")
        XCTAssertEqual(RequestLifecycle.stopLabel(1, entry: unreleased, auto: true), "Auto-approved")
        let importing = E(tier: .hd, step: .downloading, importing: true)
        XCTAssertEqual(RequestLifecycle.stopLabel(3, entry: importing, auto: false), "Importing")
        XCTAssertEqual(RequestLifecycle.versionWord(E(tier: .uhd, step: .downloading, needsManualImport: true)), "needs a manual import")
    }

    func testWash() {
        XCTAssertEqual(RequestLifecycle.wash(status: "rejected", lifecycle: []), .danger)
        XCTAssertEqual(RequestLifecycle.wash(status: "withdrawn", lifecycle: []), RequestLifecycle.Tone.none)
        let held = [E(tier: .hd, step: .available), E(tier: .uhd, step: .downloading, needsManualImport: true)]
        XCTAssertEqual(RequestLifecycle.wash(status: "approved", lifecycle: held), .attention)
        let partly = [E(tier: .hd, step: .available), E(tier: .uhd, step: .searching)]
        XCTAssertEqual(RequestLifecycle.wash(status: "approved", lifecycle: partly), .grab)
        XCTAssertEqual(RequestLifecycle.wash(status: "approved", lifecycle: [E(tier: .hd, step: .available)]), .done)
    }

    func testDaysUntilAndRelative() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = ISO8601DateFormatter().date(from: "2026-10-15T20:00:00Z")!
        XCTAssertEqual(RequestLifecycle.daysUntil("2026-10-18", now: now, calendar: cal), 3)
        XCTAssertEqual(RequestLifecycle.daysUntil("2026-10-01", now: now, calendar: cal), 0)
        XCTAssertEqual(RequestLifecycle.relativeFuture(now.addingTimeInterval(12 * 60), now: now), "in 12 min")
        XCTAssertEqual(RequestLifecycle.relativeFuture(now.addingTimeInterval(3 * 3600), now: now), "in 3 h")
    }

    func testDecodesARevampedRequest() throws {
        let json = #"""
        {"id":5,"tmdb_id":693134,"kind":"movie","tier":"UHD-2160p","tiers":["HD-1080p","UHD-2160p"],"seasons":[],"episodes":[],
         "status":"approved","title":"Dune: Part Two","year":2024,"quota_exceeded":false,"joined":false,"watch":false,"joiners":[],
         "requester":{"id":3,"display_name":"Sam"},"approved_by":{"kind":"auto","rule":"Under 20 GB"},
         "source":{"kind":"MANUAL"},"demand":{"count":3,"joined_by_me":false},"thread":{"unread":2},
         "lifecycle":[{"tier":"HD-1080p","step":"downloading","progress_pct":62,"needs_manual_import":false,"importing":false},
                      {"tier":"UHD-2160p","step":"something_new","needs_manual_import":false,"importing":false}]}
        """#
        let r = try APIClient.decoder.decode(MediaRequest.self, from: Data(json.utf8))
        XCTAssertEqual(r.lifecycle?.count, 2)
        XCTAssertEqual(r.lifecycle?[1].step, .requested)
        XCTAssertEqual(RequestLifecycle.autoText(r.approvedBy!), "Auto-approved · rule: Under 20 GB")
        XCTAssertEqual(RequestLifecycle.kindLabel(r), "Movie")
        XCTAssertEqual(RequestLifecycle.sourceText(r.source), "Requested in fusionha")
        let lead = RequestLifecycle.lead(r.lifecycle!)
        XCTAssertEqual(RequestLifecycle.statusLine(r, lead: lead!, lagging: []), .progress(62))
        XCTAssertTrue(RequestLifecycle.canWithdraw(r, lead: lead, viewerId: 3))
    }
}
