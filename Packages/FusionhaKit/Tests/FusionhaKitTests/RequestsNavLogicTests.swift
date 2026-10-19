import XCTest
@testable import FusionhaKit

final class RequestsNavLogicTests: XCTestCase {
    private func request(id: Int = 1, _ json: String = "") -> MediaRequest {
        let base = #"{"tmdb_id":10,"kind":"movie","tier":"HD-1080p","status":"rejected","id":"# + "\(id)"
        let body = json.isEmpty ? "" : "," + json
        return try! APIClient.decoder.decode(MediaRequest.self, from: Data((base + body + "}").utf8))
    }

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ iso: String) -> Date { ServerTime.parse(iso)! }

    // MARK: Origin

    func testOriginQueryIsStableAndUsesTheServerAliases() {
        XCTAssertEqual(RequestOrigin.query([]), [])
        XCTAssertEqual(RequestOrigin.query([.letterboxd, .manual]).first?.value, "MANUAL,letterboxd")
        XCTAssertEqual(RequestOrigin.query([.plex]).first?.name, "source")
    }

    func testOriginOfKinds() {
        XCTAssertEqual(RequestOrigin.of(nil), .manual)
        XCTAssertEqual(RequestOrigin.of("MANUAL"), .manual)
        XCTAssertEqual(RequestOrigin.of("PLEX_LIST"), .plex)
        XCTAssertEqual(RequestOrigin.of("LETTERBOXD_RSS"), .letterboxd)
        XCTAssertNil(RequestOrigin.of("LIST_FEED"))
    }

    func testOriginWord() {
        XCTAssertEqual(RequestOrigin.word(nil), "Manual")
        let r = request(#""source":{"kind":"LETTERBOXD_WATCHLIST"}"#)
        XCTAssertEqual(RequestOrigin.word(r.source), "Letterboxd")
    }

    // MARK: History days

    func testDayTitles() {
        let now = date("2026-10-18T15:00:00Z")
        XCTAssertEqual(RequestHistoryDays.title(date("2026-10-18T01:00:00Z"), now: now, calendar: utc), "Today")
        XCTAssertEqual(RequestHistoryDays.title(date("2026-10-17T23:00:00Z"), now: now, calendar: utc), "Yesterday")
        XCTAssertEqual(RequestHistoryDays.title(date("2026-10-09T10:00:00Z"), now: now, calendar: utc), "Earlier this month")
        XCTAssertEqual(RequestHistoryDays.title(date("2026-09-30T10:00:00Z"), now: now, calendar: utc), "September")
        XCTAssertEqual(RequestHistoryDays.title(date("2025-12-01T10:00:00Z"), now: now, calendar: utc), "December 2025")
        XCTAssertEqual(RequestHistoryDays.title(nil, now: now, calendar: utc), "Earlier")
    }

    func testGroupKeepsServerOrderAndPrefersTheDecision() {
        let now = date("2026-10-18T15:00:00Z")
        let rows = [
            request(id: 1, #""decided_at":"2026-10-18T13:00:00","requested_at":"2026-10-01T10:00:00""#),
            request(id: 2, #""decided_at":"2026-10-17T18:40:00""#),
            request(id: 3, #""decided_at":"2026-10-18T09:00:00""#),
            request(id: 4, #""requested_at":"2026-10-09T10:00:00""#),
        ]
        let groups = RequestHistoryDays.group(rows, now: now, calendar: utc)
        XCTAssertEqual(groups.map(\.title), ["Today", "Yesterday", "Earlier this month"])
        XCTAssertEqual(groups[0].ids, [1, 3])
        XCTAssertEqual(groups[2].ids, [4])
    }

    func testTimes() {
        let now = date("2026-10-18T15:00:00Z")
        XCTAssertEqual(RequestHistoryDays.time(date("2026-10-18T13:00:00Z"), now: now, calendar: utc), "2h")
        XCTAssertEqual(RequestHistoryDays.time(date("2026-10-18T14:55:00Z"), now: now, calendar: utc), "5m")
        XCTAssertEqual(RequestHistoryDays.time(date("2026-10-17T18:40:00Z"), now: now, calendar: utc), "18:40")
        XCTAssertEqual(RequestHistoryDays.time(date("2026-10-09T10:00:00Z"), now: now, calendar: utc), "Oct 9")
        XCTAssertEqual(RequestHistoryDays.time(nil, now: now, calendar: utc), "")
    }

    // MARK: Board summary

    func testSummaryNamesOnlyWhatNeedsTheApproverAndIsNeverBlank() {
        func words(_ p: [RequestBoardSummary.Part]) -> [String] { p.map { ($0.count.map { "\($0) " } ?? "") + $0.text } }
        XCTAssertEqual(words(RequestBoardSummary.parts(pending: 9, downloading: 1, available: 28)), ["9 pending", "1 downloading"])
        XCTAssertEqual(words(RequestBoardSummary.parts(pending: 9, downloading: 0, available: 28)), ["9 pending"])
        XCTAssertEqual(words(RequestBoardSummary.parts(pending: 0, downloading: 2, available: 0)), ["2 downloading"])
        XCTAssertEqual(words(RequestBoardSummary.parts(pending: 0, downloading: 0, available: 28)), ["Nothing waiting", "28 available"])
        XCTAssertEqual(RequestBoardSummary.parts(pending: 0, downloading: 0, available: 28).last?.column, .available)
        XCTAssertEqual(words(RequestBoardSummary.parts(pending: 0, downloading: 0, available: 0)), ["No requests yet"])
    }

    // MARK: 0.4.216

    func testTimeLeft() {
        XCTAssertNil(DownloadTimeLeft.text(nil))
        XCTAssertEqual(DownloadTimeLeft.text(30), "less than a minute left")
        XCTAssertEqual(DownloadTimeLeft.text(720), "about 12 min left")
        XCTAssertEqual(DownloadTimeLeft.text(5400), "about 1.5 h left")
        XCTAssertEqual(DownloadTimeLeft.text(7200), "about 2 h left")
        XCTAssertEqual(DownloadTimeLeft.text(50000), "about 14 h left")
    }

    func testLifecycleEtaAndThreadLastMessageDecode() throws {
        let r = request(#""lifecycle":[{"tier":"HD-1080p","step":"downloading","progress_pct":62,"needs_manual_import":false,"importing":false,"eta_seconds":720}]"#)
        XCTAssertEqual(r.lifecycle?.first?.etaSeconds, 720)
        let json = #"{"type":"request","id":5,"title":"Chime","last_message":{"author_name":"Sam","author_kind":"user","text":"Can this be 4K as well?","at":"2026-10-19T05:00:00"}}"#
        let item = try APIClient.decoder.decode(ThreadItem.self, from: Data(json.utf8))
        XCTAssertEqual(item.lastMessage?.line, "Sam: Can this be 4K as well?")
        let bare = try APIClient.decoder.decode(ThreadLastMessage.self, from: Data(#"{"text":"Hello","at":"2026-10-19T05:00:00"}"#.utf8))
        XCTAssertEqual(bare.line, "Hello")
    }

    // MARK: Stage facts

    func testSharedRequester() {
        let a = request(id: 1, #""requester":{"id":3,"display_name":"eafx"}"#)
        let b = request(id: 2, #""requester":{"id":3,"display_name":"eafx"}"#)
        let c = request(id: 3, #""requester":{"id":4,"display_name":"priya"}"#)
        XCTAssertEqual(RequestStageFacts.sharedRequester([a, b]), "eafx")
        XCTAssertNil(RequestStageFacts.sharedRequester([a, c]))
        XCTAssertNil(RequestStageFacts.sharedRequester([a]))
        XCTAssertNil(RequestStageFacts.sharedRequester([]))
    }
}
