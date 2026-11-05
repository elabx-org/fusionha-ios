import XCTest
@testable import FusionhaKit

/// The art palette maths behind the v2 page ground (mock palette-lift.js).
final class PaletteMathTests: XCTestCase {
    private func assertHSL(_ c: HSLColor, h: Double, s: Double, l: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(c.h, h, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(c.s, s, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(c.l, l, accuracy: 0.01, file: file, line: line)
    }

    func testRGBToHSL() {
        assertHSL(PaletteMath.hsl(r: 255, g: 0, b: 0), h: 0, s: 1, l: 0.5)
        assertHSL(PaletteMath.hsl(r: 0, g: 255, b: 0), h: 120, s: 1, l: 0.5)
        assertHSL(PaletteMath.hsl(r: 0, g: 0, b: 255), h: 240, s: 1, l: 0.5)
        assertHSL(PaletteMath.hsl(r: 255, g: 0, b: 128), h: 330, s: 1, l: 0.5)
        assertHSL(PaletteMath.hsl(r: 128, g: 128, b: 128), h: 0, s: 0, l: 0.502)
    }

    func testHSLRoundTrips() {
        for (r, g, b) in [(255.0, 0.0, 0.0), (12, 200, 90), (30, 60, 220), (240, 240, 240), (99, 102, 241)] {
            let back = PaletteMath.rgb(PaletteMath.hsl(r: r, g: g, b: b))
            XCTAssertEqual(back.r * 255, r, accuracy: 0.5)
            XCTAssertEqual(back.g * 255, g, accuracy: 0.5)
            XCTAssertEqual(back.b * 255, b, accuracy: 0.5)
        }
    }

    func testWeightFavoursVividMidTones() {
        XCTAssertEqual(PaletteMath.weight(HSLColor(h: 0, s: 1, l: 0.5)), 1, accuracy: 1e-9)
        XCTAssertEqual(PaletteMath.weight(HSLColor(h: 0, s: 0, l: 0.5)), 0, accuracy: 1e-9)
        XCTAssertEqual(PaletteMath.weight(HSLColor(h: 0, s: 1, l: 0.1)), 1 - 0.4 * 1.6, accuracy: 1e-9)
    }

    func testBuckets() {
        XCTAssertEqual(PaletteMath.bucket(HSLColor(h: 0, s: 1, l: 0.5)), 0)
        XCTAssertEqual(PaletteMath.bucket(HSLColor(h: 29.9, s: 1, l: 0.5)), 0)
        XCTAssertEqual(PaletteMath.bucket(HSLColor(h: 30, s: 1, l: 0.5)), 1)
        XCTAssertEqual(PaletteMath.bucket(HSLColor(h: 359, s: 1, l: 0.5)), 11)
    }

    func testDominantOrdersByWeightAndPads() {
        let red = RGBA8(r: 220, g: 30, b: 30), blue = RGBA8(r: 30, g: 60, b: 220)
        let grey = RGBA8(r: 120, g: 120, b: 120)
        let pixels = Array(repeating: red, count: 30) + Array(repeating: blue, count: 10) + Array(repeating: grey, count: 60)
        let top = PaletteMath.dominant(pixels)
        XCTAssertEqual(top.count, 3)
        XCTAssertEqual(PaletteMath.bucket(top[0]), 0)
        XCTAssertEqual(PaletteMath.bucket(top[1]), 7)
        XCTAssertEqual(top[2], top[0], "padded with the lead colour")
    }

    func testDominantFallsBackToTheAverageWhenNothingIsVivid() {
        let pixels = Array(repeating: RGBA8(r: 40, g: 40, b: 40), count: 8) + Array(repeating: RGBA8(r: 200, g: 200, b: 200), count: 8)
        let top = PaletteMath.dominant(pixels)
        XCTAssertEqual(top.count, 3)
        assertHSL(top[0], h: 0, s: 0, l: 120.0 / 255)
        XCTAssertTrue(PaletteMath.dominant([]).isEmpty)
        XCTAssertTrue(PaletteMath.dominant([RGBA8(r: 255, g: 0, b: 0, a: 0)]).isEmpty, "transparent pixels don't count")
    }

    func testLiftClamps() {
        let muddy = HSLColor(h: 200, s: 0.1, l: 0.05)
        assertHSL(PaletteMath.lift(muddy, dark: true), h: 200, s: 0.42, l: 0.34)
        assertHSL(PaletteMath.lift(muddy, dark: false), h: 200, s: 0.40, l: 0.80)
        let loud = HSLColor(h: 10, s: 1, l: 0.9)
        assertHSL(PaletteMath.lift(loud, dark: true), h: 10, s: 0.78, l: 0.46)
        assertHSL(PaletteMath.lift(loud, dark: false), h: 10, s: 0.70, l: 0.86)
        assertHSL(PaletteMath.lift(loud, dark: true, mono: true), h: 10, s: 0, l: 0.46)
    }

    func testTints() {
        let lead = HSLColor(h: 120, s: 0.7, l: 0.4)
        assertHSL(PaletteMath.tint(lead, dark: true), h: 120, s: 0.5, l: 0.15)
        assertHSL(PaletteMath.tint2(lead, dark: true), h: 120, s: 0.5, l: 0.19)
        assertHSL(PaletteMath.tint(lead, dark: false), h: 120, s: 0.5, l: 0.935)
        assertHSL(PaletteMath.tint2(lead, dark: false), h: 120, s: 0.5, l: 0.895)
    }

    func testPaletteIsLiftedAndNeverNearBlack() throws {
        let pixels = Array(repeating: RGBA8(r: 20, g: 8, b: 6), count: 50) + Array(repeating: RGBA8(r: 120, g: 20, b: 10), count: 5)
        let dark = try XCTUnwrap(PaletteMath.palette(pixels, dark: true))
        XCTAssertEqual(dark.colors.count, 3)
        XCTAssertTrue(dark.colors.allSatisfy { $0.l >= 0.34 && $0.s >= 0.42 })
        let light = try XCTUnwrap(PaletteMath.palette(pixels, dark: false))
        XCTAssertTrue(light.colors.allSatisfy { $0.l >= 0.80 })
        XCTAssertGreaterThan(light.tint.s, 0, "Daylight grounds are never grey")
        let mono = try XCTUnwrap(PaletteMath.palette(pixels, dark: true, mono: true))
        XCTAssertTrue(mono.colors.allSatisfy { $0.s == 0 })
        XCTAssertEqual(mono.tint.s, 0)
        XCTAssertNil(PaletteMath.palette([], dark: true))
    }
}
