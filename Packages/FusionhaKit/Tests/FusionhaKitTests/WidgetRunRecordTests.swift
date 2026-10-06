import XCTest
@testable import FusionhaKit

/// The widget run journal the app's Widget diagnostics reads.
final class WidgetRunRecordTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func record(_ id: String, kind: String = "Downloads", family: String = "medium",
                        outcome: WidgetRunLog.Outcome = .ok, call: String = "timeline") -> WidgetRunRecord {
        WidgetRunRecord(id: id, kind: kind, family: family, call: call,
                        log: WidgetRunLog(stage: "page", page: "upnext", outcome: outcome, started: start, seconds: 1.3))
    }

    func testUpsertReplacesInPlaceAndAddsNewestFirst() {
        var records = WidgetRunJournal.upserting(record("a"), into: [])
        records = WidgetRunJournal.upserting(record("b"), into: records)
        XCTAssertEqual(records.map(\.id), ["b", "a"])
        var a = record("a")
        a.rendered = true
        records = WidgetRunJournal.upserting(a, into: records)
        XCTAssertEqual(records.map(\.id), ["b", "a"])
        XCTAssertTrue(records[1].rendered)
    }

    func testJournalKeepsTheNewestFew() {
        var records: [WidgetRunRecord] = []
        for i in 0..<30 { records = WidgetRunJournal.upserting(record("\(i)"), into: records) }
        XCTAssertEqual(records.count, WidgetRunJournal.keep)
        XCTAssertEqual(records.first?.id, "29")
    }

    func testRunningRecordBecomesNeverFinished() {
        let running = record("a", outcome: .running)
        XCTAssertEqual(running.status(now: start.addingTimeInterval(5)), "running")
        XCTAssertFalse(running.abandoned(now: start.addingTimeInterval(5)))
        XCTAssertEqual(running.status(now: start.addingTimeInterval(60)), "never finished")
        XCTAssertTrue(running.line(now: start.addingTimeInterval(60)).contains("never finished @page upnext"))
    }

    func testLineSaysWhetherTheEntryWasDrawn() {
        var ok = record("a")
        XCTAssertEqual(ok.line(now: start), "Downloads medium timeline · ok @page upnext 1.3s · not drawn")
        ok.rendered = true
        XCTAssertTrue(ok.line(now: start).hasSuffix("· drawn"))
    }

    func testPreviousSkipsOtherWidgetsSnapshotsAndRunsInFlight() {
        let records = [
            record("now", outcome: .running),
            record("other", kind: "UpNext"),
            record("snap", call: "snapshot"),
            record("busy", outcome: .running),
            record("old", outcome: .failed),
        ]
        let soon = start.addingTimeInterval(3)
        XCTAssertEqual(WidgetRunJournal.previous(kind: "Downloads", family: "medium", before: "now",
                                                 in: records, now: soon)?.id, "old")
        let later = start.addingTimeInterval(60)
        XCTAssertEqual(WidgetRunJournal.previous(kind: "Downloads", family: "medium", before: "now",
                                                 in: records, now: later)?.id, "busy")
    }

    func testRoundTripsThroughJSON() {
        let records = [record("a"), record("b", outcome: .timedOut)]
        XCTAssertEqual(WidgetRunJournal.decode(WidgetRunJournal.encode(records)), records)
        XCTAssertEqual(WidgetRunJournal.decode(Data("junk".utf8)), [])
        XCTAssertEqual(WidgetRunJournal.decode(nil), [])
    }

    func testNotesDescribeThemselves() {
        XCTAssertEqual(WidgetRunLog.describe(WidgetRunNote("queue unreachable")), "queue unreachable")
    }
}
