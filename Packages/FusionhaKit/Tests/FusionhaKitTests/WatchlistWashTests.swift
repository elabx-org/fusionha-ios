import XCTest
@testable import FusionhaKit

final class WatchlistWashTests: XCTestCase {
    func testPlexWashFollowsMeta() {
        XCTAssertEqual(PlexWatchlistState.on.wash, .done)
        XCTAssertEqual(PlexWatchlistState.needsSignIn.wash, .stuck)
        XCTAssertEqual(PlexWatchlistState.tokenInvalid.wash, .stuck)
        XCTAssertEqual(PlexWatchlistState.error.wash, .stuck)
        for plain: PlexWatchlistState in [.off, .notPlexUser, .notGranted, .ineligible, .disabled] {
            XCTAssertNil(plain.wash, "\(plain)")
        }
    }

    func testPlexSyncingWashesGrabOnlyWhenWashed() {
        XCTAssertEqual(PlexWatchlistState.on.wash(syncing: true), .grab)
        XCTAssertEqual(PlexWatchlistState.on.wash(syncing: false), .done)
        XCTAssertNil(PlexWatchlistState.off.wash(syncing: true))
    }

    func testLetterboxdWash() {
        XCTAssertEqual(LetterboxdLogic.wash(.ok, running: false), .done)
        XCTAssertEqual(LetterboxdLogic.wash(.ok, running: true), .grab)
        XCTAssertEqual(LetterboxdLogic.wash(.bad, running: false), .stuck)
        XCTAssertNil(LetterboxdLogic.wash(.none, running: false))
        XCTAssertNil(LetterboxdLogic.wash(.ok, running: false, allowed: false))
    }
}
