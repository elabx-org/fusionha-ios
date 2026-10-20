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

    func testWidthAndHeightFloorsAreInclusive() {
        XCTAssertFalse(ShellSplitRule.splits(width: 559, height: 800, hasItem: true))
        XCTAssertTrue(ShellSplitRule.splits(width: 560, height: 500, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 560, height: 560, hasItem: true))
        XCTAssertFalse(ShellSplitRule.splits(width: 800, height: 499, hasItem: true))
    }

    func testDetailColumnIsClamped() {
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 560), 360)
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 669), 669 * 0.56, accuracy: 0.001)
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 951), 951 * 0.56, accuracy: 0.001)
        XCTAssertEqual(ShellSplitRule.detailWidth(for: 1366), 620)
    }

    func testSettingsSplitsAtTheWebs720() {
        XCTAssertFalse(SettingsSplitRule.splits(width: 466))
        XCTAssertFalse(SettingsSplitRule.splits(width: 669))
        XCTAssertFalse(SettingsSplitRule.splits(width: 719))
        XCTAssertTrue(SettingsSplitRule.splits(width: 720))
        XCTAssertTrue(SettingsSplitRule.splits(width: 951))
    }
}
