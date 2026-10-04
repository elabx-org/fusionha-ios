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
        let data = try fixture("library")
        let items: [MediaItem] = try decoder.decode([MediaItem].self, from: data)
        XCTAssertEqual(items.count, 1)
        let editions: [Edition] = items[0].editions
        let tiers: [QualityTier] = editions.map { $0.tier }
        let statuses: [EditionStatus] = editions.map { $0.status }
        XCTAssertEqual(tiers, [QualityTier.hd, QualityTier.uhd])
        XCTAssertEqual(statuses, [EditionStatus.downloaded, EditionStatus.downloading])
        XCTAssertEqual(editions[1].movieEdition, "Director's Cut")
    }

    func testSetupStatusAndPlexPinDecode() throws {
        let status = try decoder.decode(SetupStatus.self, from: Data(#"""
            {"needs_setup": false, "demo_mode": false, "plex_sso_enabled": true, "local_login_enabled": false}
            """#.utf8))
        XCTAssertTrue(status.offersPlex)
        XCTAssertFalse(status.offersPassword)

        let styled = try decoder.decode(SetupStatus.self, from: Data(#"""
            {"needs_setup": false, "login_style": "aurora", "login_layout": "centered",
             "login_background": "aurora", "login_show_logo": true, "login_show_wordmark": false,
             "login_show_tagline": false, "plex_sso_enabled": true, "local_login_enabled": true}
            """#.utf8))
        XCTAssertEqual(styled.loginBackground, "aurora")
        XCTAssertEqual(styled.loginShowLogo, true)

        let legacy = try decoder.decode(SetupStatus.self, from: Data(#"{"needs_setup": false}"#.utf8))
        XCTAssertFalse(legacy.offersPlex)
        XCTAssertTrue(legacy.offersPassword)

        let pin = try decoder.decode(PlexPin.self, from: Data(#"""
            {"id": 42, "code": "abcd", "authUrl": "https://app.plex.tv/auth#?code=abcd"}
            """#.utf8))
        XCTAssertEqual(pin.id, 42)
        XCTAssertEqual(pin.authUrl, "https://app.plex.tv/auth#?code=abcd")
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
