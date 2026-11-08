import XCTest
@testable import FusionhaKit

final class SafeFileNameTests: XCTestCase {
    func testKeepsSafeNames() {
        XCTAssertEqual(SafeFileName.sanitize("fusionha-2026-11-08_0300.tar.gz", fallback: "x"),
                       "fusionha-2026-11-08_0300.tar.gz")
    }

    func testReplacesUnsafeCharacters() {
        XCTAssertEqual(SafeFileName.sanitize("a/b\\c d:é", fallback: "x"), "a_b_c_d__")
    }

    func testRejectsTraversal() {
        XCTAssertEqual(SafeFileName.sanitize("..", fallback: "backup"), "backup")
        XCTAssertEqual(SafeFileName.sanitize("../../Library/Preferences/x.plist", fallback: "backup"), "backup")
        XCTAssertEqual(SafeFileName.sanitize("a..b", fallback: "backup"), "backup")
        XCTAssertEqual(SafeFileName.sanitize(".", fallback: "backup"), "backup")
        XCTAssertEqual(SafeFileName.sanitize("", fallback: "backup"), "backup")
    }

    func testFileStaysInsideTheFolder() {
        let folder = URL(fileURLWithPath: "/fusionha-tests/backups", isDirectory: true)
        XCTAssertEqual(SafeFileName.file(named: "b1.tar", in: folder, fallback: "backup")?.path,
                       "/fusionha-tests/backups/b1.tar")
        XCTAssertEqual(SafeFileName.file(named: "../../etc/passwd", in: folder, fallback: "backup")?.path,
                       "/fusionha-tests/backups/backup")
        XCTAssertEqual(SafeFileName.file(named: "/etc/passwd", in: folder, fallback: "backup")?.path,
                       "/fusionha-tests/backups/_etc_passwd")
        XCTAssertNil(SafeFileName.file(named: "..", in: folder, fallback: ".."))
    }
}

final class ResponseDiskCacheSecretsTests: XCTestCase {
    private func cacheable(_ path: String) -> Bool {
        ResponseDiskCache.cacheable(URL(string: "https://fusionha.example.com" + path)!)
    }

    func testRevealedSecretsAreNeverCached() {
        XCTAssertFalse(cacheable("/api/v1/settings/api-key"))
        XCTAssertFalse(cacheable("/api/v1/instances/3/reveal-key"))
        XCTAssertFalse(cacheable("/proxy/api/v1/instances/3/reveal-key"))
        XCTAssertFalse(cacheable("/api/v1/tokens"))
        XCTAssertFalse(cacheable("/api/v1/notifications/7/reveal-secret"))
    }

    func testPageAnswersStayCacheable() {
        XCTAssertTrue(cacheable("/api/v1/queue"))
        XCTAssertTrue(cacheable("/api/v1/settings/general"))
        XCTAssertTrue(cacheable("/api/v1/instances"))
    }
}
