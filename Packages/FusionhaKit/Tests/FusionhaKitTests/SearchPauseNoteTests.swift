import XCTest
@testable import FusionhaKit

final class SearchPauseNoteTests: XCTestCase {
    private func pauses() throws -> SearchPauses {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(SearchPauses.self, from: Data(#"""
            {"now": "2026-10-01T10:00:00Z",
             "episodes": [{"version_id": 1, "episode_id": 5, "cooldown_until": "2026-10-01T14:00:00Z", "failed_download_count": 2},
                          {"version_id": 1, "episode_id": 5, "cooldown_until": "2026-10-01T12:00:00Z", "failed_download_count": 1},
                          {"version_id": 2, "episode_id": 5, "cooldown_until": "2026-10-01T11:00:00Z", "failed_download_count": 3}],
             "seasons": [{"version_id": 1, "season_number": null, "backoff_until": "2026-10-02T09:00:00Z", "consecutive_empty": 4}]}
            """#.utf8))
    }

    func testSoonestCooldownInScope() throws {
        let c = SearchPauseNote.cooldown(try pauses(), episodeId: 5, versionIds: [1])
        XCTAssertEqual(c?.failedDownloadCount, 1)
        XCTAssertNil(SearchPauseNote.cooldown(try pauses(), episodeId: 6, versionIds: [1]))
    }

    func testItemWideBackoffCovers() throws {
        XCTAssertEqual(SearchPauseNote.backoff(try pauses(), season: 3, versionIds: [1])?.consecutiveEmpty, 4)
        XCTAssertNil(SearchPauseNote.backoff(try pauses(), season: 3, versionIds: [2]))
    }

    func testCopy() throws {
        let c = SearchPauseNote.cooldown(try pauses(), episodeId: 5, versionIds: [1])
        let note = SearchPauseNote.note(cooldown: c, backoff: nil) { _ in "12:00" }
        XCTAssertEqual(note, "auto-search was cooling down after 1 failed download (resumes 12:00) — your manual search ran anyway")
        XCTAssertEqual(SearchPauseNote.nothingGrabbed("S1E5", note: nil), "Searched S1E5 — nothing grabbed")
        XCTAssertEqual(SearchPauseNote.nothingGrabbed("S1E5", note: "x"), "Searched S1E5 — nothing grabbed · x")
        let b = SearchPauseNote.backoff(try pauses(), season: 1, versionIds: [1])
        XCTAssertEqual(SearchPauseNote.note(cooldown: nil, backoff: b) { _ in "9:00" },
                       "auto-search was paused after 4 empty searches (resumes 9:00) — your manual search ran anyway")
    }
}
