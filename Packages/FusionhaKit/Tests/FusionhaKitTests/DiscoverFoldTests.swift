import XCTest
@testable import FusionhaKit

/// Duo Spread S3: Discover, Search and the Add / Request modals keep the fold
/// clear in both "iPhone Duo, open" layouts. Duo numbers: an 849 pt shell with
/// the fold at 451.5; Discover's and Search's content is inset 16 a side, so
/// their 817 pt column has the fold at 435.5.
final class DiscoverFoldTests: XCTestCase {
    private let shell = 849.0
    private let shellFold = 451.5...451.5
    private let content = 817.0
    private let contentFold = 435.5...435.5
    /// A Spread's left page (a title open): 431.5 less the 16 pt insets.
    private let leftPage = 399.5

    private func assertClear(_ tracks: [FoldColumns.Track], of fold: ClosedRange<Double>, offset: Double = 0,
                             viewport: Double? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let gap = FoldColumns.gap(around: fold)
        for track in tracks {
            let x = track.x - offset, maxX = track.maxX - offset
            if let viewport, maxX <= 0 || x >= viewport { continue }
            XCTAssertTrue(maxX <= gap.lowerBound + 1e-9 || x >= gap.upperBound - 1e-9,
                          "track \(x)…\(maxX) crosses \(gap)", file: file, line: line)
        }
    }

    // MARK: Browse's controls (tracker: "Discover one-row controls")

    func testWebLayoutSplitsTheOneRowControlsAtTheFold() throws {
        // Was: lens | search growing across the fold | Add as.
        guard case .split(let panes) = DiscoverFold.controls(width: content, fold: contentFold) else {
            return XCTFail("expected the controls to split at the fold")
        }
        XCTAssertEqual(panes.lead, 415.5)
        XCTAssertEqual(panes.gap, 40)
        XCTAssertGreaterThanOrEqual(panes.lead, DiscoverFold.minLensPane)
        XCTAssertGreaterThanOrEqual(content - panes.lead - panes.gap, DiscoverFold.minSearchPane)
    }

    func testSpreadKeepsTheControlsStackedOnTheLeftPage() {
        // Spanning: the controls are the left piece of the header (415.5 wide).
        XCTAssertEqual(DiscoverFold.controls(width: 415.5, fold: nil), .stacked)
        // A title open: Discover is the left page.
        XCTAssertEqual(DiscoverFold.controls(width: leftPage, fold: nil), .stacked)
    }

    func testNoFoldKeepsTheWebRow() {
        XCTAssertEqual(DiscoverFold.controls(width: content, fold: nil), .oneRow)
        XCTAssertEqual(DiscoverFold.controls(width: 600, fold: 300...300), .stacked)
        // A fold too near an edge for the lens: stack rather than squeeze.
        XCTAssertEqual(DiscoverFold.controls(width: content, fold: 250...250), .stacked)
    }

    // MARK: Rails (tracker: "Discover rails")

    func testWebLayoutRailsRestAPageEachSideOfTheFold() throws {
        let cell = DiscoverFold.railCell(paneWidth: content, spanPage: nil)
        XCTAssertEqual(cell, 158)
        let pages = try XCTUnwrap(DiscoverFold.railPages(count: 20, viewport: content, fold: contentFold,
                                                         cell: cell, spacing: 14))
        XCTAssertEqual(pages.perPage, 2)
        XCTAssertGreaterThanOrEqual(pages.columnWidth, cell)
        XCTAssertEqual(pages.stride, 455.5)
        // Every resting offset (a whole number of strides) keeps every card off the fold.
        for page in 0..<pages.pageCount {
            assertClear(pages.tracks, of: contentFold, offset: Double(page) * pages.stride, viewport: content)
        }
    }

    func testSpreadRailsHoldThreeAPage() throws {
        let cell = DiscoverFold.railCell(paneWidth: shell, spanPage: 431.5)
        XCTAssertEqual(cell, 116)
        let pages = try XCTUnwrap(DiscoverFold.railPages(count: 20, viewport: content, fold: contentFold,
                                                         cell: cell, spacing: 14))
        XCTAssertEqual(pages.perPage, 3)
        for page in 0..<pages.pageCount {
            assertClear(pages.tracks, of: contentFold, offset: Double(page) * pages.stride, viewport: content)
        }
        // The trailers (300 wide) get a page each.
        let trailers = try XCTUnwrap(DiscoverFold.railPages(count: 8, viewport: content, fold: contentFold,
                                                            cell: 300, spacing: 14))
        XCTAssertEqual(trailers.perPage, 1)
    }

