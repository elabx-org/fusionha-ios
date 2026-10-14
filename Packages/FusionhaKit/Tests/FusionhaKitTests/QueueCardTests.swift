import XCTest
@testable import FusionhaKit

/// The queue card fields from fusionha 0.4.189 (`api/schemas_queue_card.py`).
final class QueueCardTests: XCTestCase {
    private func page(_ name: String) throws -> QueuePage {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(QueuePage.self, from: Data(contentsOf: url))
    }

    func testStagesPackFactsAndPipelineDecode() throws {
        let page = try page("queue-card")
        let item = try XCTUnwrap(page.items.first)
        let stages = try XCTUnwrap(item.stages)
        XCTAssertTrue(stages.isPhaseMode)
        XCTAssertEqual(stages.route, "debrid")
        XCTAssertEqual(stages.steps?.filter(\.runs).count, 4)
        XCTAssertEqual(stages.ring, 0.25, accuracy: 0.0001)
        XCTAssertEqual(stages.linking, QueueRules.Linking(done: 3, total: 4))
        XCTAssertEqual(item.lastPhase, "linking")
        XCTAssertEqual(item.fileCount, 4)
        XCTAssertEqual(item.grabHistoryId, 512)
        XCTAssertEqual(item.packRanges?.done?.label, "S06E01–E03")
        XCTAssertEqual(item.packRanges?.current?.label, "S06E04")
        XCTAssertNil(item.packRanges?.waiting)
        XCTAssertEqual(item.parsed?.chips, ["AMZN", "H.264", "DD+ 5.1", "NTb"])
        XCTAssertEqual(page.pipeline?.lastImport?.title, "Andor")
        XCTAssertNotNil(ServerTime.parse(page.pipeline?.lastImport?.at))
    }

    func testServerPlanMapsToStageState() throws {
        let item = try XCTUnwrap(page("queue-card").items.first)
        let state = QueueRules.state(stages: try XCTUnwrap(item.stages))
        XCTAssertEqual(state.stages, ["Downloading", "Linking", "Caching", "Probing", "Importing"])
        XCTAssertEqual(state.current, 1)
        XCTAssertEqual(state.currentLabel, "Linking")
        XCTAssertEqual(state.skipped, [3])
        XCTAssertEqual(state.runningTotal, 4)
        XCTAssertFalse(state.failed)
    }

    func testOlderServersStillDecode() throws {
        let item = try XCTUnwrap(page("queue").items.first)
        XCTAssertNil(item.stages)
        XCTAssertNil(item.packRanges)
        XCTAssertNil(item.grabHistoryId)
    }

    func testRangeLabels() {
        let absolute = QueuePackRange(startLabel: "001", endLabel: "012", count: 12)
        XCTAssertEqual(absolute.label, "001–012")
        let acrossSeasons = QueuePackRange(startLabel: "S01E10", endLabel: "S02E02", count: 4)
        XCTAssertEqual(acrossSeasons.label, "S01E10–S02E02")
    }

    func testRemuxChipWinsOverSource() throws {
        let json = #"{"is_remux": true, "source": "BluRay", "dynamic_range": ["DV", "HDR10"], "is_repack": true}"#
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let facts = try d.decode(ReleaseFacts.self, from: Data(json.utf8))
        XCTAssertEqual(facts.chips, ["Remux", "DV", "HDR10", "REPACK"])
    }

    func testNewErrorCodesHavePlainCopy() {
        for code in ["rows_open", "not_held", "finish_in_progress", "db_busy"] {
            XCTAssertNotNil(ErrorCopy.messages[code], code)
        }
    }

    func testBackupRecordReadsKeyFields() throws {
        let json = #"{"id": "fusionha-2026.tar.gz", "size_bytes": 10, "created_at": "2026-10-14T01:00:00", "kind": "manual", "backend": "sqlite", "key_fingerprint": "ab12", "key_included": true, "encrypted": true}"#
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        let record = try d.decode(BackupRecord.self, from: Data(json.utf8))
        XCTAssertEqual(record.keyIncluded, true)
        XCTAssertEqual(record.encrypted, true)
        XCTAssertEqual(record.keyFingerprint, "ab12")
    }
}
