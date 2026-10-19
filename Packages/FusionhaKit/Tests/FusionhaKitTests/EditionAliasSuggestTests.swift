import XCTest
@testable import FusionhaKit

final class EditionAliasSuggestTests: XCTestCase {
    func testParsesMismatchWithApostrophe() {
        let m = EditionAliasSuggest.mismatch("Release edition 'Final Cut' does not match the tracked edition 'Director's Cut'")
        XCTAssertEqual(m, .init(releaseEdition: "Final Cut", tracked: "Director's Cut"))
        XCTAssertNil(EditionAliasSuggest.mismatch("Not wanted in the quality profile"))
        XCTAssertNil(EditionAliasSuggest.mismatch(nil))
    }

    func testTermBetweenYearAndQuality() {
        XCTAssertEqual(EditionAliasSuggest.term("Frankenstein.1931.Vrach.Frankenshteyn.Cut.1080p.BluRay.x264-GRP"),
                       "Vrach Frankenshteyn Cut")
        XCTAssertEqual(EditionAliasSuggest.term("Blade.Runner.2049.2017.Final.Cut.2160p.WEB-DL"), "Final Cut")
        XCTAssertEqual(EditionAliasSuggest.term("No.Year.Here.1080p"), "")
        XCTAssertEqual(EditionAliasSuggest.term("Movie.2001.1080p"), "")
    }
}
