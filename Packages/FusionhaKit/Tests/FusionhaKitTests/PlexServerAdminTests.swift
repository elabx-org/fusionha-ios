import XCTest
@testable import FusionhaKit

final class PlexServerAdminTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    private func probe(_ uri: String, kind: String = "lan", ok: Bool = true, ms: Int? = 4, error: String? = nil) -> String {
        """
        {"uri": "\(uri)", "local": true, "relay": false, "label": "\(uri)", "kind": "\(kind)", "secure": true,
         "plex_direct": false, "reachable": \(ok), "latency_ms": \(ms.map(String.init) ?? "null"),
         "is_owner_server": \(ok), "error": \(error.map { "\"\($0)\"" } ?? "null")}
        """
    }

    private func library(_ extra: String) -> String {
        """
        {"section_key": "1", "title": "Films 4K", "type": "movie", "source": "server",
         "uhd_detected": "SUGGESTED", "effective_uhd": false, "gone": false,
         "lost_without_server_url": false\(extra)}
        """
    }

    // MARK: Decoding

    func testDecodesServerAndProbe() throws {
        let server = try decode(PlexServerInfo.self, """
        {"url": "http://10.0.0.9:32400", "verify_tls": true, "machine_id": "abc",
         "suggested_connections": [{"uri": "http://10.0.0.9:32400", "local": true, "relay": false,
           "label": "10.0.0.9", "kind": "lan", "secure": false, "plex_direct": false}],
         "ok": true, "message": "Connected", "libraries_lost_without_url": 2}
        """)
        XCTAssertEqual(server.suggestedConnections?.first?.kind, .lan)
        XCTAssertEqual(server.librariesLostWithoutUrl, 2)
        XCTAssertEqual(PlexConnectionLabels.kindLine(server.suggestedConnections![0]), "Your network · unencrypted")

        let p = try decode(PlexConnectionsProbe.self, """
        {"results": [\(probe("a")), \(probe("b", kind: "docker", ok: false, ms: nil, error: "timeout"))],
         "recommended_uri": "a", "tested": 2, "reachable": 1, "checked_at": "2026-10-16T10:00:00"}
        """)
        XCTAssertEqual(p.recommendedUri, "a")
        XCTAssertTrue(PlexConnectionLabels.isUsable(p.results[0]))
        XCTAssertFalse(PlexConnectionLabels.isUsable(p.results[1]))
        XCTAssertEqual(p.results[1].kind, .docker)
    }

    func testDecodesLibraryDetectionAndTierAccessDefaults() throws {
        let lib = try decode(PlexLibrary.self, library("""
        , "detection": {"method": "path", "matched_suffix": "movies-4k", "unique": true, "sampled": 3,
          "matched": 3, "plex_path": "/data/movies-4k", "root_path": "/movies-4k", "root_id": 4}
        """))
        XCTAssertEqual(lib.detection?.matchedSuffix, "movies-4k")
        XCTAssertEqual(PlexLibraryEvidence.state(lib), .suggested)
        XCTAssertEqual(PlexLibraryEvidence.evidenceText(lib), "Films 4K ↔ /movies-4k ✓ · matched 3 of 3 sampled titles")
        XCTAssertEqual(PlexLibraryEvidence.pathPair(lib)?.root, "/movies-4k")
        XCTAssertEqual(PlexLibraryEvidence.decisionText(lib), "Needs your decision: only 3 titles to sample, too few to be sure.")

        let row = try decode(UserTierAccess.self, #"{"user_id": 3, "uhd": false, "source": "default"}"#)
        XCTAssertTrue(row.uhdWhenActive)
        XCTAssertEqual(row.sourceWhenActive, "default")
        XCTAssertEqual(PlexWhoGets4K.bucket(row), .none)
    }

    // MARK: Connection labels

    func testProbeTailAndOtherGroups() throws {
        let p = try decode(PlexConnectionsProbe.self, """
        {"results": [\(probe("rec", ms: 2)), \(probe("slow", ms: 40)), \(probe("fast", ms: 5)),
                     \(probe("dead", ok: false, ms: nil, error: "wrong_server"))],
         "recommended_uri": "rec", "tested": 4, "reachable": 3, "checked_at": "x"}
        """)
        let res = Dictionary(uniqueKeysWithValues: p.results.map { ($0.uri, $0) })
        XCTAssertEqual(PlexConnectionLabels.probeTail(res["fast"]).text, "5 ms")
        XCTAssertEqual(PlexConnectionLabels.probeTail(res["dead"]).text, "not your server")
        XCTAssertEqual(PlexConnectionLabels.probeTail(nil, testing: true).text, "testing")

        let groups = PlexConnectionLabels.otherGroups(p.results.map(\.connection), res, recUri: "rec")
        XCTAssertEqual(groups.map(\.id), ["lan"])
        XCTAssertEqual(groups[0].list.map(\.uri), ["fast", "slow", "dead"])
        XCTAssertEqual(PlexConnectionLabels.groupSummary(groups[0].list, res), "2 reachable")
        XCTAssertEqual(PlexConnectionLabels.arrivalOrder(p.results).map(\.uri), ["rec", "fast", "slow", "dead"])
    }

    func testSavedSummary() {
        let conn = PlexConnection(uri: "http://10.0.0.9:32400", label: "10.0.0.9", kind: .lan)
        XCTAssertEqual(PlexConnectionLabels.savedSummary("http://10.0.0.9:32400", [conn], [:]).meta, "your network")
        let manual = PlexConnectionLabels.savedSummary("https://plex.example.com:32400", [conn], [:])
        XCTAssertEqual(manual.host, "plex.example.com:32400")
        XCTAssertEqual(manual.meta, "entered manually")
    }

    // MARK: Libraries

    func testLibrarySummaryAndOverrideCopy() throws {
        let suggested = try decode(PlexLibrary.self, library(""))
        let uhd = try decode(PlexLibrary.self, """
        {"section_key": "2", "title": "UHD", "type": "show", "source": "server", "uhd_detected": "MATCHED",
         "uhd_override": "ON", "effective_uhd": true, "gone": false, "lost_without_server_url": true}
        """)
        XCTAssertEqual(PlexLibraryEvidence.summary([suggested, uhd, uhd]).map(\.label), ["2 count as 4K", "1 need a decision"])
        XCTAssertEqual(PlexLibraryEvidence.typeLabel(uhd.type), "TV")
        XCTAssertEqual(PlexLibraryEvidence.evidenceText(suggested), "No 4K root folder matches this library")
        XCTAssertEqual(PlexLibraryEvidence.overrideToast("UHD", nil), "UHD back to detection")
        XCTAssertEqual(PlexLibraryEvidence.shortMachineId("3f9c2a1e00000000b7d4"), "3f9c2a1e…b7d4")
    }

    // MARK: Sync + warnings

    func testShortAgoAndSyncSummary() {
        let now = ServerTime.parse("2026-10-16T12:00:00")!
        XCTAssertEqual(PlexSyncStatus.shortAgo("2026-10-16T11:59:30", now: now), "just now")
        XCTAssertEqual(PlexSyncStatus.shortAgo("2026-10-16T11:58:00", now: now), "2 min ago")
        XCTAssertEqual(PlexSyncStatus.shortAgo("2026-10-16T09:00:00", now: now), "3 h ago")
        XCTAssertEqual(PlexSyncStatus.shortAgo("2026-10-13T12:00:00", now: now), "3 d ago")
        XCTAssertTrue(PlexSyncStatus.summary(lastSyncedAt: nil, hours: 24, now: now).never)
        XCTAssertTrue(PlexSyncStatus.summary(lastSyncedAt: "2026-10-13T12:00:00", hours: 24, now: now).overdue)
        XCTAssertFalse(PlexSyncStatus.summary(lastSyncedAt: "2026-10-16T09:00:00", hours: 24, now: now).overdue)
    }

    func testWarningNotesOrderAndCopy() {
        let notes = PlexSyncStatus.warningNotes([
            PlexAccessWarning(code: "access_not_synced", message: "Not synced"),
            PlexAccessWarning(code: "PlexAccessSyncCheck", message: "Sync failing", attempts: 1),
            PlexAccessWarning(code: "PlexAccessNoUhdLibraryCheck", message: "No 4K library"),
        ], lastSync: "")
        XCTAssertEqual(notes.map(\.code), ["PlexAccessNoUhdLibraryCheck", "PlexAccessSyncCheck", "access_not_synced"])
        XCTAssertTrue(notes[1].sub.contains("(1 attempt)"))
        XCTAssertTrue(notes[2].neutral)
        XCTAssertTrue(PlexSyncStatus.backingOff([PlexAccessWarning(code: "PlexAccessSyncCheck", message: "")]))
    }

    func testAckBlockFromPreview() throws {
        func preview(synced: Bool, libs: String) throws -> PlexAccessPreview {
            try decode(PlexAccessPreview.self, """
            {"gain": [{"user_id": 1, "display_name": "Ann"}], "lose": [], "unchanged": 4, "active": false,
             "derive_enabled": true, "uhd_libraries": \(libs), "synced": \(synced), "warnings": []}
            """)
        }
        XCTAssertEqual(PlexSyncStatus.ackBlock(try preview(synced: false, libs: #"["Films"]"#)), .sync)
        XCTAssertEqual(PlexSyncStatus.ackBlock(try preview(synced: true, libs: "[]")), .noLibrary)
        XCTAssertNil(PlexSyncStatus.ackBlock(try preview(synced: true, libs: #"["Films"]"#)))
    }

    // MARK: Who gets UHD·4K

    func testWhoGets4KBuckets() throws {
        let rows = try decode([UserTierAccess].self, """
        [{"user_id": 1, "uhd": true, "source": "plex", "source_when_active": "plex", "is_owner": true},
         {"user_id": 2, "uhd": true, "source": "plex", "source_when_active": "plex", "uhd_when_active": false},
         {"user_id": 3, "uhd": true, "source": "user", "source_when_active": "user"},
         {"user_id": 4, "uhd": true, "source": "plex", "source_when_active": "plex", "uhd_when_active": true}]
        """)
        let buckets = PlexWhoGets4K.group(rows, names: [1: "Owner", 2: "Bob"], synced: false)
        XCTAssertEqual(buckets.map(\.id), [.owner, .friend4k, .hdonly, .manual])
        XCTAssertEqual(buckets[2].people.first?.name, "Bob")
        XCTAssertEqual(buckets[2].sub, "Not fetched from Plex yet: counted as HD")
        XCTAssertEqual(buckets[3].people.first?.name, "Unknown user")
    }
}
