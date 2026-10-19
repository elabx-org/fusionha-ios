import XCTest
@testable import FusionhaKit

final class BlocklistTargetTests: XCTestCase {
    private func t(_ type: String, version: Int? = 3, guid: String? = nil, flag: Bool? = nil) -> BlocklistTarget? {
        BlocklistTarget.history(id: 7, eventType: type, versionId: version, guid: guid, blocklistable: flag)
    }

    func testServerFlagWins() {
        XCTAssertEqual(t("IMPORTED", flag: true), .history(id: 7, keepsCurrentFile: false))
        XCTAssertNil(t("GRABBED", guid: "g", flag: false))
    }

    func testHeldKeepsCurrentFile() {
        let target = t("HELD", flag: true)
        XCTAssertEqual(target, .history(id: 7, keepsCurrentFile: true))
        XCTAssertNil(target?.body(search: true, deleteFile: true).deleteCurrentFile)
    }

    func testNonReleaseEvents() {
        XCTAssertNil(t("DELETED", flag: true))
        XCTAssertNil(t("RENAMED", guid: "g"))
    }

    func testGuidFallbackOnlyForGrabbedWithVersion() {
        XCTAssertEqual(t("GRABBED", guid: "g"), .history(id: 7, keepsCurrentFile: false))
        XCTAssertNil(t("GRABBED", version: nil, guid: "g"))
        XCTAssertNil(t("GRABBED", guid: ""))
        XCTAssertNil(t("IMPORTED", guid: "g"))
    }

    func testQueueTarget() {
        let body = BlocklistTarget.queue(downloadId: 4).body(search: false, deleteFile: false)
        XCTAssertEqual(body.downloadId, 4)
        XCTAssertNil(body.historyId)
    }
}
