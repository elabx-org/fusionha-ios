import XCTest
@testable import FusionhaKit

final class UsersRosterTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func users() throws -> [UserAccount] {
        try decode([UserAccount].self, """
        [
          {"id": 1, "username": "owner", "is_admin": true, "is_active": true},
          {"id": 2, "username": "ana", "is_admin": false, "role_name": "Requestor", "is_active": true, "auth_provider": "plex"},
          {"id": 3, "username": "bo", "is_admin": false, "role_name": "Manager"},
          {"id": 4, "username": "cy", "is_admin": false, "role_name": "Requestor", "is_active": false},
          {"id": 5, "username": "di", "is_admin": false, "role_name": "Curators",
           "credentials": [{"id": 9, "provider": "plex", "is_primary": true, "is_active": true}]},
          {"id": 6, "username": "ed", "is_admin": false}
        ]
        """)
    }

    // MARK: Search (UsersList matches)

    func testSearchMatchesNameRoleAndProvider() throws {
        let all = try users()
        func ids(_ q: String) -> [Int] { all.filter { UsersRoster.matches($0, query: q) }.map(\.id) }
        XCTAssertEqual(ids(""), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(ids("  ANA "), [2, 3]) // "ana", and "Manager"
        XCTAssertEqual(ids("requestor"), [2, 4])
        XCTAssertEqual(ids("plex"), [5])
        XCTAssertEqual(ids("zzz"), [])
    }

    // MARK: UHD·4K (users-uhd.ts)

    func testBanner() {
        XCTAssertNil(UsersUHD.banner(active: nil, uhdLibraryCount: 0))
        XCTAssertEqual(UsersUHD.banner(active: false, uhdLibraryCount: 2), .off)
        XCTAssertEqual(UsersUHD.banner(active: true, uhdLibraryCount: 0), .noLibrary)
        XCTAssertNil(UsersUHD.banner(active: true, uhdLibraryCount: 1))
    }

    func testChipCopy() {
        XCTAssertEqual(UsersUHD.chip(uhd: true, source: "plex", detail: nil, isAdmin: true).label, "UHD·4K · admin")
        let plex = UsersUHD.chip(uhd: false, source: "plex", detail: nil)
        XCTAssertEqual(plex.label, "HD only · from Plex")
        XCTAssertEqual(plex.title, "From Plex: not fetched from Plex yet")
        XCTAssertEqual(UsersUHD.chip(uhd: true, source: "plex", detail: "shares Movies 4K").title, "From Plex: shares Movies 4K")
        XCTAssertEqual(UsersUHD.chip(uhd: true, source: "role", detail: nil).label, "UHD·4K · from role")
        XCTAssertEqual(UsersUHD.chip(uhd: false, source: "user", detail: nil).label, "HD only · manual")
        let open = UsersUHD.chip(uhd: true, source: "default", detail: "not linked to Plex")
        XCTAssertEqual(open.label, "All versions")
        XCTAssertEqual(open.title, "No restriction: not linked to Plex")
        XCTAssertEqual(UsersUHD.chip(uhd: true, source: "default", detail: nil).title, "No restriction")
        XCTAssertEqual(UsersUHD.legend.map(\.label), ["UHD·4K · manual", "UHD·4K · from Plex", "All versions"])
    }

    func testTierAccessDecodesDetail() throws {
        let row = try decode(UserTierAccess.self,
                             #"{"user_id": 2, "uhd": true, "source": "plex", "detail": "shares 4K", "stale": true, "fetched_at": "2026-10-01T00:00:00"}"#)
        XCTAssertEqual(row.detail, "shares 4K")
        XCTAssertTrue(row.stale)
        XCTAssertEqual(UsersUHD.qualifier(row), "shares 4K · stale")
        XCTAssertEqual(UsersUHD.chip(row).label, "UHD·4K · from Plex")
    }

    // MARK: Pulse and groups

    func testPulseCounts() throws {
        let all = try users()
        XCTAssertEqual(UsersRoster.count(.total, in: all), 6)
        XCTAssertEqual(UsersRoster.count(.admin, in: all), 1)
        XCTAssertEqual(UsersRoster.count(.requestor, in: all), 1) // the disabled one doesn't count
        XCTAssertEqual(UsersRoster.count(.plex, in: all), 2) // provider or a Plex credential
        XCTAssertEqual(UsersRoster.count(.disabled, in: all), 1)
    }

    func testGroupsOrder() throws {
        let groups = try UsersRoster.groups(users())
        XCTAssertEqual(groups.map(\.label), ["Administrators", "Requestors", "Managers", "Curators", "No role", "Disabled"])
        XCTAssertEqual(groups.first { $0.id == "disabled" }?.users.map(\.id), [4])
        XCTAssertEqual(groups.first { $0.id == "role:Manager" }?.accent, .grab)
    }

    // MARK: Duplicates

    func testDuplicatesAndSurvivor() throws {
        let groups = try decode(DuplicatesRead.self, """
        {"groups": [{"reason": "email", "key": "a@x", "members": [
          {"id": 7, "username": "eafx (plex:1)", "auth_provider": "plex"},
          {"id": 3, "username": "eafx", "auth_provider": "local"}
        ]}]}
        """).groups
        XCTAssertEqual(UsersRoster.defaultSurvivor(groups[0].members), 3)
        XCTAssertEqual(UsersRoster.duplicatesLine(groups), "eafx (plex:1) ↔ eafx")
        let admin = try decode([DuplicateMember].self, #"[{"id": 1, "username": "a", "auth_provider": "plex"}, {"id": 2, "username": "b", "auth_provider": "plex", "is_admin": true}]"#)
        XCTAssertEqual(UsersRoster.defaultSurvivor(admin), 2)
    }

    func testMergeAndDisconnectPreviews() throws {
        let merge = try decode(MergePreview.self, #"{"survivor_id": 3, "loser_id": 7, "role_resolution": "keep_survivor", "credentials_repointed": 1}"#)
        XCTAssertEqual(merge.roleLine, "None")
        XCTAssertEqual(merge.credentialsRepointed, 1)
        XCTAssertFalse(merge.refused)
        let disc = try decode(DisconnectPreview.self, """
        {"provider": "plex", "fallback": "disable", "affected": [
          {"user_id": 1, "username": "a", "would_be_zeroed": true, "action": "disable"},
          {"user_id": 2, "username": "b", "would_be_zeroed": false, "action": "none"}]}
        """)
        XCTAssertEqual(disc.zeroed, 1)
        XCTAssertEqual(disc.safe, 1)
    }
}
