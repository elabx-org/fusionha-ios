import XCTest
@testable import FusionhaKit

final class FailureCopyTests: XCTestCase {
    private let realDead = "failed to process nzb: failed to process NZB archives: no valid files found in NZB: dead articles (every provider denied the post) (7/7 groups failed: dead_articles=7) [decypharr reason=dead_articles]"

    func testDeadPostRealWorld() {
        let f = FailureCopy.format(realDead)
        XCTAssertEqual(f.kind, .deadPost)
        XCTAssertEqual(f.title, "Dead post")
        XCTAssertTrue(f.detail.contains("7/7 groups"))
        XCTAssertTrue(f.detail.contains("dead articles"))
        XCTAssertTrue(f.sub?.contains("re-searching") == true)
        XCTAssertTrue(f.isContentFailure)
        XCTAssertEqual(f.raw, realDead)
    }

    func testHyphenMarker() {
        let f = FailureCopy.format("boom [decypharr-reason=dead_articles]")
        XCTAssertEqual(f.kind, .deadPost)
        XCTAssertTrue(f.isContentFailure)
    }

    func testDeadPostWithoutNumbers() {
        let f = FailureCopy.format("no valid files found in NZB")
        XCTAssertEqual(f.detail, "Every provider denied the post (dead articles).")
    }

    func testGroupsShape() {
        XCTAssertTrue(FailureCopy.format("dead articles (3/8 groups failed)").detail.contains("3/8 groups"))
    }

    func testKnownKinds() {
        let cases: [(String, String, Bool)] = [
            ("rejected release as known-bad", "Known-bad release", true),
            ("no space left on device", "No disk space", false),
            ("request timed out after 60s", "Timed out", false),
            ("mount unavailable", "Link expired", false),
            ("removed by download client", "Link expired", false),
            ("[decypharr-reason=provider_busy]", "Provider error", false),
            ("[decypharr-reason=decode_giveup]", "Provider error", false),
            ("repair failed: not enough repair blocks", "Unpack failed", false),
            ("[decypharr-reason=structural]", "Unpack failed", false),
        ]
        for (raw, title, content) in cases {
            let f = FailureCopy.format(raw)
            XCTAssertEqual(f.title, title, raw)
            XCTAssertEqual(f.isContentFailure, content, raw)
            XCTAssertEqual(f.raw, raw)
        }
    }

    func testAmountIsNotMount() {
        XCTAssertNotEqual(FailureCopy.format("bad amount of data").kind, .linkExpired)
    }

    func testUnknownCleaner() {
        let f = FailureCopy.format("failed to process nzb: failed to process NZB archives: something odd happened [decypharr reason=weird_thing]")
        XCTAssertEqual(f.kind, .download)
        XCTAssertEqual(f.detail, "Something odd happened")
        XCTAssertTrue(f.raw.contains("decypharr"))
    }

    func testDedupesClauses() {
        XCTAssertEqual(FailureCopy.format("boom: boom: the tail").detail, "Boom: the tail")
    }

    func testContextTitles() {
        XCTAssertEqual(FailureCopy.format("mystery", context: .import).title, "Import failed")
        XCTAssertEqual(FailureCopy.format("mystery", context: .import).kind, .import)
        XCTAssertEqual(FailureCopy.format("mystery", context: .download).title, "Download failed")
        XCTAssertEqual(FailureCopy.format("mystery", context: .blocklist).kind, .unknown)
    }

    func testNeverEmpties() {
        XCTAssertFalse(FailureCopy.format("[decypharr-reason=weird_thing]").detail.isEmpty)
    }

    func testBlank() {
        for v: String? in [nil, "", "   "] {
            let f = FailureCopy.format(v)
            XCTAssertEqual(f.kind, .unknown)
            XCTAssertEqual(f.raw, "")
            XCTAssertFalse(f.isContentFailure)
            XCTAssertFalse(f.detail.isEmpty)
        }
    }
}
