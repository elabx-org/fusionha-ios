import XCTest
@testable import FusionhaKit

/// The scanned root's "parent / last" line (web `SourceLine`, `top-chrome.test.tsx`).
final class ManualImportPathsTests: XCTestCase {
    func testParentAndShortenedLast() {
        let path = "/mnt/symlinks/fusionha-tv-4k/Mad.Men.S04E02.Christmas.Comes.But.Once.a.Year.REPACK.2160p.HMAX.WEB-DL.DDP5.1.DV.HDR.H.265-WADU"
        let line = ManualImportPaths.sourceLine(path)
        XCTAssertEqual(line.parent, "fusionha-tv-4k")
        XCTAssertEqual(line.last, "Mad.Men.S04E02.…HDR.H.265-WADU")
    }

    func testNoParentAtTheRoot() {
        XCTAssertEqual(ManualImportPaths.sourceLine("/downloads"), .init(parent: "", last: "downloads"))
        XCTAssertEqual(ManualImportPaths.sourceLine("/downloads/complete/"), .init(parent: "downloads", last: "complete"))
    }
}
