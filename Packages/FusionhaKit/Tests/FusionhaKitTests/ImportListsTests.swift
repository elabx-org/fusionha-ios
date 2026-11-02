import XCTest
@testable import FusionhaKit

/// Admin import lists (fusionha 0.4.237, phase 10b slice 3): the reads in the
/// OpenAPI shapes (the live summary is a real capture), the words, the form's
/// bodies and the routes.
final class ImportListsTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    static let mdbList = #"""
    {"id": 1, "name": "Top Watched Movies of the Week", "provider": "MDBLIST",
     "url": "https://mdblist.com/lists/linaspurinis/top-watched-movies-of-the-week", "owner": "linaspurinis",
     "list_kind": "LIST", "media_kind": "movie",
     "versions": [{"tier": "HD_1080P", "root_folder_id": null, "quality_profile_id": null},
                  {"tier": "UHD_2160P", "root_folder_id": 4, "quality_profile_id": 9}],
     "monitored": true, "search_on_add": false, "interval_hours": 6, "enabled": true, "status": "OK",
     "last_error": null, "item_count": 20, "added_count": 3, "unmatched_count": 1, "queued_count": 0,
     "last_checked_at": "2026-11-02T10:00:00", "next_check_at": "2026-11-02T16:00:00", "sync_requested_at": null,
     "last_run": {"id": 11, "list_id": 1, "started_at": "2026-11-02T10:00:00", "finished_at": "2026-11-02T10:00:01.400000",
                  "counts": {"added": 3, "owned": 12, "excluded": 1, "unmatched": 1, "skipped_kind": 0, "queued": 3}, "error": null},
     "created_at": "2026-10-12T10:00:00"}
    """#

    func testListDecodes() throws {
        let list = try decode(ImportList.self, Self.mdbList)
        XCTAssertEqual(list.site, .mdblist)
        XCTAssertEqual(list.mediaKind, .movie)
        XCTAssertEqual(list.versions.map(\.tier), [.hd, .uhd])
        XCTAssertEqual(list.version(.uhd)?.rootFolderId, 4)
        XCTAssertEqual(list.lastRun?.counts.total, 20)
        XCTAssertEqual(ImportListCopy.status(list).word, "Healthy")
        XCTAssertEqual(ImportListCopy.runDuration(try XCTUnwrap(list.lastRun)), "1.4 s · 20 read")
        let now = try XCTUnwrap(ServerTime.parse("2026-11-02T12:00:00"))
        XCTAssertEqual(ImportListCopy.meta(list, now: now), "MDBList · every 6 h · last sync added 3 · 2 hr ago")
    }

    func testLiveSummaryAndLedgerDecode() throws {
        // Captured from the live server (0.4.237, no lists yet).
        let live = try decode(ImportListsSummary.self, #"""
        {"running":false,"checked":0,"total":0,"next_run_at":"2026-11-02T18:44:00.000096","lists":[],
         "today":{"added":0,"owned":0,"excluded":0,"errors":0},
         "jobs":[{"name":"import-list-sync","last_run_at":"2026-11-02T18:39:00.000096","last_status":"completed","running":false,"next_run_at":"2026-11-02T18:44:00.000096"}]}
        """#)
        XCTAssertEqual(live.total, 0)
        XCTAssertEqual(live.jobs.map(\.name), ["import-list-sync"])
        let summary = try decode(ImportListsSummary.self, #"""
        {"running": false, "checked": 0, "total": 1, "next_run_at": null, "today": {"added": 4, "owned": 55, "excluded": 1, "errors": 1},
         "jobs": [], "lists": [{"id": 3, "name": "Sight & Sound", "provider": "LETTERBOXD", "media_kind": "movie", "state": "error",
          "counts": {"added": 0, "owned": 212, "excluded": 0, "unmatched": 0, "skipped_kind": 0, "queued": 0},
          "item_count": 212, "last_checked_at": null, "next_check_at": null, "last_error": "Letterboxd is blocking fusionha"}]}
        """#)
        XCTAssertEqual(summary.lists[0].counts.owned, 212)
        XCTAssertEqual(ImportListCopy.kindLine(provider: "LETTERBOXD", mediaKind: "movie"), "Letterboxd · Movies")
        XCTAssertEqual(ImportListCopy.rowState("error").word, "Error")
        let exclusions = try decode([ImportListExclusion].self, #"""
        [{"id": "all-3", "scope": "all", "list_id": null, "tmdb_id": 100, "kind": "movie", "title": "The Room", "year": 2003, "created_at": null},
         {"id": "list-7", "scope": "list", "list_id": 1, "tmdb_id": 101, "kind": "series", "title": null, "year": null, "created_at": null}]
        """#)
        XCTAssertEqual(exclusions.map(\.everyList), [true, false])
        let items = try decode([ImportListItem].self, #"""
        [{"id": 3, "list_id": 1, "external_key": "k3", "tmdb_id": null, "kind": "movie", "title": "The Thing with Feathers",
          "year": 2025, "outcome": "UNMATCHED", "unmatched_reason": "no_match", "media_item_id": null,
          "first_seen_at": "2026-11-02T09:00:00", "last_seen_at": "2026-11-02T10:00:00", "decided_at": null}]
        """#)
        XCTAssertEqual(items[0].label, "The Thing with Feathers (2025)")
        XCTAssertEqual(ImportListCopy.reason(items[0].unmatchedReason), "No title on TMDB matched.")
        let preview = try decode(ImportListPreview.self, #"""
        {"provider": "MDBLIST", "kind": "LIST", "title": "Top", "owner": "o", "item_count": 20, "mix": {"movies": 20, "series": 0},
         "in_library_count": 12, "excluded_count": 1, "would_add": 7, "first_sync_adds": 7,
         "items": [{"title": "Sinners", "year": 2025, "kind": "movie", "tmdb_id": 1, "in_library": false, "excluded": false, "poster_url": null}]}
        """#)
        XCTAssertEqual(preview.wouldAdd, 7)
        XCTAssertEqual(preview.items.first?.tmdbId, 1)
    }

    func testWords() throws {
        XCTAssertEqual(ImportListCopy.every(6), "6 h")
        XCTAssertEqual(ImportListCopy.every(24), "24 h")
        XCTAssertEqual(ImportListCopy.every(168), "7 days")
        XCTAssertEqual(ImportListCopy.outcome("SKIPPED_KIND").word, "Skipped")
        XCTAssertEqual(ImportListCopy.unmatched(1), "1 title couldn’t be matched")
        XCTAssertEqual(ImportListCopy.reviewDesc(2, list: "Trending"),
                       "2 titles from Trending couldn’t be matched. Choose what each is, or ignore it.")
        let paused = try decode(ImportList.self, Self.mdbList.replacingOccurrences(of: #""enabled": true"#, with: #""enabled": false"#))
        XCTAssertEqual(ImportListCopy.status(paused).word, "Paused")
        XCTAssertNil(ImportListCopy.problem(APIError.http(status: 429, body: #"{"detail": {"code": "rate_limited"}}"#)))
        let trakt = try XCTUnwrap(ImportListCopy.problem(APIError.http(status: 409, body: #"{"detail": {"code": "provider_unavailable"}}"#)))
        XCTAssertTrue(trakt.fatal && trakt.traktLink)
        XCTAssertFalse(try XCTUnwrap(ImportListCopy.problem(APIError.http(status: 503, body: #"{"detail": {"code": "unavailable"}}"#))).fatal)
        XCTAssertEqual(ImportListCopy.serverMessage(APIError.http(status: 422, body: #"{"detail": {"code": "duplicate_tier", "detail": "each tier once"}}"#)),
                       "each tier once")
        XCTAssertEqual(ImportListCopy.serverMessage(APIError.http(status: 500, body: "oops")), "Couldn’t save. Try again.")
    }

    // MARK: Form

    func testNewDraftBody() throws {
        var draft = ImportListDraft()
        XCTAssertFalse(draft.canSave(problemIsFatal: false), "no address yet")
        draft.url = " https://letterboxd.com/dave/list/sight/ "
        draft.provider = "LETTERBOXD"
        draft.uhd = .init(on: true, rootFolderId: 4)
        XCTAssertEqual(draft.effectiveInterval, 12, "Letterboxd is read at most every 12 hours")
        XCTAssertFalse(draft.intervalAllowed(6))
        XCTAssertFalse(draft.canSave(problemIsFatal: true))
        XCTAssertTrue(draft.canSave(problemIsFatal: false))
        let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.createBody)) as? NSDictionary
        XCTAssertEqual(body?["url"] as? String, "https://letterboxd.com/dave/list/sight/")
        XCTAssertEqual(body?["interval_hours"] as? Int, 12)
        XCTAssertNil(body?["name"], "an empty name lets the server use the list’s own")
        let versions = try XCTUnwrap(body?["versions"] as? [NSDictionary])
        XCTAssertEqual(versions.map { $0["tier"] as? String }, ["HD_1080P", "UHD_2160P"])
        XCTAssertEqual(versions[1]["root_folder_id"] as? Int, 4)
        XCTAssertTrue(versions[0]["quality_profile_id"] is NSNull)
        draft.hd.on = false
        draft.uhd.on = false
        XCTAssertFalse(draft.canSave(problemIsFatal: false), "at least one tier")
    }

    func testEditDraftPatch() throws {
        var draft = ImportListDraft(editing: try decode(ImportList.self, Self.mdbList))
        XCTAssertTrue(draft.editing)
        XCTAssertTrue(draft.uhd.custom)
        draft.name = "  "
        let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.patchBody(fallbackName: "Top"))) as? NSDictionary
        XCTAssertEqual(body?["name"] as? String, "Top")
        XCTAssertNil(body?["url"])
        XCTAssertTrue(draft.canSave(problemIsFatal: true))
    }
}

/// The slice 3 routes through the canned-response stub.
final class ImportListsAPITests: XCTestCase {
    private func client(_ json: String, status: Int = 200) -> APIClient {
        ItemActionsStubProtocol.responseBody = Data(json.utf8)
        ItemActionsStubProtocol.status = status
        ItemActionsStubProtocol.lastRequest = nil
        ItemActionsStubProtocol.lastBody = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ItemActionsStubProtocol.self]
        return APIClient(baseURL: URL(string: "http://fh.test")!, token: "k", session: URLSession(configuration: config))
    }

    private var sent: URLRequest? { ItemActionsStubProtocol.lastRequest }

    private func sentJSON() throws -> NSDictionary {
        let body = try XCTUnwrap(ItemActionsStubProtocol.lastBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? NSDictionary)
    }

    func testRoutes() async throws {
        _ = try await client("[]").importLists()
        XCTAssertEqual(sent?.url?.path, "/api/v1/import-lists")
        _ = try await client(#"{"provider": "TRAKT", "mix": {"movies": 0, "series": 3}, "items": []}"#)
            .previewImportList(url: "https://trakt.tv/users/a/lists/b", mediaKind: .anime)
        XCTAssertEqual(sent?.url?.path, "/api/v1/import-lists/preview")
        XCTAssertEqual(try sentJSON()["media_kind"] as? String, "anime")
        try await client(ImportListsTests.mdbList, status: 202).syncImportList(1)
        XCTAssertEqual(sent?.httpMethod, "POST")
        XCTAssertEqual(sent?.url?.path, "/api/v1/import-lists/1/sync")
        try await client("", status: 204).deleteImportList(1)
        XCTAssertEqual(sent?.httpMethod, "DELETE")
        _ = try await client("[]").importListExclusions(listId: 2)
        XCTAssertEqual(sent?.url?.query, "list_id=2")
        try await client("", status: 204).removeImportListExclusion("list-7")
        XCTAssertEqual(sent?.url?.path, "/api/v1/import-lists/exclusions/list-7")
        _ = try await client("[]").importListRunItems(31)
        XCTAssertEqual(sent?.url?.path, "/api/v1/import-lists/runs/31/items")
    }

    func testReviewAndExclusionBodies() async throws {
        let item = #"{"id": 3, "list_id": 1, "external_key": "k3", "outcome": "ADDED", "first_seen_at": "x", "last_seen_at": "x"}"#
        _ = try await client(item).resolveImportListItem(1, itemId: 3, tmdbId: 550, kind: .movie)
        XCTAssertEqual(sent?.url?.path, "/api/v1/import-lists/1/items/3/resolve")
        XCTAssertEqual(try sentJSON(), ["tmdb_id": 550, "kind": "movie"] as NSDictionary)
        _ = try await client(item).ignoreImportListItem(1, itemId: 3, everywhere: true)
        XCTAssertEqual(try sentJSON(), ["everywhere": true] as NSDictionary)
        let excl = #"{"id": "all-3", "scope": "all", "kind": "movie"}"#
        _ = try await client(excl, status: 201).addImportListExclusion(tmdbId: 100, kind: .movie, title: "The Room", year: 2003, listId: nil)
        let body = try sentJSON()
        XCTAssertEqual(body["tmdb_id"] as? Int, 100)
        XCTAssertTrue(body["list_id"] is NSNull)
    }
}
