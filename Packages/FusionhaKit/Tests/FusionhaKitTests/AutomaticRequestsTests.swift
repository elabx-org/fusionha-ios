import XCTest
@testable import FusionhaKit

/// Watchlists & lists (fusionha 0.4.226, phase 10b slice 1): the summary,
/// sync, unmatched review and remembered-match goldens from fusionha
/// `docs/fixtures/`, the row line, the page model and the refusal copy.
final class AutomaticRequestsTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"))
        return try APIClient.decoder.decode(T.self, from: Data(contentsOf: url))
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func error(_ status: Int, _ detail: String) -> APIError {
        .http(status: status, body: #"{"detail":\#(detail)}"#)
    }

    // MARK: Summary

    func testSummaryActive() throws {
        let s = try decode(AutoSummary.self, "automatic_requests_summary")
        XCTAssertEqual(s.requestedLast7d, 9)
        XCTAssertEqual(s.needsReview, 1)
        XCTAssertNil(s.syncing)
        XCTAssertEqual(s.sources.map(\.sourceId), ["letterboxd-diary", "letterboxd-watchlist"])
        XCTAssertEqual(s.sources.map(\.state), [.healthy, .partlyWorking])
        XCTAssertEqual(s.sources.map(\.group), [.letterboxd, .letterboxd])
        XCTAssertEqual(s.defaultSourceId, "letterboxd-watchlist")
        XCTAssertEqual(s.source("letterboxd-watchlist")?.needsReview, 1)
        let line = AutomaticRequestsCopy.rowLine(s)
        XCTAssertEqual(line.kind, .active)
        XCTAssertEqual(line.text, "9 requested this week")
        XCTAssertEqual(line.review, "1 needs review")
        XCTAssertEqual(line.plain, "9 requested this week · 1 needs review")
        XCTAssertTrue(WatchlistsRoute.spreadOpensLists(s))
    }

    func testSummarySyncingFreshAndPaused() throws {
        let syncing = try decode(AutoSummary.self, "automatic_requests_summary_syncing")
        XCTAssertEqual(syncing.syncing?.done, 140)
        XCTAssertEqual(syncing.syncing?.total, 250)
        XCTAssertEqual(AutomaticRequestsCopy.rowLine(syncing).plain, "Syncing 140 of 250… · 0 requested so far")

        let fresh = try decode(AutoSummary.self, "automatic_requests_summary_fresh")
        XCTAssertTrue(AutomaticRequestsCopy.isFresh(fresh))
        XCTAssertEqual(AutomaticRequestsCopy.rowLine(fresh).plain, "Set up")
        XCTAssertFalse(WatchlistsRoute.spreadOpensLists(fresh))
        XCTAssertFalse(WatchlistsRoute.spreadOpensLists(nil))

        let paused = try decode(AutoSummary.self, "automatic_requests_summary_paused")
        let own = try XCTUnwrap(paused.source("letterboxd-watchlist"))
        XCTAssertEqual(own.state, .paused)
        XCTAssertTrue(own.paused)
        XCTAssertFalse(own.pausedByOthers)
        XCTAssertEqual(own.state.word, "Paused")
        XCTAssertTrue(own.state.skipsSync)
    }

    func testUnknownWordsAndOlderServers() throws {
        let s = try decode(AutoSummary.self, json: #"{"sources": [{"source_id": "list-9", "group": "mdblist", "state": "brand_new", "needs_review": 0}]}"#)
        XCTAssertEqual(s.sources.first?.state, .retrying)
        XCTAssertEqual(s.sources.first?.group, .lists)
        XCTAssertEqual(s.sources.first?.paused, false)
        XCTAssertEqual(s.requestedLast7d, 0)
        XCTAssertNil(s.defaultSourceId)
        let admin = try decode(AutoSource.self, json: #"{"source_id": "plex-watchlist", "group": "plex", "state": "paused", "needs_review": 2, "paused": false}"#)
        XCTAssertTrue(admin.pausedByOthers)
    }

    func testStateWordsAndTones() {
        XCTAssertEqual(AutoSourceState.needsSignIn.word, "Sign in again")
        XCTAssertEqual(AutoSourceState.gone.word, "Deleted on Plex")
        XCTAssertEqual(AutoSourceState.healthy.tone, .done)
        XCTAssertEqual(AutoSourceState.syncing.tone, .grab)
        XCTAssertEqual(AutoSourceState.notPublic.tone, .miss)
        XCTAssertEqual(AutoSourceState.retrying.tone, .stuck)
        XCTAssertEqual(AutoSourceState.blocked.tone, .danger)
        XCTAssertNil(AutoSourceState.off.tone)
        XCTAssertEqual(AutoSourceState.off.pausedText, "Turned off")
        XCTAssertTrue(AutoSourceState.needsSignIn.idle)
        XCTAssertFalse(AutoSourceState.healthy.skipsSync)
    }

    func testSyncResult() throws {
        let r = try decode(AutoSyncResult.self, "automatic_requests_sync")
        XCTAssertEqual(r.queued, ["letterboxd-diary", "letterboxd-watchlist"])
        XCTAssertEqual(r.syncAvailableAt, "2026-10-17T12:05:00")
        XCTAssertEqual(AutomaticRequestsCopy.syncError(error(429, #"{"code":"rate_limited","sync_available_at":"2026-10-17T12:05:00"}"#)),
                       "You can check again in a moment.")
        XCTAssertEqual(AutomaticRequestsCopy.syncError(error(409, #"{"code":"source_paused","reason":"paused"}"#)),
                       "This source is paused. Resume it to sync.")
        XCTAssertEqual(AutomaticRequestsCopy.syncDone(sources: 2, added: 1), "Checked your watchlist and 2 lists · 1 new title requested")
    }

    // MARK: Unmatched review

    func testUnmatchedAndWhy() throws {
        let items = try decode([UnmatchedItem].self, "request_source_unmatched")
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.itemId, 38)
        XCTAssertEqual(item.label, "Primal (2019)")
        XCTAssertEqual(item.reason, "no_tmdb_link")
        XCTAssertEqual(item.query, "Primal 2019")
        XCTAssertEqual(PickCopy.slug(item.sourceUrl), "primal-2019-1")
        let why = PickCopy.whySentence(item, provider: "Letterboxd")
        XCTAssertEqual(why.before + (why.slug ?? "") + why.after,
                       "Letterboxd’s page for this film has no TMDB link, and its address (primal-2019-1) is Letterboxd’s second film called “Primal” from 2019, so more than one title fits. fusionha didn’t guess.")
        let plex = try decode(UnmatchedItem.self, json: #"{"item_id": 4, "title": "Untitled item", "year": null, "source_url": null, "reason": "not_found", "query": ""}"#)
        XCTAssertEqual(PickCopy.whySentence(plex, provider: "Plex").before, "Plex gave no id fusionha could match. fusionha didn’t guess.")
        XCTAssertNil(PickCopy.slug("https://letterboxd.com/film/primal/"))
        XCTAssertEqual(PickCopy.intro(1, source: "My watchlist", provider: "Letterboxd"),
                       "1 title from My watchlist (Letterboxd) couldn’t be matched. Choose what it is, or ignore it.")
        XCTAssertEqual(PickCopy.from(provider: "Letterboxd", source: "My watchlist"), "From your Letterboxd watchlist")
        XCTAssertEqual(PickCopy.from(provider: "Letterboxd", source: "Best of 2026"), "From Best of 2026")
    }

    func testResolveOutcomes() throws {
        let r = try decode(ResolveResult.self, "request_source_resolve")
        XCTAssertEqual(r.outcome, "REQUESTED")
        XCTAssertEqual(r.requestId, 1)
        XCTAssertFalse(r.queued)
        XCTAssertEqual(PickCopy.done(r.outcome, title: "Primal (2019)"), "Requested Primal (2019) · remembered for everyone")
        XCTAssertEqual(PickCopy.done("JOINED", title: "Primal (2019)"), "Joined the request for Primal (2019)")
        XCTAssertEqual(PickCopy.done("OWNED", title: "x"), "Already in your library")
    }

    func testRefusals() {
        let paused = PickCopy.Refusal(error(409, #"{"code":"source_paused","reason":"paused","detail":"x"}"#))
        XCTAssertEqual(paused, .paused)
        XCTAssertEqual(paused.inline, "Resume this source to request it.")
        let off = PickCopy.Refusal(error(409, #"{"code":"source_paused","reason":"off"}"#))
        XCTAssertEqual(off, .off)
        XCTAssertEqual(off.inline, "Turn this source on to request it.")
        let signIn = PickCopy.Refusal(error(409, #"{"code":"needs_sign_in"}"#))
        XCTAssertEqual(signIn.inline, "Sign in with Plex again to request it.")
        let handled = PickCopy.Refusal(error(409, #"{"code":"not_unmatched"}"#))
        XCTAssertEqual(handled, .handled)
        XCTAssertNil(handled.inline)
        XCTAssertEqual(handled.toast, "This title was already handled.")
        let denied = PickCopy.Refusal(error(403, #"{"code":"not_allowed"}"#))
        XCTAssertEqual(denied, .notAllowed)
        XCTAssertEqual(denied.toast, PickCopy.notAllowed)
        XCTAssertEqual(PickCopy.Refusal(error(500, #""boom""#)).toast, "That didn’t work. Try again in a moment.")
    }

    func testPauseRefusal() {
        let admin = error(403, #""Forbidden""#)
        XCTAssertEqual(SourceDetailCopy.pauseError(admin, resuming: true), "An admin paused this source, so only an admin can resume it.")
        XCTAssertEqual(SourceDetailCopy.pauseError(admin, resuming: false), "That didn’t work. Try again in a moment.")
    }

    // MARK: Remembered matches

    func testListMatches() throws {
        let rows = try decode([ListMatch].self, "list_matches")
        let m = try XCTUnwrap(rows.first)
        XCTAssertEqual(m.id, "LETTERBOXD:primal-2019-1")
        XCTAssertEqual(m.tmdbId, 500916)
        XCTAssertEqual(RememberedCopy.into(m), "→ Primal (2019)")
        XCTAssertEqual(RememberedCopy.entry(m), "primal-2019-1")
        XCTAssertEqual(RememberedCopy.who(m), "chosen by @example_member")
        XCTAssertEqual(RememberedCopy.link(rows.count), "Remembered matches · 1")
        let plex = try decode(ListMatch.self, json: #"{"provider": "PLEX", "external_key": "plex://movie/5d77", "entry_url": null, "tmdb_id": 7, "kind": "movie", "title": null, "year": null, "resolved_by": null, "resolved_at": "2026-10-17T12:00:00"}"#)
        XCTAssertEqual(RememberedCopy.entry(plex), "Plex item")
        XCTAssertEqual(RememberedCopy.into(plex), "→ TMDB 7")
        XCTAssertEqual(RememberedCopy.who(plex), "chosen")
    }

    // MARK: Page model

    func testPageModelJoinsTheReads() throws {
        let summary = try decode(AutoSummary.self, json: #"""
        {"requested_last7d": 3, "needs_review": 1, "syncing": null, "default_source_id": "plex-watchlist",
         "sources": [
          {"source_id": "letterboxd-diary", "group": "letterboxd", "state": "healthy", "needs_review": 0},
          {"source_id": "letterboxd-watchlist", "group": "letterboxd", "state": "partly_working", "needs_review": 0},
          {"source_id": "plex-watchlist", "group": "plex", "state": "healthy", "needs_review": 1},
          {"source_id": "list-2", "group": "plex", "state": "healthy", "needs_review": 0},
          {"source_id": "list-3", "group": "lists", "state": "healthy", "needs_review": 0},
          {"source_id": "list-5", "group": "lists", "state": "healthy", "needs_review": 0},
          {"source_id": "list-99", "group": "lists", "state": "checking", "needs_review": 0}]}
        """#)
        let lb = try decode(LetterboxdRead.self, "letterboxd_me_connected")
        let rows = try decode([LbSource].self, "request_sources_me")
        let plex = try decode(PlexWatchlistRead.self, "plex_watchlist_me_on")
        let views = AutoSourceViews.build(summary, letterboxd: lb, sources: rows, plex: plex)
        XCTAssertEqual(views.map(\.name), ["Diary", "My watchlist", "Plex watchlist", "Kids movies", "Best of 2026",
                                           "@example_friend’s watchlist", "Letterboxd list"])
        XCTAssertEqual(views.map(\.kind), [.diary, .ownWatchlist, .plexWatchlist, .plexList, .list, .watchlist, .list])
        XCTAssertEqual(views[0].subtitle, "@example_member · 7 requested")
        XCTAssertEqual(views[1].rowId, 2)
        XCTAssertEqual(views[2].subtitle, "12 requested")
        XCTAssertEqual(views[2].reviewText, "1 to review")
        XCTAssertEqual(views[3].mini, "3 requested · 18 titles")
        XCTAssertEqual(views[4].subtitle, "@example_critic · 4 requested · 2 baseline")
        XCTAssertEqual(views[4].rowId, 3)
        XCTAssertTrue(views[2].isPlex)
        XCTAssertEqual(views[4].provider, "Letterboxd")

        let detail = AutoSourceDetail(views[2])
        XCTAssertTrue(detail.enabled)
        XCTAssertEqual(detail.unmatched, 1)
        XCTAssertEqual(detail.counts.unmatched, 1)
        XCTAssertEqual(detail.counts.skipped, 1)
        XCTAssertEqual(detail.baseline, "new")
        XCTAssertEqual(AutoSourceDetail(views[1]).hint(ownWatchlist: true), "605 films read")

        XCTAssertEqual(AutoSourceViews.groupMeta(.letterboxd, Array(views[0...1])), "@example_member · public data only")
        XCTAssertEqual(AutoSourceViews.groupMeta(.plex, Array(views[2...3])), "connected")
    }

    func testOwnWatchlistAndSourceIds() throws {
        let lb = try decode(LetterboxdRead.self, "letterboxd_me_connected")
        XCTAssertEqual(lb.watchlistFollow.sourceKey, "letterboxd-watchlist")
        XCTAssertEqual(lb.watchlistFollow.sourceId, 2)
        XCTAssertFalse(lb.watchlistFollow.alsoUhd)
        XCTAssertEqual(lb.diary?.sourceId, "letterboxd-diary")
        let rows = try decode([LbSource].self, "request_sources_me")
        XCTAssertEqual(rows.map(\.sourceId), ["letterboxd-diary", "letterboxd-watchlist", "list-3", "list-4", "list-5", "list-6"])
        XCTAssertEqual(rows.first?.alsoUhd, false)
        let older = try decode(LbSource.self, json: #"{"id": 12, "kind": "LETTERBOXD_LIST"}"#)
        XCTAssertEqual(older.sourceId, "list-12")
        let effective = try decode(LbSource.self, json: #"{"id": 2, "kind": "LETTERBOXD_WATCHLIST", "source_id": "letterboxd-watchlist", "options": {"also_uhd": true}}"#)
        XCTAssertTrue(effective.alsoUhd)
        let plex = try decode(PlexWatchlistRead.self, "plex_watchlist_me_on")
        XCTAssertEqual(plex.sourceId, "plex-watchlist")
        XCTAssertEqual(plex.lists.sources.map { $0.sourceId ?? "" }, ["list-2", "list-3", "list-4"])
    }

    func testRoutesAndAdminRows() throws {
        XCTAssertEqual(WatchlistsRoute.parse(host: "account", path: ["lists"]), .some(nil))
        XCTAssertEqual(WatchlistsRoute.parse(host: "account", path: ["lists", "list-38"]), .some("list-38"))
        XCTAssertNil(WatchlistsRoute.parse(host: "account", path: ["watchlist"]))
        XCTAssertNil(WatchlistsRoute.parse(host: "library", path: ["lists"]))

        let rows = try decode([PlexWatchlistSummaryRow].self, "plex_watchlist_summary")
        XCTAssertEqual(rows.first?.pausedByUser, false)
        let byUser = try decode(PlexWatchlistSummaryRow.self, json: #"{"user_id": 9, "state": "paused", "source_count": 1, "requested_count": 0, "paused_by_user": true}"#)
        XCTAssertEqual(SourceAdminCopy.plexChipLabel(byUser), "Paused by user")
        let byAdmin = try decode(PlexWatchlistSummaryRow.self, json: #"{"user_id": 9, "state": "paused", "source_count": 1, "requested_count": 0}"#)
        XCTAssertEqual(SourceAdminCopy.plexChipLabel(byAdmin), "Paused by admin")
        let summary = try decode(RequestSourcesSummary.self, "request_sources_summary")
        XCTAssertTrue(summary.sources.contains { $0.stableId == "letterboxd-diary" })
    }

    func testFollowAndManageWords() {
        XCTAssertEqual(FollowCopy.linkedAfter(3, max: 5), "3 of 5 linked after this")
        XCTAssertEqual(FollowCopy.following("Best of 2026"), "Following Best of 2026. Its first check starts now.")
        XCTAssertEqual(SourceDetailCopy.resume, "Resume")
        XCTAssertEqual(SourceDetailCopy.removeDesc, "You’ll be asked to confirm.")
    }
}
