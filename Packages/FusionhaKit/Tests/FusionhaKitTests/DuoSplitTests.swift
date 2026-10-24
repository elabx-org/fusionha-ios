import XCTest
@testable import FusionhaKit

/// Option A (owner-approved 2026-10-24): flat is a native third | two-thirds
/// split with no reserved fold; book pose keeps equal pages at the fold; the
/// list hides per tab, flat only.
final class DuoSplitTests: XCTestCase {
    /// The Duo's inner landscape shell (849 wide), the fold at 451.5 in it.
    private let width = 849.0
    private let fold = 451.5...451.5

    // MARK: Posture

    func testPostureComesFromTheActiveDivision() {
        XCTAssertEqual(DuoPosture(activeDivision: true), .book)
        XCTAssertEqual(DuoPosture(activeDivision: false), .flat)
        XCTAssertTrue(DuoPosture.book.reservesFold)
        XCTAssertFalse(DuoPosture.flat.reservesFold)
        XCTAssertTrue(DuoPosture.flat.canHideList)
        XCTAssertFalse(DuoPosture.book.canHideList)
    }

    // MARK: Posture -> layout

    func testFlatIsAThirdAndTheRestWithNoGutter() throws {
        let pages = try XCTUnwrap(DuoSplit.pages(width: width, fold: fold, posture: .flat))
        XCTAssertEqual(pages.left.x, 0)
        XCTAssertEqual(pages.left.width, 283)
        XCTAssertEqual(pages.right.x, 283)
        XCTAssertEqual(pages.right.maxX, width)
        XCTAssertEqual(pages.gap, 0, "flat reserves nothing at the fold")
        XCTAssertGreaterThan(pages.right.width, pages.left.width * 1.9)
    }

    func testBookKeepsTheOldMaths() throws {
        let book = try XCTUnwrap(DuoSplit.pages(width: width, fold: fold, posture: .book))
        XCTAssertEqual(book, SpreadGeometry.pages(width: width, fold: fold))
        XCTAssertEqual(book.left.width, 431.5)
        XCTAssertEqual(book.right.x, 471.5)
        XCTAssertEqual(book.gap, 40)
        // An active fold with a width: its whole width plus the gutter stays empty.
        let wide = try XCTUnwrap(DuoSplit.pages(width: width, fold: 445...458, posture: .book))
        XCTAssertEqual(wide.left.maxX, 425)
        XCTAssertEqual(wide.right.x, 478)
    }

    func testFlatNeedsTheDuoOpenAndRoomForTheDetail() {
        XCTAssertNil(DuoSplit.pages(width: width, fold: 0...0, posture: .flat))
        XCTAssertNil(DuoSplit.pages(width: 466, fold: 233...233, posture: .flat))
        XCTAssertNil(DuoSplit.flatPages(width: 600))
        // The list never goes under its minimum.
        XCTAssertEqual(DuoSplit.flatPages(width: 700)?.left.width, 260)
    }

    func testModeFollowsThePosture() throws {
        let flat = try XCTUnwrap(DuoSplit.flatPages(width: width))
        let book = try XCTUnwrap(SpreadGeometry.pages(width: width, fold: fold))
        XCTAssertEqual(SpreadGeometry.mode(layout: .spread, width: width, fold: fold, posture: .flat,
                                           spanRequested: true, hasItem: true), .pages(flat))
        XCTAssertEqual(SpreadGeometry.mode(layout: .spread, width: width, fold: fold, posture: .book,
                                           spanRequested: true, hasItem: true), .pages(book))
        // Browsing with nothing open still spans the display in both postures.
        XCTAssertTrue(SpreadGeometry.mode(layout: .spread, width: width, fold: fold, posture: .flat,
                                          spanRequested: true, hasItem: false).spans)
        XCTAssertTrue(SpreadGeometry.mode(layout: .spread, width: width, fold: fold, posture: .book,
                                          spanRequested: true, hasItem: false).spans)
        // The Web layout is never a Spread.
        XCTAssertEqual(SpreadGeometry.mode(layout: .web, width: width, fold: fold, posture: .flat,
                                           spanRequested: false, hasItem: true), .off)
    }

