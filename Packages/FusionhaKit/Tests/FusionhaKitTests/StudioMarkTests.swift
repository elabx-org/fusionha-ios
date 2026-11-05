import XCTest
@testable import FusionhaKit

/// `studios` on the item detail (StudioRead) and the v2 network mark pick.
final class StudioMarkTests: XCTestCase {
    private func decode(_ json: String) throws -> ItemDetail {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return try d.decode(ItemDetail.self, from: Data(json.utf8))
    }

    func testDecodesStudiosAndPicksTheFirstWithALogo() throws {
        let detail = try decode("""
        {"id": 7, "title": "Andor", "kind": "series", "studios": [
          {"name": "Lucasfilm", "logo_url": null},
          {"name": "Disney+", "logo_url": "https://image.tmdb.org/t/p/original/disney.png"},
          {"name": "Other", "logo_url": "https://image.tmdb.org/t/p/original/other.png"}
        ]}
        """)
        XCTAssertEqual(detail.studios?.count, 3)
        XCTAssertNil(detail.studios?.first?.logoUrl)
        XCTAssertEqual(detail.networkMark?.name, "Disney+")
        XCTAssertEqual(detail.networkMark?.logoUrl, "https://image.tmdb.org/t/p/original/disney.png")
    }

    func testOlderServerWithoutStudiosStillDecodes() throws {
        let detail = try decode(#"{"id": 1, "title": "Heat", "kind": "movie"}"#)
        XCTAssertNil(detail.studios)
        XCTAssertNil(detail.networkMark)
    }

    func testNoMarkWithoutALogo() {
        XCTAssertNil(Studio.mark(in: []))
        XCTAssertNil(Studio.mark(in: [Studio(name: "A", logoUrl: nil), Studio(name: "B", logoUrl: " ")]))
    }
}
