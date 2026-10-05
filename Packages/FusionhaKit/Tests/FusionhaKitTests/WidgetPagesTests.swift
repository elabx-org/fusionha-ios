import XCTest
@testable import FusionhaKit

final class WidgetPagesTests: XCTestCase {
    private let now = CalendarMath.parseUTC("2026-10-04T12:00:00Z")!

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(T.self, from: Data(json.utf8))
    }

    func testAvailablePagesOrderAndGating() {
        let all = Set(WidgetPage.allCases)
        XCTAssertEqual(WidgetPage.available(enabled: all, downloading: true, requestsAllowed: true), WidgetPage.allCases)
        XCTAssertEqual(WidgetPage.available(enabled: all, downloading: false, requestsAllowed: false),
                       [.upNext, .recent, .library, .indexers, .wanted])
        XCTAssertEqual(WidgetPage.available(enabled: [.wanted, .downloading], downloading: false, requestsAllowed: true),
                       [.wanted])
        // Nothing enabled: still one page to show.
        XCTAssertEqual(WidgetPage.available(enabled: [], downloading: false, requestsAllowed: true), [.upNext])
        XCTAssertEqual(WidgetPage.available(enabled: [.requests], downloading: true, requestsAllowed: false), [.downloading])
    }

    func testCurrentAndNextWrap() {
        let pages: [WidgetPage] = [.upNext, .recent, .library]
        XCTAssertEqual(WidgetPage.current(stored: .recent, in: pages), .recent)
        XCTAssertEqual(WidgetPage.current(stored: .downloading, in: pages), .upNext)
        XCTAssertEqual(WidgetPage.current(stored: nil, in: pages), .upNext)
        XCTAssertEqual(WidgetPage.next(after: .upNext, in: pages), .recent)
        XCTAssertEqual(WidgetPage.next(after: .library, in: pages), .upNext)
        XCTAssertEqual(WidgetPage.next(after: .wanted, in: pages), .upNext)
        XCTAssertEqual(WidgetPage(rawValue: "upnext"), .upNext)
    }

    func testPageRoutes() {
        XCTAssertEqual(WidgetRoute.page(.downloading).url.absoluteString, "fusionha://activity")
        XCTAssertEqual(WidgetRoute.page(.upNext).url.absoluteString, "fusionha://calendar")
        XCTAssertEqual(WidgetRoute.page(.recent).url.absoluteString, "fusionha://library")
        XCTAssertEqual(WidgetRoute.page(.indexers).url.absoluteString, "fusionha://activity/indexers")
        XCTAssertEqual(WidgetRoute.page(.wanted).url.absoluteString, "fusionha://wanted")
        XCTAssertEqual(WidgetRoute.page(.requests).url.absoluteString, "fusionha://discover/requests")
    }

    func testLibrarySummary() throws {
        let items = try decode([MediaItem].self, """
            [{"id":1,"title":"Movie","kind":"movie","is_anime":false,"is_animation":false,"monitored":true,
              "is_available":true,"editions":[
                {"id":1,"tier":"HD-1080p","monitored":true,"status":"done","have":1,"total":1},
                {"id":2,"tier":"UHD-2160p","monitored":true,"status":"wanted","have":0,"total":1}]},
             {"id":2,"title":"Show","kind":"series","is_anime":false,"is_animation":false,"monitored":true,
              "is_available":true,"editions":[
                {"id":3,"tier":"HD-1080p","monitored":true,"status":"grabbing","have":3,"total":8}]},
             {"id":3,"title":"Anime","kind":"series","is_anime":true,"monitored":true,"is_available":true,
              "editions":[{"id":4,"tier":"HD-1080p","monitored":true,"status":"done","have":12,"total":12}]},
             {"id":4,"title":"Soon","kind":"movie","is_anime":false,"is_animation":true,"monitored":true,
              "is_available":false,"editions":[{"id":5,"tier":"HD-1080p","monitored":true,"status":"wanted","have":0,"total":1}]}]
            """)
        let s = WidgetLibrarySummary(items)
        XCTAssertEqual(s.titles, 4)
        XCTAssertEqual(s.versions, 5)
        XCTAssertEqual([s.movies, s.series, s.anime], [1, 1, 2])
        XCTAssertEqual(s.missing, 1)
        XCTAssertEqual(s.downloading, 1)
        XCTAssertEqual(s.complete, 1)
        XCTAssertEqual(s.upcoming, 1)
        XCTAssertEqual(s.fourKTitles, 1)
        XCTAssertEqual(s.fourKPercent, 25)
        // Round-trips through the widget's cache.
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(WidgetLibrarySummary.self, from: data), s)
    }

    func testIndexerSummary() throws {
        let stats = try decode(ActivityIndexerStats.self, """
            {"indexers":[
              {"id":1,"name":"Small","health":{"state":"healthy"},"grabs_range":6,"queries_range":100,
               "success_rate_range":0.9,"activity_series":[1,2,3]},
              {"id":2,"name":"Big","health":{"state":"healthy"},"grabs_range":40,"queries_range":600,
               "success_rate_range":0.97,"activity_series":[5,6,7]},
              {"id":3,"name":"Flaky","health":{"state":"backoff","failure_count":3},"grabs_range":2,
               "success_rate_range":0.71},
              {"id":4,"name":"Gone","health":{"state":"disabled"},"grabs_range":50}
            ],"summary":{"range":"7d","indexers":4,"healthy":2,"backoff":1,"off":1,"grabs_range":48,
              "queries_range":1341,"avg_success_range":0.92}}
            """)
        let unavailable = try decode(ItemsEnvelope<UnavailableIndexer>.self, """
            {"count":1,"items":[{"indexer_id":3,"name":"Flaky","disabled_till":"2026-10-04T12:12:00Z","reason":"HTTP 503"}]}
            """).items
        let s = WidgetIndexerSummary(stats: stats, unavailable: unavailable, now: now, top: 2)
        XCTAssertEqual([s.healthy, s.backingOff, s.off], [2, 1, 1])
        XCTAssertEqual(s.successPercent, 92)
        XCTAssertEqual(s.top.map(\.name), ["Big", "Small"])
        XCTAssertEqual(s.top[0].successPercent, 97)
        XCTAssertEqual(s.top[0].series, [5, 6, 7])
        XCTAssertEqual(s.flagged, [WidgetIndexerFlag(name: "Flaky", detail: "unavailable · retry in 12m"),
                                   WidgetIndexerFlag(name: "Gone", detail: "off")])
        XCTAssertEqual(s.line, "48 grabs · 1.3k queries · 4 indexers")
        XCTAssertEqual(WidgetIndexerSummary.compact(950), "950")
        XCTAssertEqual(WidgetIndexerSummary.compact(2000), "2k")
        XCTAssertEqual(WidgetIndexerSummary.compact(12_400), "12k")
        XCTAssertEqual(WidgetIndexerSummary.compact(1_300_000), "1.3M")
    }

    func testWantedSummary() throws {
        let page = try decode(WantedPage.self, """
            {"total":6,"missing_count":9,"cutoff_unmet_count":10,"missing_titles":6,"cutoff_unmet_titles":7,"items":[
              {"id":8,"title":"Breaking Bad","kind":"series","is_anime":false,"poster_url":"b.jpg","editions":[
                {"edition_id":11,"tier":"UHD-2160p","state":"missing","missing_episode_count":3},
                {"edition_id":12,"tier":"HD-1080p","state":"missing","missing_episode_count":1}]},
              {"id":1,"title":"The Matrix","kind":"movie","is_anime":false,"editions":[
                {"edition_id":1,"tier":"HD-1080p","state":"missing"}]},
              {"id":2,"title":"A","kind":"movie","is_anime":false,"editions":[]},
              {"id":3,"title":"B","kind":"movie","is_anime":false,"editions":[]}
            ]}
            """)
        let fourK = try decode(FourKAvailablePage.self, #"{"items":[],"total":2,"fourk_available_count":5}"#)
        let s = WidgetWantedSummary(missing: page, fourK: fourK)
        XCTAssertEqual(s.missing, 6)
        XCTAssertEqual(s.cutoffUnmet, 7)
        XCTAssertEqual(s.fourKAvailable, 5)
        XCTAssertEqual(s.rows.map(\.itemId), [8, 1, 2])
        XCTAssertEqual(s.rows[0].tiers, [.hd, .uhd])
        XCTAssertEqual(s.rows[0].detail, "3 episodes missing")
        XCTAssertEqual(s.rows[1].detail, "Movie")
        XCTAssertNil(WidgetWantedSummary(missing: page, fourK: nil).fourKAvailable)
    }

    func testRequestsSummary() throws {
        let requests = try decode([MediaRequest].self, """
            [{"id":1,"user_id":4,"tmdb_id":10,"kind":"movie","tier":"UHD-2160p","editions":["UHD-2160p"],
              "seasons":[],"status":"pending","requested_at":"2026-10-04T10:00:00"},
             {"id":2,"user_id":5,"tmdb_id":11,"kind":"series","tier":"HD-1080p","editions":["HD-1080p","UHD-2160p"],
              "seasons":[1,2],"status":"pending","requested_at":"2026-10-04T11:00:00"},
             {"id":3,"user_id":4,"tmdb_id":12,"kind":"movie","tier":"HD-1080p","status":"approved"},
             {"id":4,"user_id":4,"tmdb_id":13,"kind":"movie","tier":"HD-1080p","status":"fulfilled","media_item_id":9}]
            """)
        let issues = try decode([MediaIssue].self, """
            [{"id":1,"media_item_id":8,"reporter_user_id":4,"issue_type":"audio","scope":"episode","season":2,
              "episode":5,"status":"open","created_at":"2026-10-04T09:00:00"},
             {"id":2,"media_item_id":1,"reporter_user_id":6,"issue_type":"playback","scope":"item","status":"open",
              "created_at":"2026-10-03T09:00:00"}]
            """)
        let s = WidgetRequestsSummary(requests: requests, openIssues: issues)
        XCTAssertEqual([s.pending, s.inProgress, s.openIssues], [2, 1, 2])
        XCTAssertEqual(s.newest.map(\.id), [2, 1])
        XCTAssertEqual(s.newest[0].seasons, "Seasons 1–2")
        XCTAssertEqual(s.newest[0].tiers, [.hd, .uhd])
        XCTAssertNil(s.newest[1].seasons)
        XCTAssertEqual(s.issue?.mediaItemId, 8)
        XCTAssertEqual(s.issue?.label, "Audio · S02E05")
        XCTAssertEqual(WidgetRequestsSummary.seasonsLabel([3]), "Season 3")
        XCTAssertEqual(WidgetRequestsSummary.seasonsLabel([1, 3, 5]), "Seasons 1, 3, 5")
        XCTAssertNil(WidgetRequestsSummary.seasonsLabel([]))
    }

    func testUserNamesDecode() throws {
        let users = try decode([WidgetUserName].self, """
            [{"id":4,"username":"elmer","is_admin":true},{"id":6,"username":"sam (plex:123)","is_admin":false}]
            """)
        XCTAssertEqual(users.map(\.display), ["elmer", "sam"])
    }

    func testTimeLeft() {
        XCTAssertEqual(WidgetFeeds.timeLeft(fraction: 0.5, ageSeconds: 600), "10m left")
        XCTAssertEqual(WidgetFeeds.timeLeft(fraction: 0.25, ageSeconds: 3600), "3h left")
        XCTAssertEqual(WidgetFeeds.timeLeft(fraction: 0.4, ageSeconds: 3600), "1h 30m left")
        XCTAssertNil(WidgetFeeds.timeLeft(fraction: 0.01, ageSeconds: 600))
        XCTAssertNil(WidgetFeeds.timeLeft(fraction: 0.5, ageSeconds: nil))
        XCTAssertNil(WidgetFeeds.timeLeft(fraction: 0.5, ageSeconds: 600, stalled: true))
        XCTAssertNil(WidgetFeeds.timeLeft(fraction: 1, ageSeconds: 600))
    }
}
