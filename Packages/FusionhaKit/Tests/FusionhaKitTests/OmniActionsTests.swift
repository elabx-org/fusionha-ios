import XCTest
@testable import FusionhaKit

final class OmniActionsTests: XCTestCase {
    func testProviderShortLabel() {
        XCTAssertEqual(OmniActions.providerShortLabel(nil), "TMDB")
        XCTAssertEqual(OmniActions.providerShortLabel("tmdb"), "TMDB")
        XCTAssertEqual(OmniActions.providerShortLabel("tvdb"), "TheTVDB")
        XCTAssertEqual(OmniActions.providerShortLabel("tvmaze"), "TVmaze")
        XCTAssertEqual(OmniActions.providerShortLabel("hybrid"), "TMDB + TheTVDB")
        XCTAssertEqual(OmniActions.providerShortLabel("other"), "TMDB")
    }

    func testAddRowActionsGateSeparately() {
        XCTAssertEqual(OmniActions.addRowActions(openable: true, canAdd: true, canRequest: true), [.open])
        XCTAssertEqual(OmniActions.addRowActions(openable: false, canAdd: true, canRequest: true), [.add, .request])
        XCTAssertEqual(OmniActions.addRowActions(openable: false, canAdd: true, canRequest: false), [.add])
        XCTAssertEqual(OmniActions.addRowActions(openable: false, canAdd: false, canRequest: true), [.request])
        XCTAssertEqual(OmniActions.addRowActions(openable: false, canAdd: false, canRequest: false), [])
    }

    func testAddRowPrimary() {
        XCTAssertEqual(OmniActions.addRowPrimary(openable: true, canAdd: false, canRequest: true), .open)
        XCTAssertEqual(OmniActions.addRowPrimary(openable: false, canAdd: true, canRequest: true), .preview)
        XCTAssertEqual(OmniActions.addRowPrimary(openable: false, canAdd: false, canRequest: true), .request)
        XCTAssertEqual(OmniActions.addRowPrimary(openable: false, canAdd: false, canRequest: false), .none)
    }
}
