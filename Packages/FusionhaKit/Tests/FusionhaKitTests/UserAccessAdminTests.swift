import XCTest
@testable import FusionhaKit

/// Settings › Users: per-instance access grants and any user's sign-in methods
/// (web `AccessDialog`, `UserCredentialsDialog`).
final class UserAccessAdminTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    func testGrantsDecodeAndIndexByInstance() throws {
        let grants = try decode([AccessGrant].self, """
        [{"id":7,"user_id":3,"instance_id":2,"capabilities":["read"]},
         {"id":8,"user_id":3,"instance_id":null,"capabilities":["read","add"]},
         {"id":9,"user_id":3,"instance_id":5,"capabilities":[]}]
        """)
        XCTAssertEqual(grants.count, 3)
        XCTAssertEqual(grants[0].userId, 3)
        XCTAssertNil(grants[1].instanceId)
        let map = AccessGrant.byInstance(grants)
        XCTAssertEqual(Set(map.keys), [2, 5])
        XCTAssertEqual(map[2]?.id, 7)
        XCTAssertEqual(map[5]?.id, 9)
    }

    func testUserAccountCarriesCredentials() throws {
        let user = try decode(UserAccount.self, """
        {"id":4,"username":"eafx (plex:5967786)","is_admin":false,"plex_linked":true,
         "plex_username":"eafx","auth_provider":"plex",
         "credentials":[{"id":11,"provider":"plex","external_id":"5967786","is_primary":true,"is_active":true}]}
        """)
        XCTAssertEqual(user.plexLinked, true)
        XCTAssertEqual(user.credentials?.first?.externalId, "5967786")
        let subject = SignInSubject(user)
        XCTAssertEqual(subject.name, "eafx")
        XCTAssertTrue(subject.hasPlex)
        XCTAssertFalse(subject.hasLocal)
        XCTAssertTrue(subject.plexLinked)
    }

    func testOlderUserRowWithoutCredentialsStillDecodes() throws {
        let user = try decode(UserAccount.self, #"{"id":1,"username":"admin","is_admin":true}"#)
        XCTAssertNil(user.credentials)
        XCTAssertTrue(SignInSubject(user).credentials.isEmpty)
    }

    func testSignInRules() throws {
        let creds = try decode([UserCredential].self, """
        [{"id":1,"provider":"plex","external_id":"9","is_primary":true,"is_active":true},
         {"id":2,"provider":"oidc","external_id":"sub","is_primary":false,"is_active":false}]
        """)
        let s = SignInSubject(id: 3, name: "sam", credentials: creds, plexLinked: true, plexUsername: "sam")
        XCTAssertEqual(s.activeCount, 1)
        XCTAssertTrue(s.isLastActive(creds[0]))
        XCTAssertFalse(s.isLastActive(creds[1]))
        // INV8: only blocks the Plex-origin person adding their own first password.
        XCTAssertTrue(s.addPasswordBlocked(isSelf: true, canAdminSystem: false))
        XCTAssertFalse(s.addPasswordBlocked(isSelf: true, canAdminSystem: true))
        XCTAssertFalse(s.addPasswordBlocked(isSelf: false, canAdminSystem: false))
        XCTAssertFalse(SignInSubject.canMove(creds[0], canAdminSystem: true))
        XCTAssertTrue(SignInSubject.canMove(creds[1], canAdminSystem: true))
        XCTAssertFalse(SignInSubject.canMove(creds[1], canAdminSystem: false))
    }

    func testMoveResultDecodes() throws {
        let r = try decode(MoveCredentialResult.self, """
        {"credential_id":2,"provider":"local","source_user_id":3,"target_user_id":4,
         "source_sessions_revoked":1,"plex_adopted":false}
        """)
        XCTAssertEqual(r.targetUserId, 4)
        XCTAssertEqual(r.sourceSessionsRevoked, 1)
        let minimal = try decode(MoveCredentialResult.self,
                                 #"{"credential_id":2,"provider":"local","source_user_id":3,"target_user_id":4}"#)
        XCTAssertNil(minimal.plexAdopted)
    }
}
