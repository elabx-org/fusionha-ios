import XCTest
@testable import FusionhaKit

final class RunVersionScopeTests: XCTestCase {
    func testVersionIdWins() {
        XCTAssertTrue(RunVersionScope.candidateInScope(candidateVersionId: 3, quality: "Bluray-2160p", versionId: 3, tier: .hd))
        XCTAssertFalse(RunVersionScope.candidateInScope(candidateVersionId: 4, quality: nil, versionId: 3, tier: .hd))
    }

    func testQualityTierFallback() {
        XCTAssertTrue(RunVersionScope.candidateInScope(candidateVersionId: nil, quality: "WEBDL-2160p", versionId: 3, tier: .uhd))
        XCTAssertFalse(RunVersionScope.candidateInScope(candidateVersionId: nil, quality: "WEBDL-1080p", versionId: 3, tier: .uhd))
        XCTAssertTrue(RunVersionScope.candidateInScope(candidateVersionId: nil, quality: "WEBDL-720p", versionId: 3, tier: .hd))
    }

    func testUnknownCounts() {
        XCTAssertTrue(RunVersionScope.candidateInScope(candidateVersionId: nil, quality: nil, versionId: 3, tier: .hd))
        XCTAssertTrue(RunVersionScope.candidateInScope(candidateVersionId: nil, quality: "WEBDL-1080p", versionId: 3, tier: nil))
    }
}
