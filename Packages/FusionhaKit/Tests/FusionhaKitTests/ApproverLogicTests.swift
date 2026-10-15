import XCTest
@testable import FusionhaKit

final class ApproverLogicTests: XCTestCase {
    private func request(id: Int = 1, status: String = "pending", _ json: String) -> MediaRequest {
        let base = #"{"tmdb_id":10,"kind":"series","tier":"HD-1080p","id":"# + "\(id),\"status\":\"\(status)\""
        let body = json.isEmpty ? "" : "," + json
        return try! APIClient.decoder.decode(MediaRequest.self, from: Data((base + body + "}").utf8))
    }

    // MARK: Triage

    func testDecodesTriage() throws {
        let json = #"[{"request_id":5,"track_record":{"requests_30d":3,"approved_30d":3,"declined_30d":0,"trusted":true},"demand":{"count":2,"people":[]},"versions":[{"tier":"HD-1080p","configured":true,"root_path":"/tv","profile_name":"HD","estimate_bytes":4294967296}],"disks":[{"root_paths":["/tv"],"total_bytes":1099511627776,"free_bytes":549755813888,"needed_bytes":4294967296,"free_after_bytes":545460846592}],"low_space":false,"four_k":{"state":"unseen"},"release":{"state":"out","label":"Out now"}}]"#
        let rows = try APIClient.decoder.decode([RequestTriage].self, from: Data(json.utf8))
        let t = try XCTUnwrap(rows.first)
        XCTAssertEqual(t.trackRecord.requests30d, 3)
        XCTAssertTrue(t.trackRecord.trusted)
        XCTAssertEqual(TriageFacts.size(t).value, "~4 GB")
        XCTAssertEqual(TriageFacts.freeAfter(t).value, "508 GB")
        XCTAssertEqual(TriageFacts.freeAfter(t).of, "of 1 TB")
        XCTAssertEqual(TriageFacts.fourK(t).tile.value, "Not yet")
        XCTAssertTrue(TriageFacts.fourK(t).checkable)
        XCTAssertEqual(TriageFacts.release(t).short, "Out now")
        XCTAssertEqual(TriageFacts.demandText(t, ownerName: "Sam Smith"), "2 people want this")
        XCTAssertEqual(TriageFacts.trackLine(t), "3 requests · 0 declined")
        XCTAssertEqual(TriageFacts.trackBadge(t, role: "Friend")?.label, "Trusted")
        XCTAssertFalse(TriageFacts.setupMissing(t))
    }

    func testLowSpaceAndMissingSetup() {
        let disk = RequestTriage.Disk(rootPaths: ["/movies"], totalBytes: 100, freeBytes: 10, neededBytes: 50, freeAfterBytes: -40)
        let t = RequestTriage(requestId: 1, versions: [.init(tier: .uhd, configured: false)], disks: [disk], lowSpace: true)
        XCTAssertEqual(TriageFacts.freeAfter(t).value, "Not enough space")
        XCTAssertEqual(TriageFacts.freeAfter(t).tone, .warn)
        XCTAssertEqual(TriageFacts.lowSpaceMessage(t), "Not enough space on /movies — needs ~50 B, 10 B free.")
        XCTAssertTrue(TriageFacts.setupMissing(t))
        XCTAssertEqual(TriageFacts.bulkLowSpace([1: t, 2: t], ids: [1, 2]), "Not enough space on /movies for all 2.")
    }

    func testAgesAndLabels() {
        let now = ServerTime.parse("2026-10-15T12:00:00")!
        XCTAssertEqual(TriageFacts.compactAge("2026-10-15T11:48:00", now: now), "12 m")
        XCTAssertEqual(TriageFacts.compactAge("2026-10-13T12:00:00", now: now), "2 d")
        XCTAssertEqual(TriageFacts.compactAge(nil, now: now), "")
        XCTAssertEqual(TriageFacts.approveLabel([.hd, .uhd]), "Approve HD + 4K")
        XCTAssertEqual(TriageFacts.shortDay("2026-11-03"), "3 Nov")
        XCTAssertEqual(TriageFacts.bulkFailureText(["withdrawn", "not_rejectable", "withdrawn", nil]),
                       "2 withdrawn · 1 already decided · 1 couldn’t be decided")
        XCTAssertEqual(TriageFacts.failureMessage(code: nil, status: 422), "Set up Add defaults for this kind and tier in Settings first.")
    }

    // MARK: Scope

    func testScopeWords() {
        let r = request(#""seasons":[1,2,4],"episodes":[{"season":5,"episode":3},{"season":5,"episode":2}]"#)
        XCTAssertEqual(RequestScope.head(r), "Seasons 1–2, 4 · Season 5 from E2")
        XCTAssertEqual(RequestScope.chip(r), "S01–S02, S04, S05·E2+")
        XCTAssertEqual(RequestScope.copy(r, existing: nil)?.lead, "Requested Seasons 1–2, 4 · Season 5")
        let fresh = RequestScope.copy(r, existing: .init(monitored: [], unmonitored: []))
        XCTAssertEqual(fresh?.lead, "Monitors Seasons 1–2, 4 · Season 5 from E2")
        XCTAssertTrue(fresh?.later == true)
        let widen = RequestScope.copy(r, existing: .init(monitored: [.hd], unmonitored: []), requested: [.hd])
        XCTAssertEqual(widen?.text, "Adds Seasons 1–2, 4 · Season 5 to the existing HD·1080p version")
        XCTAssertNil(RequestScope.copy(request(#""seasons":[]"#), existing: nil))
    }

    // MARK: Board

    func testColumnsAndMerge() {
        let pending = request(#""requested_at":"2026-10-15T10:00:00""#)
        let downloading = request(id: 2, status: "approved", #""lifecycle":[{"tier":"HD-1080p","step":"downloading","needs_manual_import":false,"importing":false}],"thread":{"unread":0,"last_event_at":"2026-10-15T11:00:00"}"#)
        let waiting = request(id: 3, status: "waiting", #""requested_at":"2026-10-15T12:00:00""#)
        XCTAssertEqual(RequestBoard.column(pending), .pending)
        XCTAssertEqual(RequestBoard.column(downloading), .downloading)
        XCTAssertNil(RequestBoard.column(request(status: "withdrawn", "")))
        let merged = RequestBoard.merge([.pending: [pending, waiting], .active: [downloading]])
        XCTAssertEqual(merged.map(\.id), [3, 2, 1])
        XCTAssertEqual(RequestBoard.group(merged)[.pending]?.map(\.id), [1, 3])
    }

    func testTimeToAvailableAndPill() {
        let r = request(status: "fulfilled", #""requested_at":"2026-10-15T10:00:00","available_at":"2026-10-15T12:05:00""#)
        XCTAssertEqual(RequestBoard.timeToAvailable(r), "2h 05m")
        XCTAssertEqual(RequestBoard.historyPill(r).label, "Available")
        XCTAssertEqual(RequestBoard.countLabel(30, exact: false), "30+")
        XCTAssertNil(HistoryFilter.approved.query(search: nil).filter)
    }
}
