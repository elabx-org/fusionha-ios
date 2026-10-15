import XCTest
@testable import FusionhaKit

final class RequestOfferTests: XCTestCase {
    private let demand = RequestTitleDemand(tmdbId: 1, state: "me_too", asked: 2, joinableTiers: [.hd],
                                            watchTiers: [.uhd], requestableTiers: [.hd, .uhd])

    func testActs() {
        XCTAssertEqual(RequestOffer.act(demand, tier: .hd), .join)
        XCTAssertEqual(RequestOffer.act(demand, tier: .uhd), .watch)
        XCTAssertEqual(RequestOffer.act(nil, tier: .hd), .new)
        XCTAssertTrue(RequestOffer.tagged(demand))
        XCTAssertFalse(RequestOffer.tagged(RequestTitleDemand(tmdbId: 1, state: "request", requestableTiers: [.hd])))
    }

    func testTiersPreferDemand() {
        XCTAssertEqual(RequestOffer.tiers(demand: demand, fallback: [.hd]), [.hd, .uhd])
        XCTAssertEqual(RequestOffer.tiers(demand: nil, fallback: [.hd]), [.hd])
    }

    func testSubmitLabel() {
        XCTAssertEqual(RequestOffer.submitLabel([]), "Request")
        XCTAssertEqual(RequestOffer.submitLabel([.join, .new]), "Request")
        XCTAssertEqual(RequestOffer.submitLabel([.join, .watch]), "Me too")
        XCTAssertEqual(RequestOffer.submitLabel([.watch]), "Watch")
    }

    func testSummary() {
        XCTAssertEqual(RequestOffer.summary([(.hd, .join), (.uhd, .new)], limited: true),
                       "Me too on HD·1080p · free · New request for UHD·4K · uses 1 of your quota")
        XCTAssertEqual(RequestOffer.summary([(.uhd, .watch)], limited: false), "Watch on UHD·4K · free")
    }

    func testDecodesDemandWithDefaults() throws {
        let json = #"[{"tmdb_id":5,"kind":"movie","state":"request"}]"#
        let rows = try APIClient.decoder.decode([RequestTitleDemand].self, from: Data(json.utf8))
        XCTAssertEqual(rows.first?.asked, 0)
        XCTAssertEqual(rows.first?.requestableTiers, [])
    }

    func testCreateBodyEncodesJoinAndWishlist() throws {
        let body = RequestCreateBody(tmdbId: 1, kind: .movie, editions: [.hd], wishlist: true)
        let json = String(decoding: try APIClient.encoder.encode(body), as: UTF8.self)
        XCTAssertTrue(json.contains("\"wishlist\":true"))
        XCTAssertTrue(json.contains("\"join\":false"))
    }
}

final class DiscoverCardDemandTests: XCTestCase {
    func testRows() {
        let meToo = RequestTitleDemand(tmdbId: 1, state: "me_too", asked: 2, joinableTiers: [.hd])
        XCTAssertEqual(DiscoverCardDemand.view(meToo, requestMode: true, titleInLibrary: false).row, .meToo)
        XCTAssertNil(DiscoverCardDemand.view(meToo, requestMode: false, titleInLibrary: false).row)
        let joined = RequestTitleDemand(tmdbId: 1, state: "joined", asked: 3, requestId: 9)
        XCTAssertTrue(DiscoverCardDemand.view(joined, requestMode: true, titleInLibrary: false).hideRequested)
        let watch = RequestTitleDemand(tmdbId: 1, state: "watch", watchTiers: [.uhd])
        XCTAssertEqual(DiscoverCardDemand.view(watch, requestMode: true, titleInLibrary: false).row, .watch)
        let elsewhere = RequestTitleDemand(tmdbId: 1, state: "request", requestableTiers: [.hd])
        let view = DiscoverCardDemand.view(elsewhere, requestMode: true, titleInLibrary: true)
        XCTAssertEqual(view.row, .requestTiers)
        XCTAssertFalse(view.inLibrary)
        let watching = RequestTitleDemand(tmdbId: 1, state: "mine", watching: true)
        XCTAssertTrue(DiscoverCardDemand.view(watching, requestMode: true, titleInLibrary: false).watching)
    }

    func testRequestTiersLabel() {
        XCTAssertEqual(DiscoverCardDemand.requestTiersLabel([.hd, .uhd]), "Request HD + 4K")
        XCTAssertEqual(DiscoverCardDemand.requestTiersLabel([]), "Request")
    }
}
