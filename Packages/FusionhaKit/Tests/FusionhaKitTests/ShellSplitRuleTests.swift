import XCTest
@testable import FusionhaKit

/// The size matrix of the web's fold-geometry tests (fusionha PR #185), so the
/// app and the web split at the same sizes.
final class ShellSplitRuleTests: XCTestCase {
    func testIPhoneDuoOuterDisplayStaysAPhone() {
        XCTAssertFalse(ShellSplitRule.splits(width: 466, height: 678, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 678, height: 466, hasItem: true))
    }

    func testIPhoneDuoInnerLandscapeSplitsWithATitleOpen() {
        XCTAssertTrue(ShellSplitRule.splits(width: 951, height: 669, hasItem: true))
    }

    /// Q-DC3: inner portrait keeps the tab bar at the bottom (no 265pt tabs column).
    func testPortraitNeverSplits() {
        XCTAssertFalse(ShellSplitRule.splits(width: 669, height: 951, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 744, height: 1133, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 800, height: 800, hasItem: true))
    }

    func testNoTitleNoSplit() {
        XCTAssertFalse(ShellSplitRule.splits(width: 951, height: 669, hasItem: false))
    }

    func testPhoneInLandscapeKeepsTheSheet() {
        XCTAssertFalse(ShellSplitRule.splits(width: 874, height: 402, hasItem: true))
    }

    func testAWideButShortWindowKeepsTheSheet() {
        XCTAssertFalse(ShellSplitRule.splits(width: 669, height: 450, hasItem: true))
    }

    func testSideBySideNarrowWindowKeepsTheSheet() {
        XCTAssertFalse(ShellSplitRule.splits(width: 420, height: 951, hasItem: true))
    }

    func testWidthAndHeightFloors() {
        XCTAssertFalse(ShellSplitRule.splits(width: 559, height: 800, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 560, height: 560, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 1000, height: 499, hasItem: true))
        XCTAssertTrue(ShellSplitRule.splits(width: 1000, height: 500, hasItem: true))
    }

    /// D2b follow-up: in landscape the tab's pane beside the title never drops
    /// under 360; a narrower landscape window opens the title as the sheet.
    func testLandscapeKeepsA360PaneBesideTheTitle() {
        XCTAssertFalse(ShellSplitRule.splits(width: 560, height: 500, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 700, height: 500, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 820, height: 600, hasItem: true))
        XCTAssertTrue(ShellSplitRule.splits(width: 821, height: 600, hasItem: true))
        XCTAssertTrue(ShellSplitRule.splits(width: 1133, height: 744, hasItem: true))
        XCTAssertGreaterThanOrEqual(ShellSplitRule.primaryWidth(for: 821), 360)
        XCTAssertLessThan(ShellSplitRule.primaryWidth(for: 820), 360)
    }

    func testIPhoneDuoInnerLandscapeLeavesA417Pane() {
        XCTAssertEqual(ShellSplitRule.primaryWidth(for: 951), 951 - 951 * 0.56 - 1, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(ShellSplitRule.primaryWidth(for: 951), ShellSplitRule.primaryMin)
    }

    func testDetailColumnIsClamped() {
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 560), 360)
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 669), 669 * 0.56, accuracy: 0.001)
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 951), 951 * 0.56, accuracy: 0.001)
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 1366), 620)
    }

    /// Book pose, a zero-wide active fold (the harness's) splits the shell:
    /// the tabs end 20 before it, the title starts 20 after it. Flat open the
    /// app passes no fold (option A: nothing reserved), so the Web layout keeps
    /// the web's split (`DuoSplitTests`).
    func testABookFoldSplitsAtTheFoldWithAGutter() throws {
        let split = try XCTUnwrap(ShellSplitRule.foldSplit(width: 951, fold: 475...475))
        XCTAssertEqual(split.primary, 455)
        XCTAssertEqual(split.gap, 40)
        XCTAssertNotEqual(split.primary, ShellSplitRule.primaryWidth(for: 951))
    }

    /// Half open, the active fold has a width: the gutter goes around it.
    func testAnActiveFoldKeepsItsWidthInTheGap() throws {
        let split = try XCTUnwrap(ShellSplitRule.foldSplit(width: 951, fold: 470...481))
        XCTAssertEqual(split.primary, 450)
        XCTAssertEqual(split.gap, 51)
    }

    /// A fold too near an edge (or outside the window) leaves the web's split.
    func testAFoldNearAnEdgeKeepsTheWebSplit() {
        XCTAssertNil(ShellSplitRule.foldSplit(width: 951, fold: 300...300))
        XCTAssertNil(ShellSplitRule.foldSplit(width: 951, fold: 700...700))
        XCTAssertNil(ShellSplitRule.foldSplit(width: 600, fold: 300...300))
    }

    func testSettingsSplitsAtTheWebs720() {
        XCTAssertFalse(SettingsSplitRule.splits(width: 466))
        XCTAssertFalse(SettingsSplitRule.splits(width: 669))
        XCTAssertFalse(SettingsSplitRule.splits(width: 719))
        XCTAssertTrue(SettingsSplitRule.splits(width: 720))
        XCTAssertTrue(SettingsSplitRule.splits(width: 951))
    }
}
