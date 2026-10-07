import XCTest
@testable import FusionhaKit

/// Answers every request with a canned body and records what was sent.
final class ItemActionsStubProtocol: URLProtocol {
    static var responseBody = Data("{}".utf8)
    static var status = 200
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.read)
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n <= 0 { break }
            data.append(buffer, count: n)
        }
        return data
    }
}

/// The item actions rail: its order and gating (HeroActionRail.tsx), the
/// rename / edition-alias / numbering endpoints and their copy.
final class ItemActionsTests: XCTestCase {
    private func client(_ json: String, status: Int = 200) -> APIClient {
        ItemActionsStubProtocol.responseBody = Data(json.utf8)
        ItemActionsStubProtocol.status = status
        ItemActionsStubProtocol.lastRequest = nil
        ItemActionsStubProtocol.lastBody = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ItemActionsStubProtocol.self]
        return APIClient(baseURL: URL(string: "http://fh.test")!, token: "k", session: URLSession(configuration: config))
    }

    private var sent: URLRequest? { ItemActionsStubProtocol.lastRequest }

    private func sentJSON() throws -> [String: Any] {
        let body = try XCTUnwrap(ItemActionsStubProtocol.lastBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    // MARK: Rail

    func testRailOrderMatchesTheWeb() {
        XCTAssertEqual(ItemAction.rail(isSeries: false, canEdit: true, hasNonStandardEdition: false),
                       [.refresh, .previewRename, .manageFiles, .reportIssue, .edit, .delete])
        XCTAssertEqual(ItemAction.rail(isSeries: true, canEdit: true, hasNonStandardEdition: true),
                       [.refresh, .previewRename, .manageEpisodes, .reportIssue, .checkNumbering, .editionAliases, .edit, .delete])
    }

    func testReadOnlyKeepsReportAndTheNumberingCheck() {
        XCTAssertEqual(ItemAction.rail(isSeries: true, canEdit: false, hasNonStandardEdition: true),
                       [.reportIssue, .checkNumbering])
        XCTAssertEqual(ItemAction.rail(isSeries: false, canEdit: false, hasNonStandardEdition: true), [.reportIssue])
    }

    func testRailLabels() {
        XCTAssertEqual(ItemAction.delete.label(isSeries: true), "Delete series")
        XCTAssertEqual(ItemAction.delete.label(isSeries: false), "Delete movie")
        XCTAssertEqual(ItemAction.checkNumbering.label(isSeries: true), "Check episode numbering")
        XCTAssertEqual(ItemAction.checkNumbering.label(isSeries: true, numberingFlagged: true), "Review episode numbering")
        XCTAssertEqual(ItemAction.edit.label(isSeries: false), "Edit & monitoring")
    }

    // MARK: Rename

    func testRenamePreviewRequestAndDecode() async throws {
        let api = client("""
        [{"file_id": 4, "version_id": 2, "from": "a.mkv", "to": "b.mkv", "blocked": false, "reason": null},
         {"file_id": 5, "version_id": 2, "from": "c.mkv", "to": "b.mkv", "blocked": true,
          "reason": "duplicate_name", "blocked_by_file_id": 4, "blocked_by_path": "a.mkv"}]
        """)
        let rows = try await api.renamePreview(itemId: 7, versionId: 2, season: 3)
        let url = try XCTUnwrap(sent?.url)
        XCTAssertEqual(sent?.httpMethod, "GET")
        XCTAssertEqual(url.path, "/api/v1/library/7/rename")
        XCTAssertEqual(url.query, "version_id=2&season=3&include_blocked=1")
        let split = RenameCopy.split(rows)
        XCTAssertEqual(split.movable.map(\.fileId), [4])
        XCTAssertEqual(split.blocked.map(\.fileId), [5])
        XCTAssertEqual(RenameCopy.blockReason(split.blocked[0]),
                       "Another file on this title wants the same name (a.mkv). Delete or repoint the duplicate.")
    }

    func testRenamePreviewWholeTitleQuery() {
        XCTAssertEqual(APIClient.renamePreviewQuery(versionId: nil, season: nil).map(\.name), ["include_blocked"])
    }

    func testApplyRenameBodies() async throws {
        let api = client(#"{"applied": 2, "skipped": []}"#)
        let whole = try await api.applyRename(itemId: 7)
        XCTAssertEqual(sent?.httpMethod, "POST")
        XCTAssertEqual(sent?.url?.path, "/api/v1/library/7/rename")
        XCTAssertTrue(try sentJSON().isEmpty)
        XCTAssertEqual(RenameCopy.appliedToast(whole).message, "2 files renamed")

        _ = try await api.applyRename(itemId: 7, versionId: 3)
        XCTAssertEqual(try sentJSON() as? [String: Int], ["version_id": 3])
    }

    func testRenameCopy() throws {
        XCTAssertEqual(RenameCopy.scopeText(versionId: nil, season: nil), "the whole title")
        XCTAssertEqual(RenameCopy.scopeText(versionId: 3, season: nil), "this version")
        XCTAssertEqual(RenameCopy.scopeText(versionId: 3, season: 2), "Season 2")
        XCTAssertEqual(RenameCopy.applyLabel(count: 0), "Rename")
        XCTAssertEqual(RenameCopy.applyLabel(count: 1), "Rename 1 file")
        XCTAssertEqual(RenameCopy.blockedHeading(3), "3 files can't be renamed")
        let skipped = try JSONDecoder.snake.decode(RenameApplyResult.self, from: Data("""
        {"applied": 1, "skipped": [{"file_id": 9, "from": "x", "to": "y", "blocked": true, "reason": "source_missing"}]}
        """.utf8))
        let toast = RenameCopy.appliedToast(skipped)
        XCTAssertTrue(toast.isWarning)
        XCTAssertEqual(toast.message, "1 file renamed · 1 skipped (The file is missing from disk — rescan or replace it first.)")
    }

    // MARK: Edition aliases

    func testEditionAliasEndpoints() async throws {
        let api = client(#"[{"id": 3, "term": "Vrach Cut", "edition": "Director's Cut", "guarded": true}]"#)
        let aliases = try await api.editionAliases(itemId: 7)
        XCTAssertEqual(sent?.url?.path, "/api/v1/library/7/edition-aliases")
        XCTAssertEqual(aliases.first?.edition, "Director's Cut")
        XCTAssertEqual(aliases.first?.guarded, true)

        try await api.addEditionAlias(itemId: 7, EditionAliasCreate(term: "Vrach Cut", edition: "Director's Cut", guarded: false))
        XCTAssertEqual(sent?.httpMethod, "POST")
        let body = try sentJSON()
        XCTAssertEqual(body["term"] as? String, "Vrach Cut")
        XCTAssertEqual(body["edition"] as? String, "Director's Cut")
        XCTAssertEqual(body["guarded"] as? Bool, false)

        try await api.deleteEditionAlias(itemId: 7, aliasId: 3)
        XCTAssertEqual(sent?.httpMethod, "DELETE")
        XCTAssertEqual(sent?.url?.path, "/api/v1/library/7/edition-aliases/3")
    }

    // MARK: Numbering

    func testNumberingPreviewDecodesTheDiff() throws {
        let preview = try JSONDecoder.snake.decode(NumberingPreview.self, from: Data("""
        {"item_id": 7, "source": "tvdb", "diff_hash": "abc", "agrees": false, "active_queue_blocked": false,
         "rows": [{"season": 2, "kind": "renumbered", "current_number": 3, "alternate_number": 4, "current_title": "Third"},
                  {"season": 1, "kind": "unchanged", "current_number": 1, "alternate_number": 1},
                  {"season": 1, "kind": "added", "current_number": null, "alternate_number": 9, "alternate_title": "Nine"}],
         "renumbered": [], "added": [], "removed_phantoms": [],
         "relinked": [{"media_file_id": 1, "path": "/tv/a.mkv", "from_slots": [[2, 3]], "to_slots": [[2, 4]]}],
         "unparseable": [], "kept_phantoms": []}
        """.utf8))
        XCTAssertEqual(preview.diffHash, "abc")
        XCTAssertEqual(preview.relinked?.first?.path, "/tv/a.mkv")
        let rows = preview.rows ?? []
        XCTAssertTrue(NumberingCopy.hasChanges(rows))
        let grouped = NumberingCopy.notableBySeason(rows)
        XCTAssertEqual(grouped.map { $0.season }, [1, 2])
        XCTAssertEqual(grouped[0].rows.map(\.kind), ["added"])
        XCTAssertEqual(NumberingCopy.kindLabel("added"), "New")
        XCTAssertEqual(NumberingCopy.sourceLabel(preview.source ?? ""), "TVDB")
        XCTAssertEqual(NumberingCopy.matchesMessage(source: "tvmaze"), "Numbering matches TVmaze — no change needed")
        XCTAssertEqual(NumberingCopy.sourceGuess(provider: "hybrid"), "tvdb")
        XCTAssertEqual(NumberingCopy.sourceGuess(provider: nil), "tvmaze")
    }

    func testApplyNumberingBodyAndRunSummary() async throws {
        let api = client(#"{"run_id": 42}"#)
        let dispatch = try await api.applyNumbering(itemId: 7, source: "tvmaze", expectedHash: "abc")
        XCTAssertEqual(dispatch.runId, 42)
        XCTAssertEqual(sent?.url?.path, "/api/v1/library/7/numbering/apply")
        XCTAssertEqual(try sentJSON() as? [String: String], ["source": "tvmaze", "expected_hash": "abc"])

        let run = try JSONDecoder.snake.decode(CommandRun.self, from: Data("""
        {"id": 42, "status": "completed", "numbering_summary": {"source": "tvmaze",
         "renumbered": [{"season": 1, "from_number": 3, "to_number": 4, "title": "x"}],
         "added": [], "relinked": [{"media_file_id": 1, "path": "a"}, {"media_file_id": 2, "path": "b"}],
         "removed_phantoms": [], "unparseable": [{"media_file_id": 3, "path": "c", "reason": "no slot"}]}}
        """.utf8))
        let summary = NumberingCopy.summary(run.numberingSummary, itemTitle: "Lost")
        XCTAssertEqual(summary.title, "Episode numbering fixed — Lost")
        XCTAssertEqual(summary.message, "1 episode renumbered · 2 files re-linked · 1 file needs manual assignment.")
        XCTAssertEqual(summary.tone, .warning)
        XCTAssertEqual(NumberingCopy.summary(nil, itemTitle: "Lost").message, "Numbering pinned to TVmaze.")
    }
}

private extension JSONDecoder {
    static var snake: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}
