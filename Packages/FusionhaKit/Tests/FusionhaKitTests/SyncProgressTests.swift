import XCTest
@testable import FusionhaKit

/// fusionha 0.4.215 sync progress: the `sync` / `counts` blocks on every
/// Plex / Letterboxd source read and the admin rollup, from the golden
/// fixtures copied from `docs/fixtures/` into `Fixtures/golden/`.
final class SyncProgressTests: XCTestCase {
    private let now = ServerTime.parse("2026-10-09T21:20:00")!

    private func load(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"))
        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: load(name))
    }

    // MARK: Account reads

    func testLetterboxdSyncingWatchlist() throws {
        let read = try decode(LetterboxdRead.self, "letterboxd_me_syncing")
        let follow = read.watchlistFollow
        XCTAssertEqual(follow.sync?.state, "running")
        XCTAssertEqual(follow.nextCheckAt, "2026-10-10T08:20:00")
        XCTAssertEqual(follow.counts?.baseline, 1)
        XCTAssertEqual(SyncProgress.variant(follow.sync), .running)
        XCTAssertEqual(SyncProgress.percent(follow.sync), 63)
        XCTAssertTrue(SyncProgress.letterboxdRunning(read, sources: []))
        let line = SyncProgress.line(follow.sync, requested: follow.counts?.requested ?? follow.requestedCount)
        XCTAssertEqual(line.plain, "Checking 24 of 38 · 0 requested so far")
        XCTAssertEqual(line.segments.filter(\.bold).map(\.text), ["24", "0"])

        let diary = try XCTUnwrap(read.diary)
        XCTAssertEqual(SyncProgress.variant(diary.sync), .idle)
        XCTAssertEqual(SyncProgress.line(diary.sync, lastCheckedAt: diary.lastCheckedAt, nextCheckAt: diary.nextCheckAt,
                                         note: SyncProgress.baselineNote(diary.counts?.baseline), now: now).plain,
                       "Up to date · checked 38 min ago · next check in 5 hr")
    }

    func testLinkedSourcesSyncing() throws {
        let sources = try decode([LbSource].self, "request_sources_me_syncing")
        XCTAssertEqual(sources.map { $0.sync?.state }, ["idle", "running", "idle", "error", "idle", "idle"])
        XCTAssertTrue(SyncProgress.letterboxdRunning(nil, sources: sources))
        let blocked = sources[3]
        XCTAssertEqual(blocked.counts?.queued, 1)
        XCTAssertEqual(SyncProgress.line(blocked.sync, nextCheckAt: blocked.nextCheckAt, now: now).plain,
                       "Couldn’t read this source · retrying in 6 hr")
        XCTAssertEqual(SyncProgress.queuedHint(blocked.counts), "1 queued · working through them")
        let fresh = sources[5]
        XCTAssertEqual(SyncProgress.line(fresh.sync, nextCheckAt: fresh.nextCheckAt, now: now).plain,
                       "Waiting for the first check · next check soon")
        XCTAssertEqual(SyncProgress.line(fresh.sync, paused: true, pausedText: "switched off for now. Counts are from the last check.").plain,
                       "Paused · switched off for now. Counts are from the last check.")

        let idle = try decode([LbSource].self, "request_sources_me")
        XCTAssertFalse(SyncProgress.letterboxdRunning(nil, sources: idle))
    }

    func testPlexWatchlistSyncing() throws {
        let read = try decode(PlexWatchlistRead.self, "plex_watchlist_me_syncing")
        XCTAssertTrue(SyncProgress.plexRunning(read))
        XCTAssertEqual(SyncProgress.percent(read.sync), 59)
        XCTAssertEqual(SyncProgress.line(read.sync, requested: read.counts?.requested ?? read.requestedTotal).plain,
                       "Checking 24 of 41 · 12 requested so far")
        XCTAssertEqual(SyncProgress.cells(read.counts).map(\.value), [12, 2, 0, 2, 1])
        XCTAssertEqual(SyncProgress.cells(read.counts).map(\.label), ["Requested", "In library", "Queued", "Waiting", "Skipped"])
        XCTAssertNil(SyncProgress.queuedHint(read.counts))
        XCTAssertEqual(read.lists.sources.first?.counts?.requested, 3)
        XCTAssertFalse(SyncProgress.plexRunning(try decode(PlexWatchlistRead.self, "plex_watchlist_me_on")))
    }

    func testOlderServerWithoutSyncBlocks() throws {
        let body = #"[{"id":9,"kind":"LETTERBOXD_LIST","enabled":true,"requested_count":3}]"#
        let source = try XCTUnwrap(try APIClient.decoder.decode([LbSource].self, from: Data(body.utf8)).first)
        XCTAssertNil(source.sync)
        XCTAssertNil(source.counts)
        XCTAssertEqual(SyncProgress.variant(source.sync), .idle)
        XCTAssertNil(SyncProgress.percent(source.sync))
        XCTAssertEqual(SyncProgress.cells(source.counts).map(\.value), [0, 0, 0, 0, 0])
        XCTAssertEqual(SyncProgress.line(SourceSync(state: "running")).plain, "Reading the source…")
        XCTAssertEqual(SyncProgress.baselineNote(43), "43 films recorded as baseline")
        XCTAssertEqual(SyncProgress.baselineNote(1), "1 film recorded as baseline")
        XCTAssertNil(SyncProgress.baselineNote(0))
    }

    // MARK: Admin rollup

    func testRequestSourcesSummary() throws {
        let summary = try decode(RequestSourcesSummary.self, "request_sources_summary")
        XCTAssertEqual(summary.runningSources, 1)
        XCTAssertEqual(summary.sources.count, 7)
        XCTAssertEqual(WatchlistsTaskLogic.tone(summary), .running)
        XCTAssertEqual(WatchlistsTaskLogic.overall(summary).plain, "Syncing 1 source · 24 of 38 checked")
        XCTAssertFalse(WatchlistsTaskLogic.hasPlexSource(summary.sources))

        let running = summary.sources[0]
        XCTAssertEqual(WatchlistsTaskLogic.stateLabel(running), "Checking")
        XCTAssertEqual(WatchlistsTaskLogic.detail(running), " · Letterboxd watchlist · example_member")
        XCTAssertEqual(WatchlistsTaskLogic.meta(running, now: now).plain, "24 of 38 · 0 requested · 0 owned · 1 baseline")
        XCTAssertEqual(SyncProgress.percent(running.sync), 63)

        XCTAssertEqual(WatchlistsTaskLogic.stateLabel(summary.sources[1]), "Error")
        XCTAssertEqual(WatchlistsTaskLogic.errorLine(summary.sources[1], now: now), "Letterboxd has no profile with that name")
        XCTAssertEqual(WatchlistsTaskLogic.errorLine(summary.sources[2], now: now),
                       "Letterboxd is blocking automatic reads right now · retrying in 6 hr")
        XCTAssertEqual(WatchlistsTaskLogic.meta(summary.sources[2], now: now).plain, "0 requested · 0 owned · 1 queued · checked 15 hr ago")
        XCTAssertEqual(WatchlistsTaskLogic.detail(summary.sources[3]), " · Letterboxd diary (RSS) · example_member")
        XCTAssertEqual(WatchlistsTaskLogic.meta(summary.sources[3], now: now).plain, "7 requested · 0 owned · checked 38 min ago")
        XCTAssertEqual(WatchlistsTaskLogic.meta(summary.sources[4], now: now).plain, "4 requested · 0 owned · 2 baseline · checked 2 hr ago")
        XCTAssertNil(WatchlistsTaskLogic.errorLine(summary.sources[4]))

        XCTAssertEqual(WatchlistsTaskLogic.todayCells(summary.today).map(\.value), [3, 0, 0, 1])
        XCTAssertEqual(summary.jobs.map(\.name), WatchlistsTaskLogic.jobs)
        XCTAssertEqual(WatchlistsTaskLogic.jobTone(summary.jobs[0]), .paused)
        XCTAssertEqual(WatchlistsTaskLogic.jobHelp(summary.jobs[0]), "Not run yet")
        XCTAssertTrue(WatchlistsTaskLogic.isWatchlistJobRun("plex-watchlist-poll"))
        XCTAssertFalse(WatchlistsTaskLogic.isWatchlistJobRun("RssSync"))
    }

    func testIdleSummaryAndJobTones() throws {
        let body = #"{"running_sources":0,"checked":0,"total":0,"next_run_at":"2026-10-09T21:26:00","today":{}}"#
        let idle = try APIClient.decoder.decode(RequestSourcesSummary.self, from: Data(body.utf8))
        XCTAssertEqual(WatchlistsTaskLogic.tone(idle), .idle)
        XCTAssertEqual(WatchlistsTaskLogic.overall(idle, now: now).plain, "Idle · next source due in 6 min")
        XCTAssertTrue(idle.sources.isEmpty)
        XCTAssertEqual(idle.today.errors, 0)

        let jobs = #"[{"name":"a","running":true},{"name":"b","last_run_at":"2026-10-09T21:00:00","last_status":"failed"},{"name":"c","last_run_at":"2026-10-09T21:00:00","last_status":"completed"}]"#
        let decoded = try APIClient.decoder.decode([SummaryJob].self, from: Data(jobs.utf8))
        XCTAssertEqual(decoded.map { WatchlistsTaskLogic.jobTone($0) }, [.running, .error, .idle])
        XCTAssertEqual(WatchlistsTaskLogic.jobHelp(decoded[2], now: now), "Last run 20 min ago")
        XCTAssertEqual(WatchlistsTaskLogic.kindLabel("PLEX_LIST"), "Plex list")
        XCTAssertEqual(WatchlistsTaskLogic.kindLabel("MDBLIST_LIST"), "mdblist list")
    }
}
