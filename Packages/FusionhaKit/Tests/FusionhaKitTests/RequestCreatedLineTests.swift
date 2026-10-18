import XCTest
@testable import FusionhaKit

/// The `created` line of automatic and re-requested rows and the
/// auto-approved strip's phrase (web `thread-format.ts`, `source-words.ts`).
final class RequestCreatedLineTests: XCTestCase {
    private let sam = try! APIClient.decoder.decode(RequestPerson.self, from: Data(#"{"id":2,"display_name":"Sam"}"#.utf8))

    private func created(_ source: String?, again: Bool? = nil, mine: Bool = false) -> RequestThreadEvent {
        .init(id: 1, kind: "SYSTEM", eventType: "created", actor: sam,
              data: .init(tiers: ["HD_1080P"], source: source, again: again), mine: mine)
    }

    private func line(_ e: RequestThreadEvent, label: String? = nil, owner: String? = nil, kind: String = "MANUAL") -> String {
        RequestThreadFormat.systemLine(e, source: RequestSource(kind: kind, label: label, owner: owner))
    }

    func testManualAndAgain() {
        XCTAssertEqual(line(created(nil)), "Sam requested HD·1080p")
        XCTAssertEqual(line(created("PLEX_LIST", again: true)), "Sam requested it again.")
        XCTAssertEqual(line(created("PLEX_LIST", again: true, mine: true)), "Requested again by you.")
    }

    func testPlex() {
        let tail = ", so fusionha requested it automatically."
        XCTAssertEqual(line(created("PLEX_WATCHLIST", mine: true)), "Added to your Plex watchlist" + tail)
        XCTAssertEqual(line(created("PLEX_WATCHLIST")), "Added to Sam’s Plex watchlist" + tail)
        XCTAssertEqual(line(created("PLEX_LIST"), label: "Kids movies"), "Added to Sam’s Plex list “Kids movies”" + tail)
        XCTAssertEqual(line(created("PLEX_LIST", mine: true)), "Added to one of your Plex lists" + tail)
        XCTAssertEqual(line(created("PLEX_LIST")), "Added to a Plex list of Sam’s" + tail)
    }

    func testLetterboxd() {
        let tail = ", so fusionha requested it automatically."
        XCTAssertEqual(line(created("LETTERBOXD_RSS", mine: true)), "Logged in your Letterboxd diary" + tail)
        XCTAssertEqual(line(created("LETTERBOXD_CSV")), "Imported from Sam’s Letterboxd export" + tail)
        XCTAssertEqual(line(created("LETTERBOXD_WATCHLIST"), owner: "dave"), "Added to @dave’s public Letterboxd watchlist" + tail)
        XCTAssertEqual(line(created("LETTERBOXD_WATCHLIST", mine: true)), "Added to your Letterboxd watchlist" + tail)
        XCTAssertEqual(line(created("LETTERBOXD_LIST")), "Found on a Letterboxd list" + tail)
        XCTAssertEqual(line(created("LETTERBOXD_LIST"), label: "Noir", owner: "dave"),
                       "Found on the Letterboxd list “Noir” by @dave" + tail)
        XCTAssertEqual(line(created("SOMETHING_NEW")), "Sam requested HD·1080p")
    }

    func testDecodesSourceAndAgain() throws {
        let json = #"{"id":9,"kind":"SYSTEM","event_type":"created","data":{"tiers":["HD_1080P"],"source":"PLEX_WATCHLIST","again":true},"created_at":"","mine":true}"#
        let e = try APIClient.decoder.decode(RequestThreadEvent.self, from: Data(json.utf8))
        XCTAssertEqual(e.data?.source, "PLEX_WATCHLIST")
        XCTAssertEqual(e.data?.again, true)
    }

    func testStripPhrase() {
        XCTAssertEqual(RequestSourceWords.stripPhrase(RequestSource(kind: "PLEX_LIST", label: "Kids")), "From the Plex list · Kids")
        XCTAssertEqual(RequestSourceWords.stripPhrase(RequestSource(kind: "PLEX_LIST")), "From the Plex list")
        XCTAssertEqual(RequestSourceWords.stripPhrase(RequestSource(kind: "PLEX_WATCHLIST")), "From the Plex watchlist")
        XCTAssertEqual(RequestSourceWords.stripPhrase(RequestSource(kind: "LETTERBOXD_RSS")), "From a Letterboxd diary")
        XCTAssertEqual(RequestSourceWords.stripPhrase(RequestSource(kind: "LETTERBOXD_LIST", label: "Noir")), "From the Letterboxd list · Noir")
        XCTAssertEqual(RequestSourceWords.stripPhrase(RequestSource(kind: "LETTERBOXD_CSV")), "From a Letterboxd watchlist")
        XCTAssertNil(RequestSourceWords.stripPhrase(RequestSource(kind: "MANUAL")))
        XCTAssertNil(RequestSourceWords.stripPhrase(nil))
    }
}

/// The Users list's source filter and Letterboxd hint.
final class UsersShowFilterTests: XCTestCase {
    private func user(_ provider: String?) -> UserAccount {
        let p = provider.map { #","auth_provider":"\#($0)""# } ?? ""
        return try! APIClient.decoder.decode(UserAccount.self, from: Data(#"{"id":3,"username":"sam","is_admin":false\#(p)}"#.utf8))
    }

    private func plex(_ state: String) -> PlexWatchlistSummaryRow {
        try! APIClient.decoder.decode(PlexWatchlistSummaryRow.self, from: Data(
            #"{"user_id":3,"state":"\#(state)","source_count":1,"requested_count":0}"#.utf8))
    }

    private func lb(_ state: String, requested: Int = 0, linked: Int = 0, diary: Bool = false) -> LetterboxdSummaryRow {
        try! APIClient.decoder.decode(LetterboxdSummaryRow.self, from: Data(
            #"{"user_id":3,"state":"\#(state)","diary_enabled":\#(diary),"requested_count":\#(requested),"linked_count":\#(linked),"blocked_count":0,"degraded_count":0}"#.utf8))
    }

    func testFilters() {
        let u = user("plex")
        XCTAssertTrue(UsersShowFilter.all.passes(user(nil), plex: nil, letterboxd: nil))
        XCTAssertTrue(UsersShowFilter.plex.passes(u, plex: nil, letterboxd: nil))
        XCTAssertFalse(UsersShowFilter.plex.passes(user(nil), plex: nil, letterboxd: nil))
        XCTAssertTrue(UsersShowFilter.watchlist.passes(u, plex: plex("allowed_off"), letterboxd: nil))
        XCTAssertFalse(UsersShowFilter.watchlist.passes(u, plex: plex("not_allowed"), letterboxd: nil))
        XCTAssertFalse(UsersShowFilter.watchlist.passes(u, plex: plex("plex_only"), letterboxd: nil))
        XCTAssertFalse(UsersShowFilter.watchlist.passes(u, plex: nil, letterboxd: nil))
        XCTAssertTrue(UsersShowFilter.letterboxd.passes(u, plex: nil, letterboxd: lb("cant_read")))
        XCTAssertFalse(UsersShowFilter.letterboxd.passes(u, plex: nil, letterboxd: lb("not_connected")))
    }

    func testLetterboxdHint() {
        XCTAssertNil(SourceAdminCopy.letterboxdHint(lb("healthy")))
        XCTAssertEqual(SourceAdminCopy.letterboxdHint(lb("healthy", requested: 4, linked: 1, diary: true)), "4 requested · 2 sources")
        XCTAssertEqual(SourceAdminCopy.letterboxdHint(lb("healthy", requested: 1, linked: 1)), "1 requested · 1 source")
    }
}

/// Avatar letters and hue (web `access-shared.tsx`).
final class PersonInitialsTests: XCTestCase {
    func testInitialsAndHue() {
        XCTAssertEqual(PersonInitials.of("sam.k"), "SK")
        XCTAssertEqual(PersonInitials.of("guest"), "GU")
        XCTAssertEqual(PersonInitials.hue(nil), 220)
        XCTAssertEqual(PersonInitials.hue(1), 138)
        XCTAssertEqual(PersonInitials.hue(3), 53)
    }
}
