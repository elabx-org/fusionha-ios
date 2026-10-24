import XCTest
@testable import FusionhaKit

/// The pre-rendered glow and ambient bitmaps: one per URL, kind, tone and
/// geometry, with the live effects' numbers baked in.
final class ArtBlurSpecTests: XCTestCase {
    private let url = "https://image.tmdb.org/t/p/w92/abc.jpg"

    func testToneMonoWinsOverLight() {
        XCTAssertEqual(ArtTone(isLight: true, isMono: true), .mono)
        XCTAssertEqual(ArtTone(isLight: true, isMono: false), .light)
        XCTAssertEqual(ArtTone(isLight: false, isMono: false), .dark)
    }

    func testKeyDiffersPerTone() {
        let keys = Set(ArtTone.allCases.map {
            ArtBlurSpec.glow(aspect: 2 / 3, tone: $0, cornerRadius: 12, referenceWidth: 120).key(for: url)
        })
        XCTAssertEqual(keys.count, 3)
    }

    func testKeyDiffersPerURLAndKind() {
        let poster = ArtBlurSpec.glow(aspect: 2 / 3, tone: .dark, cornerRadius: 12, referenceWidth: 120)
        XCTAssertNotEqual(poster.key(for: url), poster.key(for: url + "x"))
        let ambient = ArtBlurSpec.ambient(.detailAmbient, tone: .dark, aspect: 2 / 3)
        XCTAssertNotEqual(poster.key(for: url), ambient.key(for: url))
        XCTAssertNotEqual(ambient.key(for: url),
                          ArtBlurSpec.ambient(.previewAmbient, tone: .dark, aspect: 2 / 3).key(for: url))
    }

    func testKeyStableForNearlyEqualAspects() {
        let a = ArtBlurSpec.glow(aspect: 2 / 3, tone: .dark, cornerRadius: 12, referenceWidth: 120)
        let b = ArtBlurSpec.glow(aspect: 0.6667, tone: .dark, cornerRadius: 12, referenceWidth: 120)
        XCTAssertEqual(a.key(for: url), b.key(for: url))
        let shelf = ArtBlurSpec.glow(aspect: 16 / 9, tone: .dark, cornerRadius: 14, referenceWidth: 240)
        XCTAssertNotEqual(a.key(for: url), shelf.key(for: url))
    }

    func testGlowBakesTheLiveEffects() {
        let dark = ArtBlurSpec.glow(aspect: 2 / 3, tone: .dark, cornerRadius: 12, referenceWidth: 120)
        XCTAssertEqual(dark.saturation, 1.9)
        XCTAssertEqual(dark.alpha, 0.6)
        XCTAssertEqual(ArtBlurSpec.glow(aspect: 2 / 3, tone: .light, cornerRadius: 12, referenceWidth: 120).alpha, 0.45)
        XCTAssertEqual(ArtBlurSpec.glow(aspect: 2 / 3, tone: .mono, cornerRadius: 12, referenceWidth: 120).saturation, 0)
        // 20 pt blur on a 120 pt card, at 96 px across the card.
        XCTAssertEqual(dark.blur, 16, accuracy: 0.001)
        XCTAssertFalse(dark.clampsEdges)
    }

    func testGlowArtSitsInsideTheCanvasDroppedAndInset() {
        let spec = ArtBlurSpec.glow(aspect: 2 / 3, tone: .dark, cornerRadius: 12, referenceWidth: 120)
        XCTAssertGreaterThan(spec.art.x, 0)
        XCTAssertLessThan(spec.art.x + spec.art.width, spec.canvasWidth)
        XCTAssertLessThan(spec.art.y + spec.art.height, spec.canvasHeight)
        XCTAssertEqual(spec.art.width, 96 * 0.92, accuracy: 0.001)
        // Dropped: more room above the art than below it.
        let below = spec.canvasHeight - spec.art.y - spec.art.height
        XCTAssertGreaterThan(spec.art.y, below)
        // The overscan maps the canvas back onto the card's frame.
        XCTAssertEqual(spec.overscanX * 96, spec.canvasWidth, accuracy: 1)
    }

    func testAmbientMonoIsGreyAndClamped() {
        let mono = ArtBlurSpec.ambient(.detailAmbient, tone: .mono, aspect: 16 / 9)
        XCTAssertEqual(mono.saturation, 0)
        XCTAssertTrue(mono.clampsEdges)
        XCTAssertEqual(ArtBlurSpec.ambient(.detailAmbient, tone: .light, aspect: 16 / 9).brightness, 0)
        XCTAssertEqual(ArtBlurSpec.ambient(.detailAmbient, tone: .dark, aspect: 16 / 9).brightness, -0.2)
        XCTAssertEqual(ArtBlurSpec.ambient(.previewAmbient, tone: .dark, aspect: 2 / 3).brightness, -0.12)
        XCTAssertGreaterThan(mono.blur, 0)
    }
}
