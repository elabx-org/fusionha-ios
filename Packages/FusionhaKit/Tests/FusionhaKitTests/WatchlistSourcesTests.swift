import XCTest
@testable import FusionhaKit

/// The Plex watchlist & lists (fusionha 0.4.2xx phase 9) and Letterboxd
/// (phase 10a) golden bodies, copied from fusionha `docs/fixtures/`.
final class WatchlistSourcesTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"))
        return try APIClient.decoder.decode(T.self, from: Data(contentsOf: url))
    }

    // MARK: Plex

    func testPlexWatchlistOnDecodes() throws {
        let read = try decode(PlexWatchlistRead.self, "plex_watchlist_me_on")
        XCTAssertTrue(read.enabled)
        XCTAssertEqual(PlexWatchlistState(read), .on)
        XCTAssertEqual(read.requestedTotal, 16)
        XCTAssertTrue(read.alsoUhdAllowed)
        XCTAssertEqual(read.lists.state, "ok")
        XCTAssertEqual(read.lists.sources.map(\.listId), ["list-a", "list-b", "list-c"])
        XCTAssertEqual(read.lists.sources[1].visibility, "PRIVATE")
        let first = try XCTUnwrap(read.firstCheck)
        XCTAssertEqual(PlexWatchlistCopy.firstCheck(first),
                       "23 titles were already on your watchlist and were left alone. From now on, new additions are requested.")
        XCTAssertEqual(PlexWatchlistCopy.watchlistHint(read),
                       "41 titles on your watchlist · 23 were there before you turned this on and are left alone")
    }

    func testPlexWatchlistOffAndNeedsSignIn() throws {
        let off = try decode(PlexWatchlistRead.self, "plex_watchlist_me_off_lists")
        XCTAssertEqual(PlexWatchlistState(off), .off)
        XCTAssertNil(off.itemCount)
        XCTAssertNil(off.firstCheck)
        let sign = try decode(PlexWatchlistRead.self, "plex_watchlist_me_needs_sign_in")
        XCTAssertEqual(PlexWatchlistState(sign), .needsSignIn)
        XCTAssertEqual(sign.lists.state, "unknown")
        XCTAssertTrue(sign.lists.sources.isEmpty)
    }

    func testUnknownReasonReadsAsError() throws {
        let body = #"{"reason": "something_new", "enabled": true}"#
        let read = try APIClient.decoder.decode(PlexWatchlistRead.self, from: Data(body.utf8))
        XCTAssertEqual(PlexWatchlistState(read), .error)
        XCTAssertEqual(read.lists.state, "unknown")
    }

    func testPlexCopy() {
        XCTAssertEqual(PlexWatchlistCopy.syncDone(lists: 2, added: 1), "Checked your watchlist and 2 lists · 1 new title requested")
        XCTAssertEqual(PlexWatchlistCopy.checkNowSub(lists: 0), "Checks your watchlist right away. Once a minute at most.")
        XCTAssertTrue(PlexWatchlistState.on.switchable)
        XCTAssertFalse(PlexWatchlistState.disabled.switchable)
    }

    func testRetryAtReadsBothKeys() {
        let sync = APIError.http(status: 429, body: #"{"detail":{"code":"rate_limited","sync_available_at":"2026-10-09T21:26:00"}}"#)
        XCTAssertEqual(sync.retryAt, "2026-10-09T21:26:00")
        XCTAssertEqual(WatchlistErrorCopy.plexMessage(for: sync), "You can check again in a moment.")
        let retry = APIError.http(status: 429, body: #"{"detail":{"code":"rate_limited","retry_after":"2026-10-09T21:27:00"}}"#)
        XCTAssertEqual(retry.retryAt, "2026-10-09T21:27:00")
        let unreadable = APIError.http(status: 422, body: #"{"detail":{"code":"source_unreadable"}}"#)
        XCTAssertTrue(WatchlistErrorCopy.letterboxdMessage(for: unreadable, watchlist: true).hasPrefix("That watchlist isn’t public"))
    }

    func testServerTimeWords() {
        let now = ServerTime.parse("2026-10-09T21:20:00")!
        XCTAssertEqual(WatchlistTime.lastRun("2026-10-09T21:16:00", now: now), "4 min ago")
        XCTAssertEqual(WatchlistTime.until("2026-10-09T21:26:00", now: now), "in 6 min")
        XCTAssertEqual(WatchlistTime.lastRun(nil, now: now), "Never")
        XCTAssertEqual(WatchlistTime.secondsLeft("2026-10-09T21:21:00", now: now), 60)
    }

    // MARK: Letterboxd

    func testLetterboxdConnectedDecodes() throws {
        let read = try decode(LetterboxdRead.self, "letterboxd_me_connected")
        XCTAssertEqual(read.username, "example_member")
        XCTAssertEqual(LetterboxdLogic.connection(read), .ok)
        XCTAssertTrue(LetterboxdLogic.allowed(read))
        XCTAssertEqual(read.diary?.requestedCount, 7)
        XCTAssertEqual(read.watchlistFollow.status, "DEGRADED")
        XCTAssertTrue(read.watchlistFollow.truncated)
        XCTAssertEqual(read.maxLinkedLists, 5)
        XCTAssertEqual(read.linkedCount, 4)
    }

    func testLetterboxdOtherStates() throws {
        let none = try decode(LetterboxdRead.self, "letterboxd_me_not_connected")
        XCTAssertEqual(LetterboxdLogic.connection(none), .none)
        XCTAssertNil(none.diary)
        let locked = try decode(LetterboxdRead.self, "letterboxd_me_not_granted")
        XCTAssertFalse(LetterboxdLogic.allowed(locked))
        XCTAssertTrue(LetterboxdLogic.visible(locked))
        let bad = try decode(LetterboxdRead.self, "letterboxd_me_profile_not_found")
        XCTAssertEqual(LetterboxdLogic.connection(bad), .bad)
        XCTAssertEqual(LetterboxdLogic.profileProblem(bad).lead, "Letterboxd has no profile called @example_friend.")
    }

    func testRequestSourcesDecode() throws {
        let sources = try decode([LbSource].self, "request_sources_me")
        XCTAssertEqual(sources.count, 6)
        XCTAssertEqual(sources.filter(\.isLinked).map(\.id), [3, 4, 5, 6])
        XCTAssertEqual(sources[2].title, "@example_critic · Best of 2026")
        XCTAssertEqual(sources[4].title, "@example_friend · watchlist")
        XCTAssertEqual(LetterboxdLogic.status(sources[4].status).label, "Not public")
        XCTAssertEqual(LetterboxdLogic.status(sources[3].status).label, "Blocked by Letterboxd")
    }

    func testPreviewImportAndSuggestionsDecode() throws {
        let preview = try decode(LbSourcePreview.self, "request_source_preview")
        XCTAssertEqual(preview.items.count, 25)
        XCTAssertEqual(preview.owner, "example_critic")
        let matching = try decode(CsvPreviewRead.self, "letterboxd_csv_preview_matching")
        XCTAssertEqual(matching.status, "MATCHING")
        XCTAssertNil(matching.counts)
        XCTAssertTrue(matching.rows.isEmpty)
        let ready = try decode(CsvPreviewRead.self, "letterboxd_csv_preview_ready")
        XCTAssertEqual(ready.counts?.matched, 9)
        XCTAssertEqual(ready.lowConfidence.map(\.key), ["boxd:aaa8", "boxd:aaa9"])
        XCTAssertNil(ready.rows[9].tmdbId)
        let commit = try decode(CsvCommitResult.self, "letterboxd_csv_commit")
        XCTAssertEqual(commit.requested, 10)
        let rail = try decode(SuggestionsRead.self, "suggestions_me")
        XCTAssertTrue(rail.visible)
        XCTAssertEqual(rail.items.count, 3)
        XCTAssertEqual(rail.sources.map(\.count), [1, 2])
        XCTAssertEqual(rail.items[0].searchResult.kind, .movie)
    }

    func testLetterboxdRules() {
        XCTAssertTrue(LetterboxdLogic.validUsername("example_member"))
        XCTAssertFalse(LetterboxdLogic.validUsername("a"))
        XCTAssertFalse(LetterboxdLogic.validUsername("has space"))
        XCTAssertFalse(LetterboxdLogic.validUsername("sixteen_chars_xx"))
        XCTAssertTrue(LetterboxdLogic.looksLikeListURL("https://letterboxd.com/example_critic/list/best-of-2026/"))
        XCTAssertFalse(LetterboxdLogic.looksLikeListURL("https://letterboxd.com/example_critic/watchlist/"))
        XCTAssertEqual(LetterboxdLogic.scheduleHours(last: "2026-10-09T20:00:00", next: "2026-10-10T02:00:00"), 6)
        XCTAssertEqual(LetterboxdLogic.checkAgain(185), "You can check again in 3:05")
        XCTAssertTrue(APIClient.letterboxdFileTooLarge(name: "watchlist.csv", size: 2_000_000))
        XCTAssertFalse(APIClient.letterboxdFileTooLarge(name: "export.zip", size: 2_000_000))
    }

    func testMultipartBodyCarriesTheFile() {
        let form = MultipartForm()
        let body = String(decoding: form.body(field: "file", filename: "watch\"list.csv", mimeType: "text/csv",
                                              data: Data("Name,Year\n".utf8)), as: UTF8.self)
        XCTAssertTrue(body.contains("name=\"file\"; filename=\"watchlist.csv\""))
        XCTAssertTrue(body.hasSuffix("--\(form.boundary)--\r\n"))
    }
}
