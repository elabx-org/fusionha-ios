import XCTest
@testable import FusionhaKit

/// Spread S2: the Library and its downloads bar keep the fold clear in both
/// "iPhone Duo, open" layouts. Duo numbers: an 849 pt shell with the fold at
/// 451.5; the Library's scroll insets its content 16 each side, so its content
/// is 817 wide (783 beside the 34 pt A–Z rail) with the fold at 435.5.
final class LibraryFoldTests: XCTestCase {
    private let shell = 849.0
    private let shellFold = 451.5...451.5
    private let content = 817.0
    private let railContent = 817.0 - 34
    private let fold = 435.5...435.5
    /// The fold and its 20 pt gutter each side, in the content's coordinates.
    private var gutter: ClosedRange<Double> { 415.5...455.5 }

    private func assertClear(_ panes: FoldColumns.Panes?, width: Double,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let panes = try XCTUnwrap(panes, file: file, line: line)
        XCTAssertLessThanOrEqual(panes.lead, gutter.lowerBound, "leading piece reaches the gutter", file: file, line: line)
        XCTAssertGreaterThanOrEqual(panes.lead + panes.gap, gutter.upperBound, "trailing piece starts in the gutter",
                                    file: file, line: line)
        XCTAssertGreaterThan(width - panes.lead - panes.gap, 0, file: file, line: line)
    }

    // MARK: Web layout (the desktop Library across both halves)

    func testWebLayoutFilterFieldStopsBeforeTheFold() {
        XCTAssertEqual(LibraryFold.filterWidth(width: content, fold: fold), gutter.lowerBound)
        XCTAssertNil(LibraryFold.filterWidth(width: content, fold: nil))
    }

    func testWebLayoutPulseRibbonIsTwoCardsAtTheGutter() throws {
        try assertClear(LibraryFold.ribbon(width: content, fold: fold), width: content)
        try assertClear(LibraryFold.ribbon(width: railContent, fold: fold), width: railContent)
        XCTAssertNil(LibraryFold.ribbon(width: content, fold: nil))
    }

    func testWebLayoutToolbarSplitsSoGroupStatusNeverSitsOnTheFold() throws {
        try assertClear(LibraryFold.toolbar(width: railContent, fold: fold), width: railContent)
        // Too little room after the fold (a narrow window): keep the one piece.
        XCTAssertNil(LibraryFold.toolbar(width: 600, fold: 435.5...435.5))
    }

    func testWebLayoutCompactTableRowsSplitAtTheFold() throws {
        try assertClear(LibraryFold.table(width: content, fold: fold), width: content)
        XCTAssertNil(LibraryFold.table(width: content, fold: nil))
    }

    func testWebLayoutHeaderRulesBreakAtTheGutter() {
        XCTAssertEqual(LibraryFold.gap(width: content, fold: fold), gutter)
        XCTAssertNil(LibraryFold.gap(width: content, fold: 0...0))
        XCTAssertNil(LibraryFold.gap(width: content, fold: nil))
    }

    func testBookPoseKeepsTheActiveFoldAndItsGutterEmpty() throws {
        let book = 429.0...442.0
        let panes = try XCTUnwrap(LibraryFold.ribbon(width: content, fold: book))
        XCTAssertEqual(panes.lead, 409)
        XCTAssertEqual(panes.lead + panes.gap, 462)
        XCTAssertEqual(LibraryFold.filterWidth(width: content, fold: book), 409)
    }

    // MARK: Spread

    func testSpreadSpanPiecesNeverHaveTheFoldInside() throws {
        // The span's header is a `FoldSpanRow` (panes at 120 | 120): the
        // filter field and the toolbar sit inside a half, so they see no fold.
        let span = try XCTUnwrap(FoldColumns.panes(width: content, fold: fold, minLead: 120, minTrail: 120))
        XCTAssertEqual(span.lead, gutter.lowerBound)
        XCTAssertNil(LibraryFold.filterWidth(width: span.lead, fold: nil))
        // The grid: three a side, the gutter on the fold (S1).
        let tracks = try XCTUnwrap(PosterTracks.tracks(count: 6, width: content, fold: fold, spans: true, spacing: 12))
        XCTAssertEqual(tracks.filter { $0.maxX <= gutter.lowerBound }.count, 3)
        XCTAssertEqual(tracks.filter { $0.x >= gutter.upperBound }.count, 3)
    }

    func testSpreadWithATitleKeepsTheLibraryOnTheLeftPageAsThePhone() throws {
        let pages = try XCTUnwrap(SpreadGeometry.pages(width: shell, fold: shellFold))
        // The left page is the phone Library (no ribbon, no desktop toolbar)…
        XCTAssertFalse(PaneRule.isDesktop(pages.left.width))
        // …and the fold is outside it, so nothing in it splits.
        XCTAssertNil(LibraryFold.table(width: pages.left.width - 32, fold: nil))
    }

    // MARK: Downloads bar

    func testDownloadsBarHidesOnlyWhileTheTabsRunAcrossTheFold() throws {
        let pages = try XCTUnwrap(SpreadGeometry.pages(width: shell, fold: shellFold))
        // Spread span, and the Web layout with nothing open: the tabs fill the shell.
        XCTAssertTrue(SpreadGeometry.tabsCrossFold(tabsWidth: shell, fold: shellFold))
        // Spread with a title: the tabs are the left page.
        XCTAssertFalse(SpreadGeometry.tabsCrossFold(tabsWidth: pages.left.width, fold: shellFold))
        // Web layout with a title: the split sits on the fold.
        let split = try XCTUnwrap(ShellSplitRule.foldSplit(width: shell, fold: shellFold))
        XCTAssertFalse(SpreadGeometry.tabsCrossFold(tabsWidth: split.primary, fold: shellFold))
        // Folded, inner portrait, no Duo.
        XCTAssertFalse(SpreadGeometry.tabsCrossFold(tabsWidth: 466, fold: nil))
    }
}
