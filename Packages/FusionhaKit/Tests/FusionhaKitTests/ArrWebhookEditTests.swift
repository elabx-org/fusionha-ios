import XCTest
@testable import FusionhaKit

final class ArrWebhookEditTests: XCTestCase {
    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func webhook() throws -> ArrWebhookGroup.Webhook {
        try decoder.decode(ArrWebhookGroup.Webhook.self, from: Data(#"""
            {"id":7,"instance_id":3,"name":"decypharr","implementation":"Webhook","url":"http://d:8282/hook",
             "method":2,"username":"bob","headers":{"X-Token":"••••••","X-Plain":"a"},
             "send_validation_results":false,"password_configured":true,"on_grab":true,"on_import":false,
             "on_upgrade":true,"on_rename":false,"on_delete":false,"on_delete_for_upgrade":true,
             "on_manual_interaction_required":false,"on_import_failure":false,"on_download_failure":false,
             "on_media_added":false,"on_media_removed":false,"on_health_issue":true,"on_health_restored":false,
             "on_application_update":false,"source":"decypharr","path_mappings":[{"from":"/data","to":"/mnt"}]}
            """#.utf8))
    }

    func testTriggerGroupsCoverAllFourteen() {
        XCTAssertEqual(ArrWebhookTrigger.allCases.count, 14)
        XCTAssertEqual(ArrWebhookTriggerGroup.allCases.map { ArrWebhookTrigger.inGroup($0).count }, [5, 3, 3, 3])
        XCTAssertEqual(ArrWebhookTriggerGroup.problems.label, "Problems")
    }

    func testNewDraftUsesServerDefaultsAndNeedsInstance() {
        var draft = ArrWebhookDraft(webhook: nil)
        XCTAssertTrue(draft.isOn(.onImport))
        XCTAssertTrue(draft.isOn(.onUpgrade))
        XCTAssertFalse(draft.isOn(.onGrab))
        XCTAssertTrue(draft.sendValidationResults)
        draft.name = "Hook"
        draft.url = "https://example.com/hook"
        XCTAssertFalse(draft.isValid)
        draft.instanceId = 4
        XCTAssertTrue(draft.isValid)
        guard case .object(let body) = draft.body else { return XCTFail("object") }
        XCTAssertEqual(body["instance_id"], .int(4))
        XCTAssertEqual(body["password"], .null)
        XCTAssertEqual(body["username"], .null)
        XCTAssertEqual(body["on_import"], .bool(true))
    }

    func testEditDraftKeepsMaskedHeadersAndOmitsInstance() throws {
        var draft = ArrWebhookDraft(webhook: try webhook())
        XCTAssertFalse(draft.isNew)
        XCTAssertTrue(draft.authStartsOpen)
        XCTAssertEqual(draft.method, 2)
        XCTAssertTrue(draft.isOn(.onHealthIssue))
        XCTAssertFalse(draft.isOn(.onImport))
        draft.pathMappings.append(ArrWebhookPathMapping(from: " ", to: "/x"))
        guard case .object(let body) = draft.body else { return XCTFail("object") }
        XCTAssertNil(body["instance_id"])
        XCTAssertEqual(body["headers"], .object(["X-Token": .string(SecretPlaceholder.value), "X-Plain": .string("a")]))
        XCTAssertEqual(body["path_mappings"], .array([.object(["from": "/data", "to": "/mnt"])]))
        XCTAssertEqual(body["on_delete_for_upgrade"], .bool(true))
    }

    func testHeaderRowsRenameDropsStoredValue() {
        var rows = SecretHeaderRow.rows(from: ["A": SecretPlaceholder.value])
        XCTAssertTrue(rows[0].stored)
        XCTAssertEqual(rows[0].value, "")
        rows[0].key = "B"
        XCTAssertEqual(SecretHeaderRow.headersForWrite(rows), [:])
        rows[0].value = "new"
        XCTAssertEqual(SecretHeaderRow.headersForWrite(rows), ["B": "new"])
        rows.append(SecretHeaderRow(key: "  ", value: "x"))
        XCTAssertEqual(SecretHeaderRow.headersForWrite(rows), ["B": "new"])
    }

    func testConnectionCreateSlugScopeAndSuggestion() {
        XCTAssertEqual(ConnectionCreate.slugify("  Radarr HD (main)! "), "radarr-hd-main")
        XCTAssertEqual(ConnectionCreate.slugify("Sonarr-Anime-4K"), "sonarr-anime-4k")
        XCTAssertTrue(ConnectionCreate.scopeApplies(kind: "series"))
        XCTAssertFalse(ConnectionCreate.scopeApplies(kind: "movie"))
        XCTAssertEqual(ConnectionCreate.animeSuggestion(tier: .uhd).slug, "sonarr-anime-4k")
        XCTAssertEqual(ConnectionCreate.animeSuggestion(tier: .hd).name, "Sonarr-Anime-HD")
        let body = ConnectionCreate.body(name: "M", slug: "m", flavor: "RADARR", kind: "movie", tier: .hd,
                                         scope: "anime", limits: ["allowed_root_folder_ids": .null])
        guard case .object(let fields) = body else { return XCTFail("object") }
        XCTAssertEqual(fields["scope"], .string("all"))
        XCTAssertEqual(fields["tier"], .string("HD-1080p"))
        XCTAssertEqual(fields["allowed_root_folder_ids"], .null)
    }
}