    func testRailsWithoutAFoldScrollAsUsual() {
        XCTAssertNil(DiscoverFold.railPages(count: 20, viewport: leftPage, fold: nil, cell: 116, spacing: 14))
        XCTAssertNil(DiscoverFold.railPages(count: 0, viewport: content, fold: contentFold, cell: 116, spacing: 14))
        XCTAssertNil(DiscoverFold.railPages(count: 20, viewport: content, fold: 900...900, cell: 116, spacing: 14))
    }

    // MARK: Results and filters (tracker: "Discover results and filters")

    func testSpreadResultsAreSixAcrossThreeASide() throws {
        let count = PosterTracks.count(base: 5, spans: true)
        XCTAssertEqual(count, 6)
        let tracks = try XCTUnwrap(PosterTracks.tracks(count: count, width: content, fold: contentFold,
                                                       spans: true, spacing: 10))
        XCTAssertEqual(tracks.filter { $0.maxX <= 415.5 + 1e-6 }.count, 3)
        assertClear(tracks, of: contentFold)
    }

    func testWebLayoutResultsSplitAroundTheOffCentreFold() throws {
        // `crossesMiddle` missed it: the fold is 27 pt right of the column's middle.
        XCTAssertGreaterThan(abs(contentFold.lowerBound - content / 2), 12)
        let tracks = try XCTUnwrap(PosterTracks.tracks(count: 5, width: content, fold: contentFold,
                                                       spans: false, spacing: 10))
        XCTAssertEqual(tracks.count, 5)
        assertClear(tracks, of: contentFold)
    }

    func testFilterFieldsFitEachSideOfTheFold() throws {
        // The panel's inside in the Web layout: 817 less 2 x 14, the fold at 421.5.
        let fold = 421.5...421.5
        let tracks = try XCTUnwrap(DiscoverFold.fieldTracks(fields: 5, width: 789, fold: fold))
        XCTAssertEqual(tracks.count, 4)
        XCTAssertTrue(tracks.allSatisfy { $0.width >= 150 })
        assertClear(tracks, of: fold)
        // Spanning (no panel chrome): the column's own width.
        let span = try XCTUnwrap(DiscoverFold.fieldTracks(fields: 5, width: content, fold: contentFold))
        assertClear(span, of: contentFold)
        XCTAssertNil(DiscoverFold.fieldTracks(fields: 5, width: leftPage, fold: nil))
    }

    // MARK: Modals (tracker: "Request modal options", the preview trailer)

    func testModalsSitOnTheRightPageOrSplitAtTheFold() throws {
        let right = try XCTUnwrap(DiscoverFold.modalTrack(.rightPage, width: shell, fold: shellFold))
        XCTAssertEqual(right.x, 471.5)
        XCTAssertEqual(right.maxX, shell)
        let both = try XCTUnwrap(DiscoverFold.modalTrack(.twoPages, width: shell, fold: shellFold))
        XCTAssertEqual(both.width, shell)
        // Folded or portrait: the usual sheet.
        XCTAssertNil(DiscoverFold.modalTrack(.rightPage, width: 466, fold: nil))
        XCTAssertNil(DiscoverFold.modalTrack(.rightPage, width: 466, fold: 233...233))
    }

    func testRequestModalPutsTheTitleLeftAndTheOptionsRight() throws {
        let panes = try XCTUnwrap(DiscoverFold.requestPanes(width: shell, fold: shellFold))
        XCTAssertEqual(panes.lead, 431.5)
        XCTAssertEqual(panes.gap, 40)
        XCTAssertGreaterThanOrEqual(shell - panes.lead - panes.gap, 320)
        // The web's 300 | 1fr where there is no fold (an iPad).
        XCTAssertNil(DiscoverFold.requestPanes(width: 1032, fold: nil))
    }

    func testThePreviewTrailerFitsTheRightPage() throws {
        // The trailer is at most 640 wide; on the right page it is the page's width.
        let right = try XCTUnwrap(DiscoverFold.modalTrack(.rightPage, width: shell, fold: shellFold))
        XCTAssertLessThan(right.width - 32, 640)
        XCTAssertGreaterThanOrEqual(right.x, shellFold.upperBound + FoldColumns.gutter / 2)
    }
}
