import XCTest
@testable import FusionhaKit

final class SignInMethodsLineTests: XCTestCase {
    func testPrimaryFirstAndInactiveLeftOut() throws {
        let json = #"[{"id":1,"provider":"plex","display_handle":"eafx","is_primary":false,"is_active":true},{"id":2,"provider":"local","is_primary":true,"is_active":true},{"id":3,"provider":"oidc","is_primary":false,"is_active":false}]"#
        let creds = try APIClient.decoder.decode([UserCredential].self, from: Data(json.utf8))
        XCTAssertEqual(SignInMethodsLine.text(creds), "Password · Plex (eafx)")
    }

    func testFallsBackToPlexName() {
        XCTAssertEqual(SignInMethodsLine.text(nil, plexUsername: "sam"), "Plex (sam)")
        XCTAssertNil(SignInMethodsLine.text([]))
    }
}