    func testFlatModalsSitOnTheDetail() throws {
        let flat = try XCTUnwrap(DiscoverFold.modalTrack(.rightPage, width: width, fold: fold, posture: .flat))
        XCTAssertEqual(flat, FoldColumns.Track(x: 283, width: width - 283))
        let book = try XCTUnwrap(DiscoverFold.modalTrack(.rightPage, width: width, fold: fold, posture: .book))
        XCTAssertEqual(book.x, 471.5)
        XCTAssertEqual(DiscoverFold.modalTrack(.twoPages, width: width, fold: fold, posture: .flat),
                       FoldColumns.Track(x: 0, width: width))
    }

    /// Flat, the fold maths get no fold (nothing reserved), so every piece
    /// lays out as usual; book pose splits as before.
    func testFlatHasNoReservedFoldForTheFoldMaths() {
        XCTAssertNil(LibraryFold.ribbon(width: 793, fold: nil))
        XCTAssertNil(LibraryFold.filterWidth(width: 793, fold: nil))
        XCTAssertNil(PosterTracks.tracks(count: 6, width: 817, fold: nil, spans: true, spacing: 12))
        XCTAssertNotNil(LibraryFold.ribbon(width: 793, fold: 435.5...435.5))
        XCTAssertFalse(SpreadGeometry.tabsCrossFold(tabsWidth: width, fold: nil))
    }

    /// Manual Import (`duoPageSheet(.twoPages)`): halves at the fold in book
    /// pose, its own split by size when flat, nothing when closed.
    func testManualImportFollowsThePosture() throws {
        let book = try XCTUnwrap(ManualImportLayout.duoPanes(width: width, fold: fold, posture: .book))
        XCTAssertEqual(book, ManualImportLayout.foldPanes(width: width, fold: fold))
        XCTAssertEqual(book.lead, 431.5)
        XCTAssertNil(ManualImportLayout.duoPanes(width: width, fold: fold, posture: .flat))
        XCTAssertNil(ManualImportLayout.duoPanes(width: width, fold: nil, posture: nil))
    }

    /// List hidden, the detail is the whole display: reading text stops at ~680.
    func testReadingTextIsCappedOnlyWhenWide() {
        XCTAssertEqual(ReadableWidth.max, 680)
        XCTAssertEqual(ReadableWidth.width(in: width - 32), 680)
        XCTAssertEqual(ReadableWidth.width(in: 534), 534, "the two-thirds detail keeps its width")
    }

    // MARK: The sidebar button

    func testTheListHidesOnlyFlatAndBesideADetail() {
        XCTAssertTrue(DuoSplit.hidesList(remembered: true, posture: .flat, detailShown: true))
        XCTAssertFalse(DuoSplit.hidesList(remembered: true, posture: .book, detailShown: true))
        XCTAssertFalse(DuoSplit.hidesList(remembered: true, posture: nil, detailShown: true))
        XCTAssertFalse(DuoSplit.hidesList(remembered: true, posture: .flat, detailShown: false))
        XCTAssertFalse(DuoSplit.hidesList(remembered: false, posture: .flat, detailShown: true))
    }

    func testTheHiddenListIsRememberedPerTab() {
        var memory = DuoListMemory(raw: "")
        XCTAssertFalse(memory.isHidden("library"))
        memory.toggle("library")
        XCTAssertTrue(memory.isHidden("library"))
        XCTAssertFalse(memory.isHidden("calendar"))
        memory.set(true, for: "calendar")
        XCTAssertEqual(memory.raw, "calendar,library")
        let restored = DuoListMemory(raw: memory.raw)
        XCTAssertEqual(restored, memory)
        memory.toggle("library")
        XCTAssertEqual(memory.raw, "calendar")
        XCTAssertEqual(DuoListMemory(raw: ",,activity,").hidden, ["activity"])
    }

    func testTheNarrowListHeader() {
        XCTAssertTrue(DuoSplit.isNarrowList(width: 283))
        XCTAssertFalse(DuoSplit.isNarrowList(width: 431.5))
        XCTAssertFalse(DuoSplit.isNarrowList(width: 0))
    }
}
