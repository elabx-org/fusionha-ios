import XCTest
@testable import FusionhaKit

/// Every refusal of the bulk decide, the override, the commit and the finish
/// reads as plain copy (fusionha 0.4.225 `docs/API.md`; the web's
/// `decideErrorMessage`, `overrideErrorMessage`, `finishErrorMessage`).
final class ManualImportRefusalTests: XCTestCase {
    private func coded(_ status: Int, _ code: String, _ extra: String = "") -> APIError {
        .http(status: status, body: #"{"detail": {"code": "\#(code)"\#(extra)}}"#)
    }

    func testDecideRefusalsInOrder() {
        XCTAssertEqual(ManualImportCopy.decideError(APIError.http(status: 404, body: #"{"detail": "scan not found"}"#)),
                       "This scan is gone. Close Manual import and open it again.")
        let invalid = APIError.http(status: 422, body: #"{"detail": {"invalid_rows": [{"row_id": 4, "reason": "already imported"}, {"row_id": 5, "reason": "row not found"}]}}"#)
        XCTAssertEqual(invalid.invalidRowReasons, ["already imported", "row not found"])
        XCTAssertEqual(ManualImportCopy.decideError(invalid), "already imported")
        XCTAssertEqual(ManualImportCopy.decideError(coded(422, "unknown_download", #", "download_ids": [9]"#)),
                       "That choice no longer fits these files. Review the rows and try again.")
        XCTAssertEqual(ManualImportCopy.decideError(coded(403, "forbidden")),
                       "Removing a download needs the system.admin permission; pick leave.")
        XCTAssertEqual(ManualImportCopy.decideError(coded(422, "disposition_needs_keep", #", "download_ids": [77]"#)),
                       "That choice no longer fits these files. Review the rows and try again.")
        XCTAssertEqual(ManualImportCopy.decideError(coded(409, "leave_stands", #", "download_id": 77, "row_id": 3"#)),
                       "A leave was chosen for this download on another file; change it there.")
        XCTAssertEqual(ManualImportCopy.decideError(coded(409, "finish_in_progress")),
                       "A held download is being finished. Try again in a moment.")
        XCTAssertEqual(ManualImportCopy.decideError(coded(503, "db_busy")), "The database is busy. Try again in a moment.")
        XCTAssertEqual(ManualImportCopy.decideError(URLError(.timedOut)), "Couldn't apply that. Try again.")
    }

    func testOverrideRefusals() {
        XCTAssertEqual(ManualImportCopy.overrideError(coded(422, "disposition_not_held")),
                       "This file isn't part of a held download, so there is no download to finish.")
        XCTAssertEqual(ManualImportCopy.overrideError(coded(422, "disposition_needs_keep")), "Pick Keep current for this file first.")
        XCTAssertEqual(ManualImportCopy.overrideError(coded(403, "forbidden")), ManualImportCopy.removeForbidden)
        XCTAssertEqual(ManualImportCopy.overrideError(coded(409, "leave_stands")), ManualImportCopy.leaveStands)
        XCTAssertEqual(ManualImportCopy.overrideError(coded(409, "finish_in_progress")),
                       "This download is being finished. Try again in a moment.")
        XCTAssertNil(ManualImportCopy.overrideError(coded(422, "something_else")))
    }

    func testFinishAndCommitNameLeaveStandsAndForbidden() {
        XCTAssertEqual(ManualImportCopy.finishError(coded(409, "leave_stands")), ManualImportCopy.leaveStands)
        XCTAssertEqual(ManualImportCopy.finishError(coded(403, "forbidden")), ManualImportCopy.removeForbidden)
        XCTAssertEqual(ManualImportCopy.finishError(coded(409, "not_held")),
                       "This download isn't waiting on you any more. Refresh the queue.")
        XCTAssertEqual(ManualImportCopy.commitError(coded(409, "leave_stands")), ManualImportCopy.leaveStands)
        XCTAssertEqual(ManualImportCopy.commitError(coded(403, "forbidden")), ManualImportCopy.removeForbidden)
        XCTAssertEqual(ManualImportCopy.commitError(coded(409, "finish_in_progress")),
                       "A held download is being finished. Try the import again in a moment.")
    }
}
