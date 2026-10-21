import XCTest
@testable import FusionhaKit

/// The iPhone Duo Spread (S1): two pages at the fold's real x with the 40 pt
/// gutter, the switch, and browse grids spanning both pages.
final class SpreadGeometryTests: XCTestCase {
    /// Inner landscape, 951 x 669 with the device kit's safe area (24 left,
    /// 78 right): the shell is 849 wide and the fold (475.5 on the display)
    /// is at 451.5 in it, right of the content's middle (424.5).
    private let duoWidth = 849.0
    private let duoFold = 451.5...451.5

    private func assertClear(_ tracks: [FoldColumns.Track], of gap: ClosedRange<Double>,
                             file: StaticString = #filePath, line: UInt = #line) {
        for track in tracks {
            XCTAssertTrue(track.maxX <= gap.lowerBound + 1e-9 || track.x >= gap.upperBound - 1e-9,
                          "track \(track.x)…\(track.maxX) crosses \(gap)", file: file, line: line)
        }
    }

    func testTheSwitchDefaultsToSpreadAndFlips() {
        XCTAssertEqual(DuoOpenLayout.standard, .spread)
        XCTAssertEqual(DuoOpenLayout.spread.other, .web)
        XCTAssertEqual(DuoOpenLayout.web.other, .spread)
        XCTAssertEqual(DuoOpenLayout.spread.title, "Spread")
        XCTAssertEqual(DuoOpenLayout.web.title, "Web layout")
        XCTAssertEqual(DuoOpenLayout.spread.symbol, "rectangle.split.2x1")
        XCTAssertEqual(DuoOpenLayout.web.symbol, "rectangle")
        XCTAssertEqual(DuoOpenLayout(rawValue: "web"), .web)
        XCTAssertNil(DuoOpenLayout(rawValue: "book"))
    }

    func testPagesMeetAtTheRealFoldNotTheMiddle() throws {
        let pages = try XCTUnwrap(SpreadGeometry.pages(width: duoWidth, fold: duoFold))
        XCTAssertEqual(pages.left.x, 0)
        XCTAssertEqual(pages.left.width, 431.5)
        XCTAssertEqual(pages.right.x, 471.5)
        XCTAssertEqual(pages.right.maxX, duoWidth)
        XCTAssertEqual(pages.gap, 40)
        XCTAssertNotEqual(pages.left.maxX + 20, duoWidth / 2)
    }

    func testBookPoseKeepsTheActiveFoldPlusTheGutter() throws {
        let pages = try XCTUnwrap(SpreadGeometry.pages(width: duoWidth, fold: 445...458))
        XCTAssertEqual(pages.left.maxX, 425)
        XCTAssertEqual(pages.right.x, 478)
        XCTAssertEqual(pages.gap, 53)
    }

    func testNoPagesWithoutRoomOrAFoldInside() {
        XCTAssertNil(SpreadGeometry.pages(width: duoWidth, fold: 0...0))
        XCTAssertNil(SpreadGeometry.pages(width: duoWidth, fold: 849...849))
        // A page under 300 (the folded outer display is 466 wide).
        XCTAssertNil(SpreadGeometry.pages(width: 466, fold: 233...233))
        XCTAssertNil(SpreadGeometry.pages(width: duoWidth, fold: 300...300))
    }

    func testModeNeedsTheSettingAndAFold() {
        XCTAssertEqual(SpreadGeometry.mode(layout: .web, width: duoWidth, fold: duoFold,
                                           spanRequested: true, hasItem: false), .off)
        XCTAssertEqual(SpreadGeometry.mode(layout: .spread, width: duoWidth, fold: nil,
                                           spanRequested: true, hasItem: false), .off)
        // Inner portrait: the fold runs side to side, so there is no vertical fold.
        XCTAssertEqual(SpreadGeometry.mode(layout: .spread, width: 621, fold: nil,
                                           spanRequested: false, hasItem: true), .off)
    }

    func testABrowseScreenSpansUntilATitleIsPicked() throws {
        let pages = try XCTUnwrap(SpreadGeometry.pages(width: duoWidth, fold: duoFold))
        let browsing = SpreadGeometry.mode(layout: .spread, width: duoWidth, fold: duoFold,
                                           spanRequested: true, hasItem: false)
        XCTAssertEqual(browsing, .span(pages))
        XCTAssertTrue(browsing.spans)
        let picked = SpreadGeometry.mode(layout: .spread, width: duoWidth, fold: duoFold,
                                         spanRequested: true, hasItem: true)
        XCTAssertEqual(picked, .pages(pages))
        XCTAssertFalse(picked.spans)
        XCTAssertEqual(picked.pages, pages)
        // A work screen never spans.
        XCTAssertEqual(SpreadGeometry.mode(layout: .spread, width: duoWidth, fold: duoFold,
                                           spanRequested: false, hasItem: false), .pages(pages))
    }

    /// Library in Spread, nothing picked: three posters a side, the gutter on the fold.
    func testLibrarySpanIsThreeASideWithTheGutterOnTheFold() throws {
        // The grid is inset 16 each side: 817 wide, the fold at 435.5 in it.
        let fold = 435.5...435.5
        XCTAssertEqual(PosterTracks.count(base: 5, spans: true), 6)
        let tracks = try XCTUnwrap(PosterTracks.tracks(count: 6, width: 817, fold: fold, spans: true, spacing: 6))
        XCTAssertEqual(tracks.count, 6)
        let gap = FoldColumns.gap(around: fold)
        assertClear(tracks, of: gap)
        XCTAssertEqual(tracks.filter { $0.maxX <= gap.lowerBound + 1e-9 }.count, 3)
        XCTAssertEqual(tracks.filter { $0.x >= gap.upperBound - 1e-9 }.count, 3)
        XCTAssertEqual(tracks[2].maxX, gap.lowerBound, accuracy: 1e-9)
        XCTAssertEqual(tracks[3].x, gap.upperBound, accuracy: 1e-9)
        XCTAssertEqual(tracks[5].maxX, 817, accuracy: 1e-9)
    }

    /// Library in the Web layout with the Duo flat open and no title: the
    /// usual count, split around the real fold (the old even-count rule
    /// assumed a centred fold and put a poster on the Duo's).
    func testLibraryWebLayoutKeepsItsCountAndClearsTheFold() throws {
        let fold = 435.5...435.5
        XCTAssertEqual(PosterTracks.count(base: 5, spans: false), 5)
        let tracks = try XCTUnwrap(PosterTracks.tracks(count: 5, width: 793, fold: fold, spans: false, spacing: 6))
        XCTAssertEqual(tracks.count, 5)
        assertClear(tracks, of: FoldColumns.gap(around: fold))
        XCTAssertNil(PosterTracks.tracks(count: 5, width: 793, fold: nil, spans: false, spacing: 6))
    }

    func testForcedLeadingCountIsClamped() throws {
        let tracks = try XCTUnwrap(FoldColumns.split(count: 4, width: 800, spacing: 6, gap: 380...420, leading: 9))
        XCTAssertEqual(tracks.filter { $0.maxX <= 380 + 1e-9 }.count, 3)
        XCTAssertNil(FoldColumns.split(count: 4, width: 800, spacing: 300, gap: 380...420, leading: 3))
    }
}
