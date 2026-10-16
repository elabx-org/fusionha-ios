import XCTest
@testable import FusionhaKit

/// fusionha's golden JSON fixtures (`docs/fixtures/`, 0.4.203–0.4.204), copied into
/// `Fixtures/golden/`: the server pins these shapes, so the app's decoders are
/// checked against exactly what it sends. Re-copy them when fusionha updates.
final class GoldenFixtureTests: XCTestCase {
    private func load(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"))
        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: load(name))
    }

    func testHeldQueueItemUsesTheServersCopy() throws {
        let item = try decode(QueueItem.self, "queue_item_held")
        let held = try XCTUnwrap(item.held)
        XCTAssertEqual(held.code, "mislabeled_resolution")
        XCTAssertEqual(held.short, "not really 2160p")
        XCTAssertEqual(QueueCardText.heldTag(item), "not really 2160p")
        let reason = QueueCardText.heldReason(item)
        XCTAssertEqual(reason.lead, "Not really 2160p")
        // A detail panel explains it, so no extra line under the lead.
        XCTAssertNil(reason.text)
        XCTAssertEqual(reason.guard, "would replace your 4K FUZEER copy")
    }

    func testPlainQueueItemDecodes() throws {
        let item = try decode(QueueItem.self, "queue_item")
        XCTAssertNil(item.held)
        XCTAssertFalse(item.title.isEmpty)
    }

    func testRequestTriageReadsTheTrackRecord() throws {
        struct Wrapper: Decodable { let triage: RequestTriage }
        let triage = try decode(Wrapper.self, "request_with_triage").triage
        XCTAssertEqual(triage.trackRecord.requests30d, 6)
        XCTAssertEqual(triage.trackRecord.approved30d, 6)
        XCTAssertTrue(triage.trackRecord.trusted)
    }

    func testIssueWithStagedCopyDecodes() throws {
        let issue = try decode(MediaIssue.self, "issue_with_staged_copy")
        XCTAssertGreaterThan(issue.id, 0)
        let list = (issue.reports ?? []).compactMap(\.evidenceList).first
        XCTAssertEqual(EvidenceRows.rows(list: list).map(\.label), ["evidence"])
    }

    func testManualImportRowUsesTheServersFindingChips() throws {
        let row = try decode(ManualImportRow.self, "manual_import_row_finding")
        let chips = ManualImportDecide.findings(row)
        XCTAssertEqual(chips.map(\.text), ["Really S06E06 · Mafia", "in library"])
        XCTAssertEqual(chips.first?.icon, .redirect)
        XCTAssertEqual(chips.first?.sentence, "File says 'Mafia' — that's S06E06 in your library, not S06E05")
        XCTAssertEqual(chips.last?.tone, .library)
    }

    func testHeldCopyRules() {
        let other = HeldDisplay(code: "other", short: "needs a look",
                                text: "The imported file could not be put in place — held for review: a.mkv.")
        XCTAssertEqual(other.stepTitle, "Held: The imported file could not be put in place — held for review: a.mkv")
        XCTAssertEqual(HeldDisplay(code: "fix_in_progress", short: "a fix is in progress", text: "x.").stepTitle,
                       "Held: a fix is in progress")
    }
}
