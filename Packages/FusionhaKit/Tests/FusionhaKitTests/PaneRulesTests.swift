import XCTest
@testable import FusionhaKit

/// The web's width rules on a pane's measured width (D2c: Activity, Queue,
/// Discover, Manual Import, Settings panels on iPhone Duo).
final class PaneRulesTests: XCTestCase {
    // Inner display: ~669 x 951 portrait, ~951 x 669 landscape; outer ~466.

    func testDesktopIsAbove720() {
        XCTAssertFalse(PaneRule.isDesktop(720))
        XCTAssertTrue(PaneRule.isDesktop(721))
        XCTAssertFalse(PaneRule.isDesktop(669))
        XCTAssertTrue(PaneRule.isDesktop(951))
    }

    func testSplitCapable() {
        XCTAssertTrue(PaneRule.splitCapable(width: 669, height: 951))
        XCTAssertFalse(PaneRule.splitCapable(width: 466, height: 951))
        XCTAssertFalse(PaneRule.splitCapable(width: 840, height: 400))
    }

    func testAutoColumns() {
        // minmax(150, 1fr) gap 12: 4 fit in 636, 3 in 635.
        XCTAssertEqual(PaneRule.autoColumns(width: 636, min: 150, gap: 12), 4)
        XCTAssertEqual(PaneRule.autoColumns(width: 635, min: 150, gap: 12), 3)
        XCTAssertEqual(PaneRule.autoColumns(width: 100, min: 150, gap: 12), 1)
        XCTAssertEqual(PaneRule.autoColumns(width: 0, min: 150, gap: 12), 1)
        // auto-fit collapses empty tracks.
        XCTAssertEqual(PaneRule.autoColumns(width: 2000, min: 150, gap: 12, items: 3), 3)
    }

    func testBalancedColumnsNeverLeaveALoneTile() {
        XCTAssertEqual(PaneRule.balancedColumns(fitting: 4, items: 5), 3)
        XCTAssertEqual(PaneRule.balancedColumns(fitting: 5, items: 5), 5)
        XCTAssertEqual(PaneRule.balancedColumns(fitting: 3, items: 4), 2)
        XCTAssertEqual(PaneRule.balancedColumns(fitting: 4, items: 8), 4)
        XCTAssertEqual(PaneRule.balancedColumns(fitting: 1, items: 5), 1)
        XCTAssertEqual(PaneRule.balancedColumns(fitting: 6, items: 2), 2)
    }

    func testQueueDuoSplitsOnlyInPhoneLayoutOnASplitCapableScreen() {
        XCTAssertTrue(QueueDuoRule.splits(width: 669, height: 951))
        XCTAssertFalse(QueueDuoRule.splits(width: 466, height: 951))
        XCTAssertFalse(QueueDuoRule.splits(width: 951, height: 669))
        XCTAssertTrue(QueueDuoRule.cardIsWide(720))
        XCTAssertFalse(QueueDuoRule.cardIsWide(719))
    }

    func testManualImportLayout() {
        XCTAssertEqual(ManualImportLayout.mode(width: 466, height: 900), .cards)
        XCTAssertEqual(ManualImportLayout.mode(width: 669, height: 951), .split)
        XCTAssertEqual(ManualImportLayout.mode(width: 951, height: 669), .table)
        XCTAssertTrue(ManualImportLayout.tableIsNarrow(951))
        XCTAssertFalse(ManualImportLayout.tableIsNarrow(1133))
    }

    func testDiscoverWidths() {
        XCTAssertEqual(DiscoverWidthRule.cellWidth(402), 116)
        XCTAssertEqual(DiscoverWidthRule.cellWidth(669), 128)
        XCTAssertEqual(DiscoverWidthRule.cellWidth(951), 158)
        XCTAssertFalse(DiscoverWidthRule.controlsOneRow(669))
        XCTAssertTrue(DiscoverWidthRule.controlsOneRow(951))
        XCTAssertEqual(DiscoverWidthRule.filterColumns(891, fields: 4), 4)
        XCTAssertEqual(DiscoverWidthRule.filterColumns(342, fields: 4), 2)
    }

    func testIdleTilesBalanceTheWebsOrphan() {
        // 681–939 is the web's auto-fit band; 4 across leaves 4 + 1 there.
        let fit = IdleLayout.tileColumns(width: 760, gridWidth: 700, tiles: 5)
        XCTAssertEqual(fit, 4)
        XCTAssertEqual(IdleLayout.balancedTileColumns(width: 760, gridWidth: 700, tiles: 5), 3)
    }
}
