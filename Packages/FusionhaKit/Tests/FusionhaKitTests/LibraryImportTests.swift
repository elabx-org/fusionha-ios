import XCTest
@testable import FusionhaKit

final class LibraryImportTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func item(_ key: String, tmdb: Int? = 1, confidence: String = "high", kind: String = "movie",
                      isNew: Bool = false, owned: Bool = false, anime: Bool = false) -> String {
        """
        {"group_id": 0, "tmdb_id": \(tmdb.map(String.init) ?? "null"), "title": "Title \(key)", "year": 2001,
         "kind": "\(kind)", "confidence": "\(confidence)", "matched_by": "title", "monitored": true,
         "versions": [{"tier": "HD-1080p", "root_folder_id": 1, "folder": "Title (2001)", "files": [],
                       "edition": null, "movie_edition": null, "already_imported": false}],
         "editions": [], "already_imported": \(owned), "scan_id": 5, "folder_key": "\(key)",
         "accepted": false, "quality_profile_id": null, "override_tmdb_id": null, "variant": null,
         "is_new": \(isNew), "changed_since_reviewed": false, "is_anime": \(anime)}
        """
    }

    private func session(items: [String], status: String = "draft", sources: String = "[]") -> String {
        """
        {"id": 9, "status": "\(status)", "created_at": "2026-10-01T10:00:00", "updated_at": "2026-10-01T10:05:00",
         "sources": \(sources), "items": [\(items.joined(separator: ","))],
         "preview": {"titles": 2, "files": 1240, "per_tier": {"HD-1080p": 3, "UHD-2160p": 0}},
         "commit_result": null, "commit_total": null, "commit_done": null, "commit_phase": null,
         "commit_stalled": false, "enrichment": null}
        """
    }

    func testDecodesSessionAndPreview() throws {
        let s = try decode(LibraryImportSession.self, session(items: [item("a")]))
        XCTAssertTrue(s.isDraft)
        XCTAssertEqual(s.items?.first?.id, "5:a")
        XCTAssertEqual(s.items?.first?.versions?.first?.tier, .hd)
        XCTAssertEqual(LibraryImportRules.previewLine(s.preview), "2 titles · 1,240 files — adopt in place")
        XCTAssertEqual(LibraryImportRules.previewTiers(s.preview), [LibraryImportTierCount(tier: .hd, files: 3)])
    }

    func testToneAndPartition() throws {
        let rows = try [
            item("hi"), item("lo", confidence: "low"), item("none", tmdb: nil, confidence: "none"),
            item("num", confidence: "92"), item("new", isNew: true),
            item("owned", confidence: "low", owned: true),
        ].map { try decode(LibraryImportItem.self, $0) }
        XCTAssertEqual(rows.map(LibraryImportRules.tone), [.hi, .lo, .no, .hi, .hi, .lo])
        let triage = LibraryImportRules.partition(rows)
        XCTAssertEqual(triage.needsYou.map(\.folderKey), ["lo", "none", "new"])
        XCTAssertEqual(triage.ready.map(\.folderKey), ["hi", "num", "owned"])
    }

    func testInferRootAndSplitPath() {
        XCTAssertEqual(LibraryImportRules.inferTier("/data/movies-4k"), .uhd)
        XCTAssertEqual(LibraryImportRules.inferTier("/data/movies"), .hd)
        XCTAssertEqual(LibraryImportRules.inferKind("/data/anime"), .series)
        XCTAssertEqual(LibraryImportRules.inferKind("/data/movies"), .movie)
        let split = LibraryImportRules.splitPath("/data/movies-4k")
        XCTAssertEqual(split.head, "/data/")
        XCTAssertEqual(split.leaf, "movies-4k")
    }

    func testProfilesAndAcceptPatch() throws {
        let profiles = try decode([QualityProfile].self, """
        [{"id": 1, "name": "Any", "media_kind": null}, {"id": 2, "name": "Series HD", "media_kind": "series"},
         {"id": 3, "name": "Movie HD", "media_kind": "movie"}, {"id": 4, "name": "Anime", "media_kind": "anime"}]
        """)
        let movie = try decode(LibraryImportItem.self, item("m"))
        XCTAssertEqual(LibraryImportRules.profiles(profiles, for: movie).map(\.id), [1, 3])
        XCTAssertEqual(LibraryImportRules.profiles(profiles, kind: .series, isAnime: true).map(\.id), [1, 2, 4])
        let patch = LibraryImportRules.acceptPatch(movie, accepted: true, profiles: profiles)
        XCTAssertEqual(patch.qualityProfileId, 1)
        XCTAssertEqual(patch.body, ["scan_id": 5, "folder_key": "m", "accepted": true, "quality_profile_id": 1])
        let anime = try decode(LibraryImportItem.self, item("s", kind: "series", anime: true))
        let targets = LibraryImportRules.bulkTargets([movie, anime], kind: .series, profileId: 4, profiles: profiles)
        XCTAssertEqual(targets.map(\.folderKey), ["s"])
    }

    func testApplyingPatchesClearsAttention() throws {
        let s = try decode(LibraryImportSession.self, session(items: [item("a", isNew: true), item("b")]))
        var first = LibraryImportPatch(scanId: 5, folderKey: "a", accepted: true)
        first = first.merged(with: LibraryImportPatch(scanId: 5, folderKey: "a", monitored: false))
        let next = LibraryImportRules.applying([first], to: s)
        XCTAssertEqual(next.items?[0].accepted, true)
        XCTAssertEqual(next.items?[0].monitored, false)
        XCTAssertEqual(next.items?[0].isNew, false)
        XCTAssertEqual(next.items?[1].accepted, false)
    }

    func testPollingRules() throws {
        let scanning = #"[{"scan_id": 5, "path": "/movies", "status": "scanning", "items": 0, "files": 0, "stalled": false}]"#
        XCTAssertTrue(LibraryImportRules.needsPolling(try decode(LibraryImportSession.self, session(items: [], sources: scanning))))
        let stalled = scanning.replacingOccurrences(of: #""stalled": false"#, with: #""stalled": true"#)
        XCTAssertFalse(LibraryImportRules.needsPolling(try decode(LibraryImportSession.self, session(items: [], sources: stalled))))
        XCTAssertTrue(LibraryImportRules.needsPolling(try decode(LibraryImportSession.self, session(items: [], status: "committing"))))
    }

    func testSourceLine() throws {
        let src = try decode(LibraryImportSource.self, """
        {"scan_id": 1, "status": "scanning", "scan_total": 40, "scan_done": 10, "scan_phase": "filescan"}
        """)
        XCTAssertEqual(LibraryImportRules.sourceLine(src), "10 of 40 · scanning files")
        XCTAssertEqual(LibraryImportRules.sourceProgress(src), 0.25)
        XCTAssertFalse(LibraryImportRules.canRescan(src))
        let done = try decode(LibraryImportSource.self, #"{"scan_id": 1, "status": "ready", "items": 1, "files": 3}"#)
        XCTAssertEqual(LibraryImportRules.sourceLine(done), "1 title · 3 files")
    }

    func testTaskViewAndReport() throws {
        let summary = try decode(LibraryImportSummary.self, """
        {"id": 3, "status": "committed", "sources": 1, "roots": ["/movies"], "matched": 1, "needs_you": 0,
         "ready": 1, "files": 2, "titles": 1,
         "enrichment": {"control": "active", "state": "analyzing", "total": 1240, "enriched": 240, "pending": 1000,
                        "issue": 1, "issues": [{"media_file_id": 8, "title": "X", "reason": "probe_failed", "path": "x.mkv"}]}}
        """)
        let view = LibraryImportTaskView(summary.enrichment!)
        XCTAssertEqual(view.progressLabel, "Analyzing 240 of 1,240 files")
        XCTAssertEqual(view.percent, 19)
        XCTAssertTrue(view.canPause)
        XCTAssertFalse(view.canResume)
        XCTAssertEqual(LibraryImportTaskView.reasonLabel("probe_failed"), "Could not read media info")
        XCTAssertEqual(LibraryImportRules.rootLabel(summary), "/movies")

        let result = try decode(LibraryImportCommitResult.self, """
        {"items": [{"item_id": 10, "tmdb_id": 1, "created": true, "versions": [
                       {"version_id": 1, "edition_id": 1, "tier": "HD-1080p", "created": true, "files_created": 2}]},
                   {"item_id": 11, "tmdb_id": 2, "created": false, "versions": [
                       {"version_id": 2, "tier": "UHD-2160p", "created": false, "files_created": 0}]}],
         "skipped": []}
        """)
        let items = try [decode(LibraryImportItem.self, item("a"))]
        let report = LibraryImportReport(result: result, items: items)
        XCTAssertEqual(report.added.map(\.title), ["Title a"])
        XCTAssertEqual(report.added.first?.files, 2)
        XCTAssertEqual(report.updated, 1)
        XCTAssertEqual(report.skipped, 1)
        XCTAssertEqual(report.filesAdopted, 2)
    }
}
