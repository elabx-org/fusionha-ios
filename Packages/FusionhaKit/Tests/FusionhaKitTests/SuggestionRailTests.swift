import XCTest
@testable import FusionhaKit

final class SuggestionRailTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String, as: T.Type = T.self) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func quota(used: Int, limit: Int?) throws -> RequestQuota {
        let limitJSON = limit.map(String.init) ?? "null"
        return try decode(#"{"used":\#(used),"limit":\#(limitJSON),"auto_used":0,"auto_limit":null,"resets_at":"2026-10-26T00:00:00Z","waiting":0}"#)
    }

    func testActionPrecedence() {
        XCTAssertEqual(SuggestionRail.action(askedCount: 3, done: .requested, overLimit: true), .done(.requested))
        XCTAssertEqual(SuggestionRail.action(askedCount: 2, done: nil, overLimit: true), .meToo(asked: 2))
        XCTAssertEqual(SuggestionRail.action(askedCount: 0, done: nil, overLimit: false), .request(overLimit: false))
        XCTAssertEqual(SuggestionRail.action(askedCount: 0, done: nil, overLimit: true), .request(overLimit: true))
    }

    func testLabelsAndToasts() {
        XCTAssertEqual(SuggestionRail.primaryLabel(overLimit: false), "Request")
        XCTAssertEqual(SuggestionRail.primaryLabel(overLimit: true), "Add to wishlist")
        XCTAssertEqual(SuggestionRail.askedLine(4), "4 asked already")
        XCTAssertEqual(SuggestionRail.Done.requested.label, "Requested")
        XCTAssertEqual(SuggestionRail.Done.wishlist.label, "On your wishlist")
        XCTAssertEqual(SuggestionRail.done(afterRequest: true), .wishlist)
        XCTAssertEqual(SuggestionRail.done(afterRequest: false), .requested)
        XCTAssertEqual(SuggestionRail.requestedToast("Heat", wishlist: false), "Heat requested")
        XCTAssertEqual(SuggestionRail.requestedToast("Heat", wishlist: true), "Heat added to your wishlist")
        XCTAssertEqual(SuggestionRail.joinedToast("Heat"), "Joined · Heat")
    }

    func testTierOptions() {
        XCTAssertEqual(SuggestionRail.tierOptions(uhdAllowed: false).map(\.tiers), [[.hd]])
        XCTAssertEqual(SuggestionRail.tierOptions(uhdAllowed: true).map(\.label), ["HD·1080p", "HD·1080p + UHD·4K"])
        XCTAssertEqual(SuggestionRail.tierOptions(uhdAllowed: true).last?.tiers, [.hd, .uhd])
    }

    func testOverLimitAndPip() throws {
        XCTAssertFalse(SuggestionRail.overLimit(nil))
        XCTAssertFalse(SuggestionRail.overLimit(try quota(used: 9, limit: nil)))
        XCTAssertFalse(SuggestionRail.overLimit(try quota(used: 2, limit: 5)))
        XCTAssertTrue(SuggestionRail.overLimit(try quota(used: 5, limit: 5)))

        let unlimited = SuggestionRail.pip(try quota(used: 1, limit: nil))
        XCTAssertEqual(unlimited.strong, "Unlimited")
        XCTAssertEqual(unlimited.rest, " requests")
        XCTAssertNil(unlimited.fraction)

        let some = SuggestionRail.pip(try quota(used: 2, limit: 5))
        XCTAssertEqual(some.strong, "3 of 5")
        XCTAssertEqual(some.rest, " left this week")
        XCTAssertEqual(some.fraction ?? 0, 0.6, accuracy: 0.001)
        XCTAssertFalse(some.low)

        let over = SuggestionRail.pip(try quota(used: 7, limit: 5))
        XCTAssertEqual(over.strong, "0 of 5")
        XCTAssertEqual(over.rest, " left this week · over limit")
        XCTAssertTrue(over.low)
    }

    func testChipsHintAndStale() throws {
        let read: SuggestionsRead = try decode("""
        {"visible":true,
         "items":[{"tmdb_id":1,"kind":"movie","title":"A","source_id":7,"source_label":"Watchlist","asked_count":0,"stale":true},
                  {"tmdb_id":2,"kind":"movie","title":"B","source_id":7,"stale":true},
                  {"tmdb_id":3,"kind":"movie","title":"C","source_id":8,"stale":true},
                  {"tmdb_id":4,"kind":"movie","title":"D","source_id":9}],
         "sources":[{"source_id":7,"label":"Watchlist","count":2}]}
        """)
        let chips = SuggestionRail.chips(read)
        XCTAssertEqual(chips.map(\.text), ["All 4", "Watchlist 2"])
        XCTAssertNil(chips.first?.sourceId)

        let none: SuggestionsRead = try decode(#"{"visible":true,"items":[],"sources":[]}"#)
        XCTAssertTrue(SuggestionRail.chips(none).isEmpty)

        XCTAssertEqual(SuggestionRail.staleSources(read.items), 2)
        XCTAssertNil(SuggestionRail.hintText(itemCount: 0, staleSources: 2))
        XCTAssertEqual(SuggestionRail.hintText(itemCount: 3, staleSources: 0), SuggestionRail.hint)
        XCTAssertEqual(SuggestionRail.hintText(itemCount: 3, staleSources: 1),
                       SuggestionRail.hint + " 1 source couldn’t be checked and shows its last good check.")
        XCTAssertEqual(SuggestionRail.hintText(itemCount: 3, staleSources: 2),
                       SuggestionRail.hint + " 2 sources couldn’t be checked and show their last good check.")
    }

    func testGate() throws {
        XCTAssertFalse(SuggestionRail.gated(nil))
        let off: LetterboxdRead = try decode(#"{"username":null,"status":"not_connected","linked_count":0}"#)
        XCTAssertFalse(SuggestionRail.gated(off))
        let linked: LetterboxdRead = try decode(#"{"username":null,"status":"not_connected","linked_count":2}"#)
        XCTAssertTrue(SuggestionRail.gated(linked))
        let user: LetterboxdRead = try decode(#"{"username":"ana","status":"OK","linked_count":0}"#)
        XCTAssertTrue(SuggestionRail.gated(user))
    }
}
