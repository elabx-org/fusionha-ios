import XCTest
@testable import FusionhaKit

/// The v2 page ground's layers (mock palette-lift.js).
final class PageGroundRecipeTests: XCTestCase {
    private let colors = [
        HSLColor(h: 10, s: 0.7, l: 0.4), HSLColor(h: 200, s: 0.5, l: 0.36), HSLColor(h: 280, s: 0.6, l: 0.44),
    ]

    func testPageHasThreeEllipsesInTheMockPlaces() {
        let r = PageGroundRecipe.page(colors, dark: true)
        XCTAssertEqual(r?.ellipses.count, 3)
        XCTAssertEqual(r?.ellipses.map(\.x), [0.10, 0.95, 0.20])
        XCTAssertEqual(r?.ellipses.first?.alpha ?? 0, 0.62, accuracy: 1e-9)
        XCTAssertEqual(r?.top.h, 10)
        XCTAssertEqual(r?.bottom.h, 280)
    }

    func testLightIsPaleAndFainter() {
        let r = PageGroundRecipe.page(colors, dark: false)
        XCTAssertEqual(r?.top.l ?? 0, 0.93, accuracy: 1e-9)
        XCTAssertEqual(r?.bottom.l ?? 0, 0.95, accuracy: 1e-9)
        XCTAssertEqual(r?.ellipses.first?.alpha ?? 0, 0.62 * 0.9, accuracy: 1e-9)
    }

    func testShortListsPad() {
        let one = PageGroundRecipe.page([colors[0]], dark: true)
        XCTAssertEqual(one?.ellipses.count, 3)
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
