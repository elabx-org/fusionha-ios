import XCTest
@testable import FusionhaKit

final class DecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testQueuePageDecodes() throws {
        let page = try decoder.decode(QueuePage.self, from: fixture("queue"))
        XCTAssertEqual(page.total, 1)
        let item = try XCTUnwrap(page.items.first)
        XCTAssertEqual(item.tier, .uhd)
        XCTAssertEqual(item.fraction, 0.6, accuracy: 0.0001)
        XCTAssertEqual(item.posterUrl, "https://image.tmdb.org/t/p/w500/abc.jpg")
    }

    func testLibraryDecodesEditionsAndWireStatuses() throws {
        let items = try decoder.decode([LibraryItem].self, from: fixture("library"))
        let editions = try XCTUnwrap(items.first?.editions)
        XCTAssertEqual(editions.map(\.tier), [.hd, .uhd])
        XCTAssertEqual(editions.map(\.status), [.downloaded, .downloading])
        XCTAssertEqual(editions[1].movieEdition, "Director's Cut")
    }

    func testUnknownStatusDoesNotThrow() {
        XCTAssertEqual(EditionStatus(rawValue: "brand-new"), .other("brand-new"))
        XCTAssertEqual(EditionStatus(rawValue: "wanted"), .missing)
    }

    func testServerURLNormalisation() {
        XCTAssertEqual(APIClient.normalisedServerURL("192.168.1.10:8787/")?.absoluteString, "http://192.168.1.10:8787")
        XCTAssertEqual(APIClient.normalisedServerURL(" https://fh.example.com ")?.absoluteString, "https://fh.example.com")
        XCTAssertNil(APIClient.normalisedServerURL(""))
    }

    func testTMDBResize() {
        XCTAssertEqual(
            TMDBImage.resized("https://image.tmdb.org/t/p/w500/abc.jpg", to: "w185")?.absoluteString,
            "https://image.tmdb.org/t/p/w185/abc.jpg")
    }
}
