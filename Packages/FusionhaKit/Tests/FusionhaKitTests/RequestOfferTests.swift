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
