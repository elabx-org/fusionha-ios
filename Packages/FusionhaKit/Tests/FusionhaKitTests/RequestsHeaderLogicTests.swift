import XCTest
@testable import FusionhaKit

final class RequestsHeaderLogicTests: XCTestCase {
    private func counts(active: Int = 0, available: Int = 0, declined: Int = 0, all: Int = 0, inbox: Int = 0, waiting: Int = 0) -> RequestCounts {
        let json = #"{"inbox":\#(inbox),"waiting":\#(waiting),"active":\#(active),"available":\#(available),"declined":\#(declined),"all":\#(all)}"#
        return try! APIClient.decoder.decode(RequestCounts.self, from: Data(json.utf8))
    }

    private func request(_ status: String, _ json: String = "") -> MediaRequest {
        let body = json.isEmpty ? "" : "," + json
        let raw = #"{"id":1,"tmdb_id":10,"kind":"movie","tier":"HD-1080p","status":""# + status + "\"" + body + "}"
        return try! APIClient.decoder.decode(MediaRequest.self, from: Data(raw.utf8))
    }

    private func entry(_ step: String, tier: String = "HD-1080p") -> String {
        #"{"tier":"\#(tier)","step":"\#(step)","needs_manual_import":false,"importing":false}"#
    }

    // MARK: Result label (filters.ts resultLabel)

    func testResultLabel() {
        XCTAssertEqual(RequestsResultLabel.text(9, loaded: 3, more: true, noun: ("request", "requests")), "Show 9 requests")
        XCTAssertEqual(RequestsResultLabel.text(1, loaded: 1, more: false, noun: ("request", "requests")), "Show 1 request")
        XCTAssertEqual(RequestsResultLabel.text(nil, loaded: 50, more: true, noun: ("thread", "threads")), "Show 50+ threads")
        XCTAssertEqual(RequestsResultLabel.text(nil, loaded: 1, more: true, noun: ("thread", "threads")), "Show 1+ threads")
        XCTAssertEqual(RequestsResultLabel.text(nil, loaded: 1, more: false, noun: ("issue", "issues")), "Show 1 issue")
        XCTAssertEqual(RequestsResultLabel.fallback, "Done")
    }

    // MARK: Mine header (mine-header.ts)

    func testMineSubtitle() {
        XCTAssertEqual(MineHeader.openCount(counts(active: 5, declined: 2)), 3)
        XCTAssertEqual(MineHeader.openCount(counts(active: 1, declined: 2)), 0)
        XCTAssertNil(MineHeader.openCount(nil))
        XCTAssertEqual(MineHeader.subtitle(counts(active: 5, available: 6, declined: 2), issues: false)?.text, "3 open · 6 available")
        XCTAssertEqual(MineHeader.subtitle(counts(active: 2, available: 6, declined: 2), issues: false), .nothingOpen)
        XCTAssertEqual(MineHeader.subtitle(nil, issues: true)?.text, "Issues you reported")
        XCTAssertNil(MineHeader.subtitle(nil, issues: false))
    }

    // MARK: History

    func testHistoryCount() {
        let c = counts(available: 28, declined: 2, all: 40, inbox: 9, waiting: 1)
        XCTAssertEqual(RequestHistoryCount.count(c, status: .all), 30)
        XCTAssertEqual(RequestHistoryCount.count(c, status: .approved), 28)
        XCTAssertEqual(RequestHistoryCount.count(c, status: .available), 28)
        XCTAssertEqual(RequestHistoryCount.count(c, status: .declined), 2)
        XCTAssertNil(RequestHistoryCount.count(c, status: .auto))
        XCTAssertNil(RequestHistoryCount.count(nil, status: .all))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(RequestHistoryCount.monthWindow(now: ServerTime.parse("2026-10-19T12:00:00Z")!, calendar: cal), 19)
    }

    func testHistoryStatusWord() {
        XCTAssertEqual(RequestHistoryStatus.word(request("rejected")).label, "Declined")
        XCTAssertEqual(RequestHistoryStatus.word(request("fulfilled")).tone, .done)
        let deferred = RequestHistoryStatus.word(request("deferred"))
        XCTAssertEqual(deferred.label, "Not available yet")
        XCTAssertEqual(deferred.tone, .quiet(.attention))
        let downloading = RequestHistoryStatus.word(request("approved", #""lifecycle":[\#(entry("downloading"))]"#))
        XCTAssertEqual(downloading.label, "Downloading")
        XCTAssertEqual(downloading.tone, .step(.grab))
        let unreleased = RequestHistoryStatus.word(request("approved", #""lifecycle":[\#(entry("unreleased"))]"#))
        XCTAssertEqual(unreleased.tone, .step(.unaired))
        // An approved version with nothing started reads Approved, never its step.
        let approved = RequestHistoryStatus.word(request("approved", #""lifecycle":[\#(entry("approved"))]"#))
        XCTAssertEqual(approved.label, "Approved")
        XCTAssertEqual(approved.tone, .accent)
        // A landed lead with nothing else moving must not read "Available".
        let landed = RequestHistoryStatus.word(request("approved", #""lifecycle":[\#(entry("available"))]"#))
        XCTAssertEqual(landed.label, "Approved")
        let auto = RequestHistoryStatus.word(request("approved", #""approved_by":{"kind":"auto"}"#))
        XCTAssertEqual(auto.label, "Auto-approved")
    }

    // MARK: Threads and issues

    func testUnreadThreadsAndProblemFilter() throws {
        let json = #"[{"type":"request","id":1,"request":{"id":1,"tmdb_id":1,"kind":"movie","tier":"HD-1080p","status":"pending","thread":{"unread":2}}},{"type":"request","id":2,"request":{"id":2,"tmdb_id":2,"kind":"movie","tier":"HD-1080p","status":"pending"}}]"#
        let items = try APIClient.decoder.decode([ThreadItem].self, from: Data(json.utf8))
        XCTAssertEqual(ThreadUnread.count(items), items.filter(ThreadMeta.hasUnread).count)
        XCTAssertEqual(ThreadUnread.label(4, more: true), "4+")
        XCTAssertEqual(ThreadUnread.label(4, more: false), "4")
        XCTAssertNil(ThreadUnread.label(0, more: true))
        XCTAssertTrue(IssueProblemFilter.matches(items[0], problem: "all"))
        XCTAssertFalse(IssueProblemFilter.matches(items[0], problem: "WONT_PLAY"))
        XCTAssertEqual(IssueProblemFilter.label("LANGUAGE"), "Wrong language")
    }

    // MARK: Insights and Mine source

    func testInsightsRangeAndSourceChip() {
        XCTAssertEqual(InsightsRange.options, [4, 12, 26])
        XCTAssertEqual(InsightsRange.label(26), "Last 26 weeks")
        XCTAssertEqual(RequestSourceFilter(provider: .all).chipLabel, "All automatic")
        XCTAssertEqual(RequestSourceFilter(provider: .plex).chipLabel, "Plex")
        let diary = RequestSourceFilter.Sub(RequestSourceCount(kind: "LETTERBOXD_RSS", count: 3))
        XCTAssertEqual(RequestSourceFilter(provider: .letterboxd, sub: diary).chipLabel, "Diary")
        let list = RequestSourceFilter.Sub(RequestSourceCount(kind: "PLEX_LIST", label: "Weekend", sourceId: 4, count: 1))
        XCTAssertEqual(RequestSourceFilter(provider: .plex, sub: list).chipLabel, "List · Weekend")
    }
}
