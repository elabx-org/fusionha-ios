import XCTest
@testable import FusionhaKit

/// Manual Import's loading, error and empty sentences match the web's
/// (`ScanStates.tsx`, `ScanBody.tsx`, `ItemMatchDialog.tsx`), singular and plural.
final class ManualImportStateCopyTests: XCTestCase {
    func testRescueLoadingSingularAndPlural() {
        XCTAssertEqual(ManualImportCopy.rescueLoading(count: 1), "Opening the held download for a manual (force) import…")
        XCTAssertEqual(ManualImportCopy.rescueLoading(count: 3), "Opening 3 held downloads for a manual (force) import…")
    }

    func testRescueErrorSingularAndPlural() {
        XCTAssertEqual(ManualImportCopy.rescueError(count: 1),
                       "This held download could not be opened for manual import — it may have already been imported, or its files are no longer on disk.")
        XCTAssertEqual(ManualImportCopy.rescueError(count: 2),
                       "These held downloads could not be opened for manual import — some may have already been imported, or their files are no longer on disk.")
    }

    func testScanAndFilterCopy() {
        XCTAssertEqual(ManualImportCopy.scanError,
                       "That folder could not be scanned. Check the path is a directory the server can reach.")
        XCTAssertEqual(ManualImportCopy.filterEmpty, "Nothing matches this filter.")
        XCTAssertEqual(ManualImportCopy.noVideos(folder: true), "No video files in this folder")
        XCTAssertEqual(ManualImportCopy.noVideos(folder: false), "No video files in this download")
    }

    func testLibraryMatchTrimsTheTerm() {
        XCTAssertEqual(ManualImportCopy.noLibraryMatch("  Dune "),
                       "No library item matches “Dune”. Add the title first, then re-scan.")
    }
}
