import XCTest
@testable import FusionhaKit

/// Automatic request sources (fusionha 0.4.209–0.4.214): the badge words,
/// "Request again", the watchlist rule's sources, the policy's admin layer
/// and who may decide their own request.
final class RequestSourceLogicTests: XCTestCase {
    private func request(id: Int = 1, status: String = "pending", userId: Int? = 7, _ json: String = "") -> MediaRequest {
        var base = #"{"tmdb_id":10,"kind":"movie","tier":"HD-1080p","id":"# + "\(id),\"status\":\"\(status)\""
        if let userId { base += ",\"user_id\":\(userId)" }
        let body = json.isEmpty ? "" : "," + json
        return try! APIClient.decoder.decode(MediaRequest.self, from: Data((base + body + "}").utf8))
    }

    func testBadgeWords() {
        XCTAssertEqual(RequestSourceWords.phrase(nil, mine: true), "Requested in fusionha")
        XCTAssertEqual(RequestSourceWords.phrase(RequestSource(kind: "PLEX_WATCHLIST"), mine: true), "From your Plex watchlist")
        XCTAssertEqual(RequestSourceWords.phrase(RequestSource(kind: "PLEX_WATCHLIST"), mine: false), "Plex watchlist")
        XCTAssertEqual(RequestSourceWords.phrase(RequestSource(kind: "LETTERBOXD_RSS"), mine: true), "From your Letterboxd diary")
        XCTAssertEqual(RequestSourceWords.phrase(RequestSource(kind: "LETTERBOXD_WATCHLIST", owner: "critic"), mine: true),
                       "From @critic’s Letterboxd watchlist")
        XCTAssertEqual(RequestSourceWords.phrase(RequestSource(kind: "LETTERBOXD_WATCHLIST"), mine: false), "Letterboxd watchlist")
        // A joiner gets the kind alone.
        XCTAssertEqual(RequestSourceWords.phrase(RequestSource(kind: "PLEX_LIST"), mine: false), "Plex list")
        XCTAssertEqual(RequestSourceWords.withdrawnWhere(RequestSource(kind: "PLEX_LIST")), "your Plex list")
        XCTAssertEqual(RequestSourceWords.withdrawLabel(RequestSource(kind: "PLEX_WATCHLIST")),
                       "Withdraw request. It won’t be requested again from your watchlist.")
        XCTAssertEqual(RequestSourceWords.withdrawLabel(nil), "Withdraw request")
    }

    func testRequestAgainOnlyForTheOwnersWithdrawnAutomaticRequest() throws {
        let withdrawn = request(status: "withdrawn", #""source":{"kind":"PLEX_WATCHLIST"}"#)
        XCTAssertTrue(RequestSourceWords.canRequestAgain(withdrawn, viewerId: 7))
        XCTAssertFalse(RequestSourceWords.canRequestAgain(withdrawn, viewerId: 8))
        XCTAssertFalse(RequestSourceWords.canRequestAgain(request(status: "withdrawn"), viewerId: 7))
        let body = try JSONSerialization.jsonObject(with: APIClient.encoder.encode(RequestAgainBody(withdrawn))) as? [String: Any]
        XCTAssertEqual(body?["again_of"] as? Int, 1)
        XCTAssertEqual(body?["editions"] as? [String], ["HD-1080p"])
    }

    func testRuleSources() throws {
        func params(_ json: String) throws -> RequestRule.Params {
            try APIClient.decoder.decode(RequestRule.Params.self, from: Data(json.utf8))
        }
        XCTAssertEqual(RuleSource.of(try params(#"{"sources":[]}"#)), RuleSource.allCases)
        XCTAssertEqual(RuleSource.of(try params(#"{}"#)), RuleSource.allCases)
        XCTAssertEqual(RuleSource.of(try params(#"{"sources":["linked","plex_lists"]}"#)), [.plexLists, .linked])
        XCTAssertEqual(RuleSource.of(try params(#"{"plex_source":"watchlist"}"#)), [.plexWatchlist])
        XCTAssertEqual(RuleSource.of(try params(#"{"plex_source":"both"}"#)), [.plexWatchlist, .plexLists])
        XCTAssertEqual(RuleSource.words(RuleSource.allCases), "All automatic sources")
        XCTAssertEqual(RuleSource.sentence([.plexWatchlist], tier: .uhd, roleName: nil),
                       "Approve Plex watchlist requests for UHD·4K from everyone")

        var draft = RequestRuleDraft(kind: .watchlistApprove, tier: nil, sources: [.plexWatchlist])
        let before = draft
        draft.sources = []
        XCTAssertFalse(draft.isValid)
        draft.sources = [.plexWatchlist, .letterboxdDiary]
        guard case .object(let patch) = draft.patchBody(from: before) else { return XCTFail("not an object") }
        XCTAssertEqual(patch["params"], .object(["sources": .array([.string("plex_watchlist"), .string("letterboxd_diary")])]))
    }

    func testPolicyAdminLayer() throws {
        let json = #"{"user_id":3,"role_name":"Trusted","inherited_from":{"auto_request_plex_watchlist":"admin","can_link_lists":"role","quota_per_week":"something_new"},"can_link_lists":null,"max_linked_lists":7}"#
        let p = try APIClient.decoder.decode(RequestPolicy.self, from: Data(json.utf8))
        XCTAssertEqual(p.flagLine("auto_request_plex_watchlist", on: true), "Admin: always on")
        XCTAssertEqual(p.flagLine("can_link_lists", on: false), "Role Trusted: off")
        XCTAssertEqual(p.source("auto_request_plex_watchlist"), "Admin: always allowed")
        // An unknown layer still decodes and reads as something.
        XCTAssertNotNil(p.source("quota_per_week"))
        XCTAssertEqual(p.maxLinkedLists, 7)
    }

    func testSourceChecksWords() {
        XCTAssertEqual(SourceChecksCopy.humanInterval(10), "every 10 minutes")
        XCTAssertEqual(SourceChecksCopy.humanInterval(60), "every hour")
        XCTAssertEqual(SourceChecksCopy.humanInterval(360), "every 6 hours")
        XCTAssertEqual(SourceChecksCopy.humanInterval(1440), "once a day")
        XCTAssertEqual(SourceChecksCopy.presetLabel(360), "6 h")
        XCTAssertEqual(SourceChecksCopy.estimateLine(people: 4, minutes: 10),
                       "With 4 people opted in, each is read every 10 minutes: about 0.40 plex.tv lookups a minute in total.")
        XCTAssertEqual(SourceChecksCopy.hoursWord(1), "1 hour")
    }

    func testAdminsDecideTheirOwnRequests() {
        let mine = request(userId: 7)
        XCTAssertTrue(OwnRequestRule.isOwn(mine, viewerId: 7))
        XCTAssertFalse(OwnRequestRule.locked(mine, viewerId: 7, viewerIsAdmin: true))
        XCTAssertTrue(OwnRequestRule.locked(mine, viewerId: 7, viewerIsAdmin: false))
        XCTAssertFalse(OwnRequestRule.locked(request(userId: 9), viewerId: 7, viewerIsAdmin: false))
        XCTAssertFalse(OwnRequestRule.locked(mine, viewerId: nil, viewerIsAdmin: false))
    }
}
