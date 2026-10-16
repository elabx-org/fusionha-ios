import XCTest
@testable import FusionhaKit

final class QualityProfileAdminTests: XCTestCase {
    private func profile(_ json: String) throws -> QualityProfileRecord {
        try APIClient.decoder.decode(QualityProfileRecord.self, from: Data(json.utf8))
    }

    private let grouped = #"""
        {"id":7,"name":"WEB-2160p","media_kind":"movie","cutoff":"WEBRIP_2160P","cutoff_group":"WEB","cutoff_group_index":2,
         "upgrade_until":"WEBRIP_2160P","upgrade_allowed":true,"min_format_score":0,"cutoff_format_score":null,
         "min_upgrade_format_score":1,"language":"original","allowed_qualities":["WEBDL_1080P","WEBRIP_1080P","WEBDL_2160P","WEBRIP_2160P"],
         "items":[{"type":"group","name":"WEB","allowed":true,"order":0,"qualities":["WEBDL_1080P","WEBRIP_1080P"]},
                  {"type":"quality","quality":"BLURAY_1080P","allowed":false,"order":1},
                  {"type":"group","name":"WEB","allowed":true,"order":2,"qualities":["WEBDL_2160P","WEBRIP_2160P"]}],
         "format_scores":[{"custom_format_id":3,"score":1500,"is_override":false},{"custom_format_id":9,"score":0,"is_override":true}],
         "source":"trash","in_use":4,"default_for":[{"profile_kind":"movie","tier":"UHD-2160p"}]}
        """#

    func testDecodesGroupedItemsAndDefaults() throws {
        let p = try profile(grouped)
        XCTAssertEqual(p.items?.count, 3)
        XCTAssertEqual(p.items?.first?.order, 0)
        XCTAssertEqual(p.defaultFor?.first.map(QualityProfileKinds.defaultBadge), "Default · Movies · 4K")
        XCTAssertEqual(p.inUse, 4)
    }

    func testSeedPicksTheNamesakeByIndexAndKeepsTheStoredMember() throws {
        let model = QualityLadder.seed(try profile(grouped))
        // Best-first: the 2160p WEB group is on top.
        XCTAssertEqual(model.rows.first?.group?.qualities, ["WEBDL_2160P", "WEBRIP_2160P"])
        let resolved = QualityLadder.resolveCutoff(model.rows, model.cutoff)
        XCTAssertEqual(resolved.cutoff, "WEBRIP_2160P")
        XCTAssertEqual(resolved.cutoffGroup, "WEB")
        XCTAssertEqual(resolved.cutoffGroupIndex, 0)
        // Every real tier appears exactly once.
        XCTAssertEqual(QualityLadder.flatAllowed(model.rows).count, 4)
        let all = model.rows.flatMap { r -> [String] in
            if case .quality(let q) = r { return [q.quality] }
            return r.group?.qualities ?? []
        }
        XCTAssertEqual(Set(all), Set(QualityLadder.order))
    }

    func testAllowedPayloadIsWorstFirstAndItemsTopIsHighest() {
        let model = QualityLadder.defaultModel()
        let wire = QualityLadder.allowedPayload(model.rows)
        XCTAssertEqual(wire.last, "BLURAY_1080P")
        XCTAssertEqual(wire.first, "HDTV_720P")
        let items = QualityLadder.items(model.rows)
        guard case .object(let top) = items[0] else { return XCTFail("object") }
        XCTAssertEqual(top["order"], .int(items.count - 1))
        XCTAssertEqual(QualityLadder.cutoffLabel(model), "Bluray-1080p")
    }

    func testAssignToNewGroupThenDissolve() {
        let rows = QualityLadder.defaultModel().rows
        let result = QualityLadder.assign(rows, "BLURAY_1080P", to: .new)
        let g = QualityLadder.groupOf(result.rows, "BLURAY_1080P")
        XCTAssertEqual(g?.id, result.groupID)
        XCTAssertEqual(g?.name, "Quality Group 5")
        XCTAssertEqual(g?.allowed, true)
        let back = QualityLadder.dissolve(result.rows, id: result.groupID ?? "")
        XCTAssertNil(QualityLadder.groupOf(back, "BLURAY_1080P"))
        XCTAssertEqual(back.count, rows.count)
    }

    func testRepairedCutoffSnapsToBestAllowed() {
        var model = QualityLadder.defaultModel()
        model.rows = QualityLadder.setAllowed(model.rows, rowID: "q:BLURAY_1080P", false)
        let fixed = QualityLadder.repairedCutoff(model)
        guard case .group(let id, _) = fixed else { return XCTFail("expected the WEB 1080p group") }
        XCTAssertEqual(model.rows.first { $0.group?.id == id }?.group?.name, "WEB 1080p")
    }

    func testUntouchedUpdateOmitsTheLadder() throws {
        let p = try profile(grouped)
        let fields = QualityProfileBody.common(QualityProfileFields(p), formatScores: [])
        let body = QualityProfileBody.save(fields: fields, model: QualityLadder.seed(p), original: p)
        XCTAssertNil(body["items"])
        XCTAssertNil(body["cutoff"])
        var moved = QualityLadder.seed(p)
        moved.rows = QualityLadder.moveRow(moved.rows, at: 0, by: 1)
        XCTAssertNotNil(QualityProfileBody.save(fields: fields, model: moved, original: p)["items"])
    }

    func testFormatScoreOverrideFlags() throws {
        let p = try profile(grouped)
        let base = QualityProfileBody.baseline(p)
        let scores: [Int: String] = [3: "1500", 9: "0", 12: "-50"]
        let out = QualityProfileBody.formatScores(scores: scores, formatIDs: [3, 9, 12, 20], baseline: base, released: [])
        let expected: [SettingsJSON] = [
            ["custom_format_id": 3, "score": 1500, "is_override": false],
            ["custom_format_id": 9, "score": 0, "is_override": true],
            ["custom_format_id": 12, "score": -50, "is_override": true],
        ]
        XCTAssertEqual(out, expected)
        let released = QualityProfileBody.formatScores(scores: scores, formatIDs: [], baseline: base, released: [9])
        XCTAssertEqual(released.count, 2)
        XCTAssertEqual(QualityProfileBody.scoredCount(scores: scores, formatIDs: [20]), 2)
        XCTAssertEqual(QualityProfileBody.step(1500), 75)
        XCTAssertEqual(QualityProfileBody.step(0), 1)
    }

    func testCommonFieldsBlankCeilingIsNull() {
        let f = QualityProfileFields(name: " HD ", mediaKind: "series", upgradeAllowed: false, minScore: "abc",
                                     cutoffFormatScore: " ", minIncrement: "2", language: "Japanese")
        let body = QualityProfileBody.common(f, formatScores: [])
        XCTAssertEqual(body["name"], "HD")
        XCTAssertEqual(body["cutoff_format_score"], .null)
        XCTAssertEqual(body["min_format_score"], 0)
        XCTAssertEqual(body["min_upgrade_format_score"], 2)
    }

    func testDuplicateClonesWithCopySuffix() throws {
        let body = QualityProfileBody.duplicate(try profile(grouped))
        XCTAssertEqual(body["name"], "WEB-2160p (copy)")
        XCTAssertEqual(body["cutoff"], "WEBRIP_2160P")
        XCTAssertEqual(body["cutoff_group_index"], 0)
    }

    func testCardRungs() {
        let rungs = QualityProfileRungs.derive(allowed: ["WEBDL_1080P", "HDTV_720P"], cutoff: "WEBDL_1080P")
        XCTAssertEqual(rungs.map(\.allowed), [false, true, true, false])
        XCTAssertEqual(rungs.map(\.isCutoff), [false, false, true, false])
    }

    func testSizeLimits() throws {
        let defs = try APIClient.decoder.decode([QualityDefinitionRecord].self, from: Data(#"""
            [{"id":1,"quality":"SDTV","title":"SDTV","min_size":0,"max_size":100,"preferred_size":95},
             {"id":2,"quality":"REMUX_2160P","title":"Remux","media_kind":null,"min_size":35,"max_size":0,"preferred_size":95}]
            """#.utf8))
        let groups = QualitySizeLimits.grouped(defs)
        XCTAssertEqual(groups.map(\.name), ["2160p", "SD / other"])
        let remux = QualitySizeRange(groups[0].rows[0])
        XCTAssertTrue(remux.unlimited)
        XCTAssertEqual(QualitySizeLimits.constrain(remux, .max, 279).max, 0)
        XCTAssertEqual(QualitySizeLimits.constrain(QualitySizeRange(min: 0, pref: 95, max: 100), .max, 50).max, 95)
        XCTAssertEqual(QualitySizeLimits.typedMin(QualitySizeRange(min: 0, pref: 95, max: 100), 120).min, 95)
        XCTAssertEqual(QualitySizeLimits.typedMax(QualitySizeRange(min: 0, pref: 95, max: 100), nil).max, 0)
        XCTAssertEqual(QualitySizeLimits.fileSizeLine(remux, runtime: 120), "4.10 GB – unlimited")
        XCTAssertEqual(QualitySizeLimits.formatGB(0.5), "512 MB")
    }
}
