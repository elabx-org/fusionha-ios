import XCTest
@testable import FusionhaKit

/// The widget extension's guards: timeouts, bounded fetches, the streamed
/// library tally, the run log and the Indexers page's one-row-per-indexer rule.
final class WidgetRobustnessTests: XCTestCase {
    func testTimeoutReturnsValueInTime() async throws {
        let value = try await withTimeout(seconds: 2) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testTimeoutFiresEvenWhenTheWorkIgnoresCancellation() async {
        let started = Date()
        do {
            _ = try await withTimeout(seconds: 0.2) {
                // A detached sleep ignores the timeout's cancellation.
                await Task.detached { try? await Task.sleep(nanoseconds: 3_000_000_000) }.value
                return 1
            }
            XCTFail("expected a timeout")
        } catch {
            XCTAssertEqual(error as? WidgetTimedOut, WidgetTimedOut(seconds: 0.2))
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
    }

    func testTimeoutPassesErrorsThrough() async {
        do {
            _ = try await withTimeout(seconds: 2) { () async throws -> Int in throw APIError.notSignedIn }
            XCTFail("expected an error")
        } catch {
            XCTAssertEqual(WidgetRunLog.describe(error), "signed out")
        }
    }

    func testDeadlineSlices() {
        let now = Date()
        let deadline = WidgetDeadline(seconds: 8, from: now)
        XCTAssertEqual(deadline.slice(4, now: now), 4)
        XCTAssertEqual(deadline.slice(4, reserve: 6, now: now), 2)
        XCTAssertEqual(deadline.slice(4, now: now.addingTimeInterval(9)), 0.25)
        XCTAssertEqual(deadline.remaining(now: now.addingTimeInterval(9)), 0)
    }

    func testConcurrentMapKeepsOrderAndBound() async {
        let gauge = Gauge()
        let out = await concurrentMap(Array(0..<12), maxConcurrent: 3) { n -> Int in
            await gauge.enter()
            try? await Task.sleep(nanoseconds: UInt64((12 - n) * 2_000_000))
            await gauge.leave()
            return n * 10
        }
        XCTAssertEqual(out, (0..<12).map { $0 * 10 })
        let peak = await gauge.peak
        XCTAssertLessThanOrEqual(peak, 3)
        let empty = await concurrentMap([Int](), maxConcurrent: 3) { $0 }
        XCTAssertEqual(empty, [])
    }

    func testJSONArrayElements() throws {
        var parts: [String] = []
        let json = #" [ {"a":"x,]}","b":[1,{"c":2}]} , 3 ,"q\"]" , null ] "#
        try WidgetJSONArray.forEachElement(in: Data(json.utf8)) { parts.append(String(decoding: $0, as: UTF8.self)) }
        XCTAssertEqual(parts, [#"{"a":"x,]}","b":[1,{"c":2}]}"#, "3", #""q\"]""#, "null"])
        var none = 0
        try WidgetJSONArray.forEachElement(in: Data("[]".utf8)) { _ in none += 1 }
        XCTAssertEqual(none, 0)
        XCTAssertThrowsError(try WidgetJSONArray.forEachElement(in: Data("{}".utf8)) { _ in })
        XCTAssertThrowsError(try WidgetJSONArray.forEachElement(in: Data("[{\"a\":1}".utf8)) { _ in })
    }

    func testStreamedLibraryTallyMatchesTheFullDecode() throws {
        // The server emits each version under both `versions` and `editions` for now.
        let json = """
            [{"id":1,"title":"Movie","kind":"movie","is_anime":false,"monitored":true,"is_available":true,
              "versions":[{"id":1,"tier":"HD-1080p"}],
              "editions":[{"id":1,"tier":"HD-1080p","monitored":true,"status":"done","have":1,"total":1},
                          {"id":2,"tier":"UHD-2160p","monitored":true,"status":"wanted","have":0,"total":1}]},
             {"id":2,"title":"Broken","kind":"movie"},
             {"id":3,"title":"Anime","kind":"series","is_anime":true,"monitored":true,"is_available":true,
              "editions":[{"id":4,"tier":"HD-1080p","monitored":true,"status":"grabbing","have":2,"total":12}]}]
            """
        let (summary, skipped) = try WidgetLibrarySummary.tally(Data(json.utf8))
        XCTAssertEqual(skipped, 1)
        XCTAssertEqual(summary.titles, 2)
        XCTAssertEqual(summary.versions, 3)
        XCTAssertEqual([summary.movies, summary.anime], [1, 1])
        XCTAssertEqual(summary.downloading, 1)
        XCTAssertEqual(summary.fourKTitles, 1)
        let full = try APIClient.decoder.decode([LenientItem].self, from: Data(json.utf8)).compactMap(\.item)
        XCTAssertEqual(WidgetLibrarySummary(full), summary)
    }

    func testRunLogLinesAndDiagnostic() {
        let ok = WidgetRunLog(stage: "render", page: "library", outcome: .ok, seconds: 1.2)
        let timedOut = WidgetRunLog(stage: "page", page: "library", outcome: .timedOut, error: "timeout 6s", seconds: 8)
        let killed = WidgetRunLog(stage: "page", page: "requests", outcome: .running, seconds: 0)
        XCTAssertEqual(timedOut.line, "timeout @page library 8.0s · timeout 6s")
        XCTAssertEqual(killed.line, "killed @page requests 0.0s")
        XCTAssertNil(WidgetRunLog.diagnostic(current: ok, previous: ok))
        XCTAssertEqual(WidgetRunLog.diagnostic(current: timedOut, previous: nil), timedOut.line)
        XCTAssertEqual(WidgetRunLog.diagnostic(current: ok, previous: killed), killed.line)
        XCTAssertTrue(killed.died(loading: "requests"))
        XCTAssertFalse(killed.died(loading: "library"))
        XCTAssertFalse(timedOut.died(loading: "library"))
        XCTAssertEqual(WidgetRunLog.describe(APIError.http(status: 502, body: "")), "HTTP 502")
        XCTAssertEqual(WidgetRunLog.describe(URLError(.timedOut)), "net -1001")
        XCTAssertEqual(WidgetRunLog.describe(WidgetPayloadTooLarge(bytes: 50 << 20)), "too large 50MB")
        XCTAssertThrowsError(try APIClient.decoder.decode(MediaItem.self, from: Data(#"{"id":1}"#.utf8))) {
            XCTAssertEqual(WidgetRunLog.describe($0), "decode: missing title")
        }
    }

    func testIndexerShownOnce() {
        func row(_ name: String, _ state: String = "healthy") -> WidgetIndexerRow {
            WidgetIndexerRow(name: name, state: state, successPercent: 90, grabs: 1, series: [])
        }
        var s = WidgetIndexerSummary()
        s.top = [row("Big"), row("Flaky", "backoff"), row("Small")]
        s.flagged = [WidgetIndexerFlag(name: "Flaky", detail: "backing off"), WidgetIndexerFlag(name: "Gone", detail: "off")]
        let large = s.lines(rows: 4, flags: 2, sharedSlots: false)
        XCTAssertEqual(large.rows.map(\.name), ["Big", "Flaky", "Small"])
        XCTAssertEqual(large.notes, [nil, "backing off", nil])
        XCTAssertEqual(large.flags.map(\.name), ["Gone"])
        // Medium: two slots; the unlisted flag takes the second.
        let medium = s.lines(rows: 2, flags: 1, sharedSlots: true)
        XCTAssertEqual(medium.rows.map(\.name), ["Big"])
        XCTAssertEqual(medium.flags.map(\.name), ["Flaky"])
        s.flagged = [WidgetIndexerFlag(name: "Flaky", detail: "backing off")]
        let listed = s.lines(rows: 2, flags: 1, sharedSlots: true)
        XCTAssertEqual(listed.rows.map(\.name), ["Big", "Flaky"])
        XCTAssertEqual(listed.notes, [nil, "backing off"])
        XCTAssertEqual(listed.flags, [])
    }
}

private actor Gauge {
    private var current = 0
    private(set) var peak = 0
    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1 }
}

private struct LenientItem: Decodable {
    let item: MediaItem?
    init(from decoder: Decoder) throws { item = try? MediaItem(from: decoder) }
}
