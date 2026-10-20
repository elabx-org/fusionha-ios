import XCTest
@testable import FusionhaKit

/// The pane-width rules of D2b, at iPhone Duo and iPad sizes.
final class PaneLayoutRulesTests: XCTestCase {
    func testPaneIsWideOnlyPast720() {
        XCTAssertFalse(PaneWidthRule.isWide(466))
        XCTAssertFalse(PaneWidthRule.isWide(669))
        XCTAssertFalse(PaneWidthRule.isWide(720))
        XCTAssertTrue(PaneWidthRule.isWide(721))
        XCTAssertTrue(PaneWidthRule.isWide(951))
    }

    func testCalendarFollowsLayoutTs() {
        XCTAssertEqual(CalendarLayout.of(width: 466), .phone)
        XCTAssertEqual(CalendarLayout.of(width: 669), .phone)
        XCTAssertEqual(CalendarLayout.of(width: 719), .phone)
        XCTAssertEqual(CalendarLayout.of(width: 720), .tablet)
        XCTAssertEqual(CalendarLayout.of(width: 951), .tablet)
        XCTAssertEqual(CalendarLayout.of(width: 999), .tablet)
        XCTAssertEqual(CalendarLayout.of(width: 1000), .desktop)
        XCTAssertEqual(CalendarLayout.of(width: 1133), .desktop)
    }

    func testSignInStagesGoSideBySide() {
        XCTAssertFalse(SignInLayoutRule.splitSideBySide(width: 669))
        XCTAssertFalse(SignInLayoutRule.splitSideBySide(width: 760))
        XCTAssertTrue(SignInLayoutRule.splitSideBySide(width: 761))
        XCTAssertFalse(SignInLayoutRule.livingSideBySide(width: 720))
        XCTAssertTrue(SignInLayoutRule.livingSideBySide(width: 744))
        XCTAssertTrue(SignInLayoutRule.livingSideBySide(width: 951))
    }

    func testStatusClusterIsForWideManagers() {
        XCTAssertFalse(StatusClusterRule.shows(width: 669, requestScoped: false))
        XCTAssertFalse(StatusClusterRule.shows(width: 721, requestScoped: false))
        XCTAssertFalse(StatusClusterRule.shows(width: 900, requestScoped: false))
        XCTAssertTrue(StatusClusterRule.shows(width: 901, requestScoped: false))
        XCTAssertTrue(StatusClusterRule.shows(width: 951, requestScoped: false))
        XCTAssertFalse(StatusClusterRule.shows(width: 951, requestScoped: true))
    }
}
