import XCTest
@testable import FusionhaKit

/// The fold gutter when the iPhone Duo lies flat (or half open): no column may
/// straddle the fold.
final class FoldColumnsTests: XCTestCase {
    /// No track overlaps the gap kept around the fold.
    private func assertClear(_ tracks: [FoldColumns.Track], of gap: ClosedRange<Double>, offset: Double = 0,
                             file: StaticString = #filePath, line: UInt = #line) {
        for track in tracks {
            let x = track.x - offset, maxX = track.maxX - offset
            XCTAssertTrue(maxX <= gap.lowerBound + 1e-9 || x >= gap.upperBound - 1e-9,
                          "track \(x)…\(maxX) crosses the gap \(gap)", file: file, line: line)
        }
    }

    func testGapIsTheFoldPlusHalfTheGutterEachSide() {
        XCTAssertEqual(FoldColumns.gutter, 40)
        XCTAssertEqual(FoldColumns.gap(around: 475...475), 455...495)
        XCTAssertEqual(FoldColumns.gap(around: 470...480), 450...500)
    }

    func testACentredFoldSplitsFiveAsTwoThreeAndSevenAsThreeFour() throws {
        let gap = FoldColumns.gap(around: 475...475)
        XCTAssertEqual(FoldColumns.leadingCount(count: 5, lead: 455, trail: 455, spacing: 12), 2)
        XCTAssertEqual(FoldColumns.leadingCount(count: 7, lead: 455, trail: 455, spacing: 4), 3)

        let board = try XCTUnwrap(FoldColumns.split(count: 5, width: 950, spacing: 12, gap: gap))
        XCTAssertEqual(board.count, 5)
        assertClear(board, of: gap)
        XCTAssertEqual(board[1].maxX, 455, accuracy: 1e-9)
        XCTAssertEqual(board[2].x, 495, accuracy: 1e-9)
        XCTAssertEqual(board[4].maxX, 950, accuracy: 1e-9)
        XCTAssertEqual(board[0].width, board[1].width)
        XCTAssertEqual(board[2].width, board[4].width)

        let month = try XCTUnwrap(FoldColumns.split(count: 7, width: 950, spacing: 4, gap: gap))
        assertClear(month, of: gap)
        XCTAssertEqual(month.filter { $0.maxX <= 455 }.count, 3)
        XCTAssertEqual(month[6].maxX, 950, accuracy: 1e-9)
    }

    /// The Duo's vertical bar takes more room on the trailing side, so the
    /// fold sits right of the content's middle: the split evens the widths.
    func testAnOffCentreFoldEvensTheColumnWidths() throws {
        let gap = FoldColumns.gap(around: 451...451)
        let board = try XCTUnwrap(FoldColumns.split(count: 5, width: 829, spacing: 12, gap: gap))
        assertClear(board, of: gap)
        XCTAssertEqual(board.filter { $0.maxX <= gap.lowerBound }.count, 3)
        let month = try XCTUnwrap(FoldColumns.split(count: 7, width: 829, spacing: 4, gap: gap))
        assertClear(month, of: gap)
        XCTAssertEqual(month.filter { $0.maxX <= gap.lowerBound }.count, 4)
    }

    func testNoSplitWithoutAFoldInsideTheContainer() {
        XCTAssertNil(FoldColumns.split(count: 7, width: 400, spacing: 4, gap: 420...460))
        XCTAssertNil(FoldColumns.split(count: 7, width: 400, spacing: 4, gap: -20...20))
        XCTAssertNil(FoldColumns.split(count: 1, width: 950, spacing: 4, gap: 455...495))
        XCTAssertNil(FoldColumns.split(count: 5, width: 100, spacing: 40, gap: 30...70))
    }

    func testPagesRestWithTheFoldInTheGutter() throws {
        let gap = FoldColumns.gap(around: 451...451)
        let pages = try XCTUnwrap(FoldColumns.pages(count: 5, gap: gap, minimum: 200, spacing: 12))
        XCTAssertEqual(pages.perPage, 2)
        XCTAssertEqual(pages.columnWidth, 209.5, accuracy: 1e-9)
        XCTAssertEqual(pages.pageCount, 3)
        XCTAssertEqual(pages.stride, 471, accuracy: 1e-9)
        XCTAssertEqual(pages.lastOffset, 942, accuracy: 1e-9)
        XCTAssertEqual(pages.contentWidth(viewport: 829), 942 + 829, accuracy: 1e-9)
        let tracks = pages.tracks
        XCTAssertEqual(tracks.map(\.x), [0, 221.5, 471, 692.5, 942])
        for page in 0..<pages.pageCount {
            assertClear(tracks, of: gap, offset: Double(page) * pages.stride)
        }
    }

    func testPagesFitAtLeastOneColumn() throws {
        let pages = try XCTUnwrap(FoldColumns.pages(count: 5, gap: 150...190, minimum: 200, spacing: 12))
        XCTAssertEqual(pages.perPage, 1)
        XCTAssertEqual(pages.columnWidth, 150)
        XCTAssertEqual(pages.pageCount, 5)
        XCTAssertNil(FoldColumns.pages(count: 5, gap: -20...20, minimum: 200, spacing: 12))
    }

    func testEvenColumnsKeepTheWebsMinimum() {
        let fits = FoldColumns.even(count: 5, width: 1148, spacing: 12, minimum: 220)
        XCTAssertEqual(fits.last?.maxX ?? 0, 1148, accuracy: 1e-9)
        let scrolls = FoldColumns.even(count: 5, width: 829, spacing: 12, minimum: 220)
        XCTAssertEqual(scrolls.map(\.width), Array(repeating: 220, count: 5))
        XCTAssertEqual(scrolls[1].x, 232)
    }
}
