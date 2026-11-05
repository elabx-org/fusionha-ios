import XCTest
@testable import FusionhaKit

final class AppIdentityTests: XCTestCase {
    private let v2Info: [String: Any] = [
        AppIdentity.appGroupKey: "group.org.elabx.fusionha.v2",
        AppIdentity.keychainNamespaceKey: "org.elabx.fusionha.v2",
        AppIdentity.urlSchemeKey: "fusionha2",
    ]

    func testDefaultsAreV1Literals() {
        let id = AppIdentity(info: [:])
        XCTAssertEqual(id, .v1)
        XCTAssertEqual(id.appGroup, "group.org.elabx.fusionha")
        XCTAssertEqual(id.keychainNamespace, "org.elabx.fusionha")
        XCTAssertEqual(id.urlScheme, "fusionha")
        XCTAssertTrue(id.isV1)
        XCTAssertEqual(id.service("api-token"), "org.elabx.fusionha.api-token")
        XCTAssertEqual(id.service("credentials"), "org.elabx.fusionha.credentials")
        XCTAssertEqual(id.service("probe"), "org.elabx.fusionha.probe")
        XCTAssertEqual(id.service("shared-state"), "org.elabx.fusionha.shared-state")
        XCTAssertEqual(id.service("web-session"), "org.elabx.fusionha.web-session")
        XCTAssertEqual(id.link("item/42")?.absoluteString, "fusionha://item/42")
    }

    /// The test host's bundle names none of the keys: the process is v1.
    func testCurrentFallsBackToV1() {
        XCTAssertEqual(AppIdentity.current, .v1)
        XCTAssertEqual(CredentialStore.appGroup, "group.org.elabx.fusionha")
    }

    func testEmptyOrWrongTypedValuesKeepV1() {
        let id = AppIdentity(info: [AppIdentity.appGroupKey: "  ", AppIdentity.urlSchemeKey: 3])
        XCTAssertEqual(id, .v1)
    }

    func testV1TeamGroupsMatchTheOldList() {
        let v1 = AppIdentity.v1
        XCTAssertEqual(v1.teamGroups(prefix: "ABCDE12345", defaultGroup: "ABCDE12345.org.elabx.fusionha.shared"),
                       ["ABCDE12345.org.elabx.fusionha.shared", "ABCDE12345.*"])
        XCTAssertEqual(v1.teamGroups(prefix: "ABCDE12345", defaultGroup: "ABCDE12345.*"),
                       ["ABCDE12345.org.elabx.fusionha.shared", "ABCDE12345.*"])
        XCTAssertEqual(v1.teamGroups(prefix: "ABCDE12345", defaultGroup: "ABCDE12345.org.*"),
                       ["ABCDE12345.org.elabx.fusionha.shared", "ABCDE12345.*", "ABCDE12345.org.*"])
    }

    func testV2NeverYieldsWildcardOrV1Groups() {
        let v2 = AppIdentity(info: v2Info)
        XCTAssertFalse(v2.isV1)
        XCTAssertEqual(v2.appGroup, "group.org.elabx.fusionha.v2")
        XCTAssertNotEqual(v2.appGroup, AppIdentity.v1.appGroup)
        for defaultGroup in ["ABCDE12345.*", "ABCDE12345.org.*", "ABCDE12345.org.elabx.fusionha.v2.shared",
                             "ABCDE12345.org.elabx.fusionha.shared"] {
            let groups = v2.teamGroups(prefix: "ABCDE12345", defaultGroup: defaultGroup)
            XCTAssertEqual(groups, ["ABCDE12345.org.elabx.fusionha.v2.shared"])
            XCTAssertFalse(groups.contains { $0.contains("*") })
            XCTAssertFalse(groups.contains("ABCDE12345.org.elabx.fusionha.shared"))
            XCTAssertFalse(groups.contains(AppIdentity.v1.appGroup))
        }
    }

    func testV2ServicesAndLinksAreItsOwn() {
        let v2 = AppIdentity(info: v2Info)
        for name in ["api-token", "credentials", "probe", "shared-state", "web-session"] {
            XCTAssertNotEqual(v2.service(name), AppIdentity.v1.service(name))
            XCTAssertTrue(v2.service(name).hasPrefix("org.elabx.fusionha.v2."))
        }
        XCTAssertEqual(WidgetRoute.item(42).link(in: v2).absoluteString, "fusionha2://item/42")
        XCTAssertEqual(WidgetRoute.requests.link(in: v2).absoluteString, "fusionha2://discover/requests")
        XCTAssertEqual(PushLink.deepLink(webPath: "/activity?tab=queue&focus=8", identity: v2)?.absoluteString,
                       "fusionha2://activity/queue?focus=8")
        XCTAssertTrue(v2.owns(URL(string: "fusionha2://activity")!))
        XCTAssertFalse(v2.owns(URL(string: "fusionha://activity")!))
        XCTAssertFalse(AppIdentity.v1.owns(URL(string: "fusionha2://activity")!))
    }
}
