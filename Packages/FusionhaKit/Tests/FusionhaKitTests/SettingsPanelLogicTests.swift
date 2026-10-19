import XCTest
@testable import FusionhaKit

final class SettingsPanelLogicTests: XCTestCase {
    func testInsertAtCaret() {
        let r = NamingFormat.insert("{Year}", into: "Show ()", range: 6..<6)
        XCTAssertEqual(r.text, "Show ({Year})")
        XCTAssertEqual(r.caret, 12)
    }

    func testInsertReplacesSelection() {
        let r = NamingFormat.insert("{Title}", into: "abc XYZ def", range: 4..<7)
        XCTAssertEqual(r.text, "abc {Title} def")
        XCTAssertEqual(r.caret, 11)
    }

    func testInsertWithoutSelectionAppends() {
        let r = NamingFormat.insert("{Q}", into: "ab", range: nil)
        XCTAssertEqual(r.text, "ab{Q}")
        XCTAssertEqual(r.caret, 5)
    }

    func testInsertClampsStaleRange() {
        let r = NamingFormat.insert("X", into: "ab", range: 5..<9)
        XCTAssertEqual(r.text, "abX")
        XCTAssertEqual(r.caret, 3)
    }

    func testLatestStampIgnoresEmptyAndPicksNewest() {
        XCTAssertNil(ImportRulesNote.latest(stamps: [nil, nil]))
        XCTAssertEqual(ImportRulesNote.latest(stamps: ["2026-10-01T10:00:00", nil, "2026-10-02T09:00:00", "junk"]),
                       "2026-10-02T09:00:00")
    }

    func testSeenAgo() throws {
        let now = try XCTUnwrap(ServerTime.parse("2026-10-10T12:00:00"))
        XCTAssertEqual(ImportRulesNote.seenAgo("2026-10-10T11:59:30", now: now), "just now")
        XCTAssertEqual(ImportRulesNote.seenAgo("2026-10-10T11:15:00", now: now), "45 min ago")
        XCTAssertEqual(ImportRulesNote.seenAgo("2026-10-10T07:00:00", now: now), "5 h ago")
        XCTAssertEqual(ImportRulesNote.seenAgo("2026-10-09T10:00:00", now: now), "1 day ago")
        XCTAssertEqual(ImportRulesNote.seenAgo("2026-10-06T12:00:00", now: now), "4 days ago")
        XCTAssertEqual(ImportRulesNote.seenAgo(nil, now: now), "")
    }

    func testClientDecodesCapabilities() throws {
        let json = #"{"id":1,"name":"d","protocol":"TORRENT","host":"h","port":1,"capabilities":{"verify_api":"PRESENT","import_rules_seen_at":"2026-10-02T09:00:00"}}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let client = try decoder.decode(DownloadClientInfo.self, from: Data(json.utf8))
        XCTAssertEqual(ImportRulesNote.latest([client]), "2026-10-02T09:00:00")
    }
}
