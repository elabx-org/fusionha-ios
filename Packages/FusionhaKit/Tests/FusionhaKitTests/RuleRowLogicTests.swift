import XCTest
@testable import FusionhaKit

final class RuleRowLogicTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String) -> T {
        try! APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func rule(kind: String = "APPROVE_TIER", enabled: Bool = true, locked: Bool = false, role: String? = nil) -> RequestRule {
        let roleJSON = role.map { #","role_name":"\#($0)""# } ?? ""
        return decode(#"{"id":1,"position":0,"kind":"\#(kind)","enabled":\#(enabled),"locked":\#(locked),"label":"Approve HD"\#(roleJSON)}"#)
    }

    func testGuardRoots() {
        let roots: [RootFolder] = decode(#"[{"id":1,"path":"/movies","free_space":412900000000,"accessible":true},{"id":2,"path":"/uhd","free_space":5000000000,"accessible":false},{"id":3,"path":"/unused","free_space":1}]"#)
        let slots: [AddDefaultSlot] = decode(#"[{"profile_kind":"movie","tier":"HD-1080p","root_folder_id":1},{"profile_kind":"series","tier":"HD-1080p","root_folder_id":1},{"profile_kind":"movie","tier":"UHD-2160p","root_folder_id":2}]"#)
        let all = GuardRoot.from(roots: roots, slots: slots)
        XCTAssertEqual(all.map(\.path), ["/movies", "/uhd"])
        XCTAssertEqual(all[0].freeGb, 412)
        XCTAssertEqual(all[0].tiers, [.hd])
        XCTAssertNil(all[1].freeGb)
        XCTAssertEqual(all[1].line.free, "free space unknown")
        XCTAssertEqual(all[0].line.free, "412 GB free")
        XCTAssertEqual(GuardRoot.roots(all, for: .uhd).map(\.path), ["/uhd"])
        XCTAssertEqual(GuardRoot.roots(all, for: nil).count, 2)
    }

    func testRuleReasonsAndAudience() {
        XCTAssertEqual(RuleRowCopy.audience(rule()), "Everyone")
        XCTAssertEqual(RuleRowCopy.audience(rule(role: "Family")), "Role: Family")
        let readOnly = RuleRowCopy.reasons(rule(), canManage: false, isAdmin: false)
        XCTAssertEqual(readOnly.toggle, RuleRowCopy.needsManage)
        XCTAssertEqual(readOnly.order, RuleRowCopy.needsManage)
        let guardOn = RuleRowCopy.reasons(rule(kind: "GUARD_FREE_SPACE"), canManage: true, isAdmin: false)
        XCTAssertEqual(guardOn.toggle, RuleRowCopy.guardAdminOnly)
        XCTAssertEqual(guardOn.delete, RuleRowCopy.guardAdminOnly)
        XCTAssertNil(guardOn.edit)
        let guardOff = RuleRowCopy.reasons(rule(kind: "GUARD_FREE_SPACE", enabled: false), canManage: true, isAdmin: false)
        XCTAssertNil(guardOff.toggle)
        let builtIn = RuleRowCopy.reasons(rule(locked: true), canManage: true, isAdmin: true)
        XCTAssertEqual(builtIn.edit, RuleRowCopy.builtInOnly)
        XCTAssertEqual(builtIn.delete, RuleRowCopy.builtInOnly)
        XCTAssertNil(builtIn.toggle)
    }
}
