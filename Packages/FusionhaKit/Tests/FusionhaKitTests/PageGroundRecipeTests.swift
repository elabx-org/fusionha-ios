import XCTest
@testable import FusionhaKit

/// The v2 page ground's layers (mock palette-lift.js).
final class PageGroundRecipeTests: XCTestCase {
    private let colors = [
        HSLColor(h: 10, s: 0.7, l: 0.4), HSLColor(h: 200, s: 0.5, l: 0.36), HSLColor(h: 280, s: 0.6, l: 0.44),
    ]

    func testPageEllipsesReachEveryCorner() {
        let r = PageGroundRecipe.page(colors, dark: true)
        XCTAssertEqual(r?.ellipses.count, 4)
        XCTAssertEqual(r?.ellipses.map(\.x), [0.10, 0.92, 0.25, 0.80])
        XCTAssertEqual(r?.ellipses.first?.y ?? 1, 0.08, accuracy: 1e-9)
        XCTAssertEqual(r?.ellipses.first?.alpha ?? 0, 0.62, accuracy: 1e-9)
        XCTAssertEqual(r?.top.h, 10)
        XCTAssertEqual(r?.bottom.h, 280)
    }

    /// The dark base comes from the art, never the page's near-black.
    func testDarkBaseIsLiftedNotBlack() {
        let r = PageGroundRecipe.page(colors, dark: true)!
        XCTAssertGreaterThanOrEqual(r.top.l, 0.18)
        XCTAssertGreaterThanOrEqual(r.bottom.l, 0.14)
        XCTAssertGreaterThan(r.top.s, 0)
    }

    /// OLED and Noir stay dark, but tinted.
    func testDeepStaysDarkButTinted() {
        let deep = PageGroundRecipe.page(colors, dark: true, deep: true)!
        let page = PageGroundRecipe.page(colors, dark: true)!
        XCTAssertLessThan(deep.top.l, page.top.l)
        XCTAssertGreaterThan(deep.top.l, 0)
        XCTAssertGreaterThan(deep.top.s, 0)
        XCTAssertLessThan(deep.ellipses[0].alpha, page.ellipses[0].alpha)
    }

    func testLightIsPaleAndFainter() {
        let r = PageGroundRecipe.page(colors, dark: false)
        XCTAssertEqual(r?.top.l ?? 0, 0.93, accuracy: 1e-9)
        XCTAssertEqual(r?.bottom.l ?? 0, 0.95, accuracy: 1e-9)
        XCTAssertEqual(r?.ellipses.first?.alpha ?? 0, 0.62 * 0.9, accuracy: 1e-9)
    }

    func testShortListsPad() {
        let one = PageGroundRecipe.page([colors[0]], dark: true)
        XCTAssertEqual(one?.ellipses.count, 4)
        XCTAssertEqual(one?.bottom.h, 10)
        XCTAssertNil(PageGroundRecipe.page([], dark: true))
        XCTAssertEqual(PageGroundRecipe.listPane([colors[0]], dark: false)?.ellipses.count, 2)
    }

    func testListPaneIsDeeper() {
        let page = PageGroundRecipe.page(colors, dark: true)!, pane = PageGroundRecipe.listPane(colors, dark: true)!
        XCTAssertLessThan(pane.top.l, page.top.l)
    }

    func testInksContrastWithTheirGround() {
        let lead = colors[0]
        XCTAssertGreaterThan(PageGroundRecipe.ink(lead, dark: true).l, 0.85)
        XCTAssertLessThan(PageGroundRecipe.ink(lead, dark: false).l, 0.2)
        XCTAssertLessThanOrEqual(PageGroundRecipe.ink(lead, dark: true).s, 0.3)
    }

    func testPageGroundSpec() {
        let spec = ArtBlurSpec.pageGround(tone: .dark, aspect: 16 / 9)
        XCTAssertEqual(spec.kind, .pageGround)
        XCTAssertEqual(spec.saturation, 1.7)
        XCTAssertEqual(ArtBlurSpec.pageGround(tone: .mono, aspect: 16 / 9).saturation, 0)
        XCTAssertNotEqual(spec.key(for: "u"), ArtBlurSpec.ambient(.detailAmbient, tone: .dark, aspect: 16 / 9).key(for: "u"))
    }
}
