import XCTest
@testable import FusionhaKit

final class CustomFormatAdminTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func value(_ json: String) throws -> JSONValue {
        JSONValue(any: try JSONSerialization.jsonObject(with: Data(json.utf8)))
    }

    func testFormatDecodesWithSpecDefaults() throws {
        let f = try decode(CustomFormatInfo.self, """
        {"id": 3, "name": "x265", "source": "trash", "media_kind": "movie", "include_when_renaming": true,
         "specifications": [{"spec_type": "release_title", "value": "x265"},
                            {"spec_type": "source", "value": "BLURAY", "negate": true, "required": false}]}
        """)
        XCTAssertEqual(f.provenance, "trash")
        XCTAssertEqual(f.specifications[0].required, true)
        XCTAssertEqual(f.specifications[0].negate, false)
        XCTAssertEqual(f.specifications[1].negate, true)
        XCTAssertEqual(f.specifications[1].required, false)
        let legacy = try decode(CustomFormatInfo.self, #"{"id": 4, "name": "Old", "specifications": []}"#)
        XCTAssertEqual(legacy.provenance, "manual")
        XCTAssertNil(CFLibrary.kindTag(legacy.mediaKind))
    }

    func testBlocksGroupByTypeAndInsertAfterBlock() {
        let specs = [
            CustomFormatSpec(specType: "release_title", value: "a"),
            CustomFormatSpec(specType: "source", value: "WEBDL"),
            CustomFormatSpec(specType: "release_title", value: "b"),
        ]
        let blocks = CFBlocks.group(specs)
        XCTAssertEqual(blocks.map(\.type), ["release_title", "source"])
        XCTAssertEqual(blocks[0].indices, [0, 2])
        let next = CFBlocks.addToBlock(specs, blocks[1])
        XCTAssertEqual(next.count, 4)
        XCTAssertEqual(next[2].specType, "source")
        XCTAssertEqual(next[2].value, "BLURAY")
        XCTAssertFalse(next[2].required)
    }

    func testVocabDefaults() {
        XCTAssertNil(CFSpecVocab.options(for: "release_title"))
        XCTAssertEqual(CFSpecVocab.defaultValue("release_group"), "")
        XCTAssertEqual(CFSpecVocab.defaultValue("resolution"), "2160")
        XCTAssertEqual(CFSpecVocab.valueLabel("indexer_flag", "doubleUpload"), "Double Upload")
        XCTAssertEqual(CFSpecVocab.label("quality_modifier"), "Quality Modifier")
        XCTAssertEqual(CFSpecVocab.types.count, 8)
    }

    func testLibraryFiltersChipsAndUsage() throws {
        let formats = try decode([CustomFormatInfo].self, """
        [{"id": 1, "name": "Remux", "source": "trash", "media_kind": "movie", "specifications": []},
         {"id": 2, "name": "Anime BD", "source": "arr", "media_kind": "anime", "specifications": []},
         {"id": 3, "name": "Mine", "specifications": []}]
        """)
        XCTAssertEqual(CFLibrary.chips(formats), ["all", "trash", "arr", "manual"])
        XCTAssertEqual(CFLibrary.filter(formats, query: "re", chip: "all", kind: "all").map(\.id), [1])
        XCTAssertEqual(CFLibrary.filter(formats, query: "", chip: "manual", kind: "all").map(\.id), [3])
        XCTAssertEqual(CFLibrary.filter(formats, query: "", chip: "all", kind: "anime").map(\.id), [2])
        let profiles = try decode([ProfileScoringSummary].self, """
        [{"id": 1, "name": "HD", "format_scores": [{"custom_format_id": 1, "score": 100}, {"custom_format_id": 2, "score": 0}]},
         {"id": 2, "name": "4K", "format_scores": [{"custom_format_id": 1, "score": -5}]}]
        """)
        XCTAssertEqual(CFLibrary.usedIn(profiles, formatId: 1), 2)
        XCTAssertEqual(CFLibrary.usedIn(profiles, formatId: 2), 0)
        XCTAssertEqual(CFLibrary.score(-10), "−10")
        XCTAssertEqual(CFLibrary.score(5), "+5")
    }

    func testTesterResultAndBulkCopy() throws {
        let r = try decode(CFTestResponse.self, """
        {"results": [{"title": "A.1080p.WEB-DL", "total": 15, "action": "upgrade", "accepted": true, "reason": "", "best": true,
          "parsed": {"quality": "WEBDL_1080P", "resolution": 1080, "source": "WEBDL", "release_group": "NTb",
                     "edition": null, "languages": ["English"]},
          "matched": [{"name": "WEB", "score": 20}, {"name": "x265", "score": -5}]}]}
        """).results[0]
        XCTAssertEqual(r.verdictLabel, "Upgrade")
        XCTAssertEqual(r.matchedTotal, 15)
        XCTAssertEqual(r.parsed.chips, ["WEBDL-1080p", "1080p", "WEBDL", "NTb", "English"])
        let bulk = try decode(CustomFormatBulkResult.self, #"{"affected": 2, "errors": [{"id": 9, "detail": "in use"}]}"#)
        XCTAssertEqual(bulk.message, "Deleted 2 custom formats · 1 in use, not deleted")
    }

    func testTrashTextAndPrefs() throws {
        XCTAssertEqual(TrashText.plain("Line one<br>line <b>two</b>  "), "Line one line two")
        XCTAssertEqual(TrashText.intervalOptions(current: 86_400).count, 5)
        XCTAssertEqual(TrashText.intervalOptions(current: 7_200).first?.label, "every 7200s")
        let conflict = try decode(TrashConflict.self, """
        {"trash_id": "t", "cf_id": 1, "name": "IMAX", "media_kind": "movie",
         "guide_specs": [{"spec_type": "source", "value": "BLURAY", "negate": true}], "local_specs": []}
        """)
        XCTAssertEqual(TrashText.specs(conflict.guideSpecs), "!source=BLURAY")
        XCTAssertEqual(TrashText.specs(conflict.localSpecs), "(none)")
        let prefs = try decode(TrashAnimePreferences.self, #"{"prefer_dubs": true}"#)
        XCTAssertTrue(prefs.value("prefer_dubs"))
        XCTAssertTrue(prefs.setting("avoid_raws", true).avoidRaws)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertEqual(TrashText.synced(ISO8601DateFormatter().string(from: now.addingTimeInterval(-300)), now: now), "5m ago")
    }

    private let presetJSON = """
    {"id": 7, "name": "HD Bluray", "media_kind": "movie", "deploy_name": "HD Bluray-Movie", "captured_at": "2026-01-01",
     "manifest": {"allowed_qualities": ["WEBRIP_1080P", "WEBDL_1080P", "BLURAY_1080P"], "cutoff": "BLURAY_1080P",
       "upgrade": {"allowed": true, "cutoff_format_score": 10000},
       "format_scores": {"abc_def": 1750, "Mine": -100, "zzz": 5},
       "format_specs": {"zzz": []},
       "quality_groups": [{"name": "WEB 1080p", "qualities": ["WEBRIP_1080P", "WEBDL_1080P"]}]}}
    """

    func testPresetKeepsKeysAndPlansDeploy() throws {
        let preset = try XCTUnwrap(PresetInfo(json: try value(presetJSON)))
        XCTAssertEqual(preset.tierLabel, "HD")
        XCTAssertEqual(preset.manifest.upgradeSummary, "on · CF ≤10000")
        XCTAssertEqual(preset.manifest.formatScores["abc_def"], 1750)
        XCTAssertEqual(preset.manifest.topScores.first?.key, "abc_def")
        let catalog = try decode([TrashCatalogEntry].self, #"[{"trash_id": "abc_def", "name": "BR-DISK", "added": true}]"#)
        let formats = try decode([CustomFormatInfo].self, #"[{"id": 1, "name": "Mine", "media_kind": "movie", "specifications": []}]"#)
        let rows = PresetDeployPlan.rows(preset, catalog: catalog, formats: formats)
        XCTAssertEqual(rows.map(\.name), ["BR-DISK", "zzz", "Mine"])
        XCTAssertEqual(rows.map(\.status), ["exists", "unresolved", "exists"])
        let counts = PresetDeployPlan.counts(rows, mode: .perRow, perRow: ["Mine": "skip"])
        XCTAssertEqual(counts.overwrite, 1)
        XCTAssertEqual(counts.skip, 1)
        XCTAssertEqual(counts.unresolved, 1)
        let body = PresetDeployPlan.body(name: " ", rows: rows, mode: .perRow, perRow: ["Mine": "skip"],
                                         replace: false, allowUnresolved: true)
        XCTAssertEqual(body, .object(["name": .null, "conflict": "skip",
                                      "per_format": .object(["abc_def": "overwrite", "Mine": "skip"]),
                                      "replace": false, "allow_unresolved": false]))
    }

    func testLadderGroupsShareRankAndOwnCutoff() throws {
        let preset = try XCTUnwrap(PresetInfo(json: try value(presetJSON)))
        let ladder = PresetLadder.preview(preset.manifest)
        XCTAssertEqual(ladder.rows, [.quality("BLURAY_1080P"),
                                     .group(index: 0, name: "WEB 1080p", qualities: ["WEBDL_1080P", "WEBRIP_1080P"])])
        XCTAssertNil(ladder.cutoffGroupIndex)
        XCTAssertEqual(ladder.qualityCount, 3)

        let grouped = PresetManifest(json: try value("""
        {"allowed_qualities": ["WEBRIP_1080P", "HDTV_1080P", "WEBDL_1080P"], "cutoff": "WEBDL_1080P",
         "quality_groups": [{"name": "Split", "qualities": ["WEBRIP_1080P", "WEBDL_1080P"]},
                            {"name": "Top", "allowed": true, "qualities": ["HDTV_1080P"]}],
         "cutoff_group": "Top"}
        """))
        let split = PresetLadder.preview(grouped)
        // "Split" is not contiguous, so it is refused; "Top" does not own the cutoff.
        XCTAssertEqual(split.groupCount, 1)
        XCTAssertNil(split.cutoffGroupIndex)
    }

    func testImportSummaries() throws {
        let section = try decode(CfImportSection.self, """
        {"media_kind": "series", "custom_formats": {"created": 3, "updated": 1}, "profiles": 2, "format_scores": 40}
        """)
        XCTAssertEqual(section.summary, "Series — 3 created · 1 updated · 0 skipped custom formats · 2 profiles · 40 format scores")
        let preset = try decode(BundledPresetSummary.self, """
        {"name": "Capture", "filename": "c.json", "sections": {"series": {"custom_formats": 4, "profiles": 1}}}
        """)
        XCTAssertEqual(preset.chips, ["Series: 4 CFs · 1 profiles"])
    }
}
