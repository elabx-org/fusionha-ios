import XCTest
@testable import FusionhaKit

final class ApproverLogicTests: XCTestCase {
    private func request(id: Int = 1, status: String = "pending", _ json: String) -> MediaRequest {
        let base = #"{"tmdb_id":10,"kind":"series","tier":"HD-1080p","id":"# + "\(id),\"status\":\"\(status)\""
        let body = json.isEmpty ? "" : "," + json
        return try! APIClient.decoder.decode(MediaRequest.self, from: Data((base + body + "}").utf8))
    }

    // MARK: Triage

    func testDecodesTriage() throws {
        let json = #"[{"request_id":5,"track_record":{"requests_30d":3,"approved_30d":3,"declined_30d":0,"trusted":true},"demand":{"count":2,"people":[]},"versions":[{"tier":"HD-1080p","configured":true,"root_path":"/tv","profile_name":"HD","estimate_bytes":4294967296}],"disks":[{"root_paths":["/tv"],"total_bytes":1099511627776,"free_bytes":549755813888,"needed_bytes":4294967296,"free_after_bytes":545460846592}],"low_space":false,"four_k":{"state":"unseen"},"release":{"state":"out","label":"Out now"}}]"#
        let rows = try APIClient.decoder.decode([RequestTriage].self, from: Data(json.utf8))
        let t = try XCTUnwrap(rows.first)
        XCTAssertEqual(t.trackRecord.requests30d, 3)
        XCTAssertTrue(t.trackRecord.trusted)
        XCTAssertEqual(TriageFacts.size(t).value, "~4 GB")
        XCTAssertEqual(TriageFacts.freeAfter(t).value, "508 GB")
        XCTAssertEqual(TriageFacts.freeAfter(t).of, "of 1 TB")
        XCTAssertEqual(TriageFacts.fourK(t).tile.value, "Not yet")
        XCTAssertTrue(TriageFacts.fourK(t).checkable)
        XCTAssertEqual(TriageFacts.release(t).short, "Out now")
        XCTAssertEqual(TriageFacts.demandText(t, ownerName: "Sam Smith"), "2 people want this")
        XCTAssertEqual(TriageFacts.trackLine(t), "3 requests · 0 declined")
        XCTAssertEqual(TriageFacts.trackBadge(t, role: "Friend")?.label, "Trusted")
        XCTAssertFalse(TriageFacts.setupMissing(t))
    }

    func testLowSpaceAndMissingSetup() {
        let disk = RequestTriage.Disk(rootPaths: ["/movies"], totalBytes: 100, freeBytes: 10, neededBytes: 50, freeAfterBytes: -40)
        let t = RequestTriage(requestId: 1, versions: [.init(tier: .uhd, configured: false)], disks: [disk], lowSpace: true)
        XCTAssertEqual(TriageFacts.freeAfter(t).value, "Not enough space")
        XCTAssertEqual(TriageFacts.freeAfter(t).tone, .warn)
        XCTAssertEqual(TriageFacts.lowSpaceMessage(t), "Not enough space on /movies — needs ~50 B, 10 B free.")
        XCTAssertTrue(TriageFacts.setupMissing(t))
        XCTAssertEqual(TriageFacts.bulkLowSpace([1: t, 2: t], ids: [1, 2]), "Not enough space on /movies for all 2.")
    }

    func testAgesAndLabels() {
        let now = ServerTime.parse("2026-10-15T12:00:00")!
        XCTAssertEqual(TriageFacts.compactAge("2026-10-15T11:48:00", now: now), "12 m")
        XCTAssertEqual(TriageFacts.compactAge("2026-10-13T12:00:00", now: now), "2 d")
        XCTAssertEqual(TriageFacts.compactAge(nil, now: now), "")
        XCTAssertEqual(TriageFacts.approveLabel([.hd, .uhd]), "Approve HD + 4K")
        XCTAssertEqual(TriageFacts.shortDay("2026-11-03"), "3 Nov")
        XCTAssertEqual(TriageFacts.bulkFailureText(["withdrawn", "not_rejectable", "withdrawn", nil]),
                       "2 withdrawn · 1 already decided · 1 couldn’t be decided")
        XCTAssertEqual(TriageFacts.failureMessage(code: nil, status: 422), "Set up Add defaults for this kind and tier in Settings first.")
    }

    // MARK: Scope

    func testScopeWords() {
        let r = request(#""seasons":[1,2,4],"episodes":[{"season":5,"episode":3},{"season":5,"episode":2}]"#)
        XCTAssertEqual(RequestScope.head(r), "Seasons 1–2, 4 · Season 5 from E2")
        XCTAssertEqual(RequestScope.chip(r), "S01–S02, S04, S05·E2+")
        XCTAssertEqual(RequestScope.copy(r, existing: nil)?.lead, "Requested Seasons 1–2, 4 · Season 5")
        let fresh = RequestScope.copy(r, existing: .init(monitored: [], unmonitored: []))
        XCTAssertEqual(fresh?.lead, "Monitors Seasons 1–2, 4 · Season 5 from E2")
        XCTAssertTrue(fresh?.later == true)
        let widen = RequestScope.copy(r, existing: .init(monitored: [.hd], unmonitored: []), requested: [.hd])
        XCTAssertEqual(widen?.text, "Adds Seasons 1–2, 4 · Season 5 to the existing HD·1080p version")
        XCTAssertNil(RequestScope.copy(request(#""seasons":[]"#), existing: nil))
    }

    // MARK: Board

    func testColumnsAndMerge() {
        let pending = request(#""requested_at":"2026-10-15T10:00:00""#)
        let downloading = request(id: 2, status: "approved", #""lifecycle":[{"tier":"HD-1080p","step":"downloading","needs_manual_import":false,"importing":false}],"thread":{"unread":0,"last_event_at":"2026-10-15T11:00:00"}"#)
        let waiting = request(id: 3, status: "waiting", #""requested_at":"2026-10-15T12:00:00""#)
        XCTAssertEqual(RequestBoard.column(pending), .pending)
        XCTAssertEqual(RequestBoard.column(downloading), .downloading)
        XCTAssertNil(RequestBoard.column(request(status: "withdrawn", "")))
        let merged = RequestBoard.merge([.pending: [pending, waiting], .active: [downloading]])
        XCTAssertEqual(merged.map(\.id), [3, 2, 1])
        XCTAssertEqual(RequestBoard.group(merged)[.pending]?.map(\.id), [1, 3])
    }

    func testTimeToAvailableAndPill() {
        let r = request(status: "fulfilled", #""requested_at":"2026-10-15T10:00:00","available_at":"2026-10-15T12:05:00""#)
        XCTAssertEqual(RequestBoard.timeToAvailable(r), "2h 05m")
        XCTAssertEqual(RequestBoard.historyPill(r).label, "Available")
        XCTAssertEqual(RequestBoard.countLabel(30, exact: false), "30+")
        XCTAssertNil(HistoryFilter.approved.query(search: nil).filter)
    }
}

final class IssueFormatTests: XCTestCase {
    func testWords() {
        XCTAssertEqual(IssueFormat.stateLabel("CHECKING"), "Checking")
        XCTAssertEqual(IssueFormat.stateLabel("NEEDS_ADMIN", reopenCount: 1), "Reopened")
        XCTAssertEqual(IssueFormat.stateTone("RESOLVED"), .resolved)
        XCTAssertEqual(IssueFormat.stateLabel("NEEDS_ADMIN"), "Needs an admin")
        XCTAssertEqual(IssueFormat.stateTone("NEEDS_ADMIN"), .accent)
        XCTAssertEqual(IssueFormat.stateTone("NEEDS_ADMIN", reopenCount: 1), .attention)
        XCTAssertEqual(IssueFormat.stateLabel("AWAITING_USER"), "Open")
        XCTAssertEqual(IssueFormat.problems(series: false).count, 5)
        XCTAssertEqual(IssueFormat.disabledSub("rate_limited", choiceId: "request_version"),
                       "Used this week’s requests · They reset on Monday.")
        XCTAssertEqual(IssueFormat.disabledSub("no_access"), "Needs UHD·4K access · Ask an admin below instead.")
        XCTAssertEqual(IssueFormat.disabledSub("no_access", manager: true), "Not allowed on this title")
        XCTAssertEqual(IssueFormat.defaultVersionId([.init(id: 2, tier: .uhd), .init(id: 3, tier: .hd, edition: "Extended"),
                                                     .init(id: 4, tier: .hd)]), 4)
        XCTAssertTrue(IssueFormat.scopeComplete(scope: "season", season: 1, episode: nil))
        XCTAssertFalse(IssueFormat.scopeComplete(scope: "episode", season: 1, episode: nil))
    }

    func testPickReportAndDecode() throws {
        let json = #"{"id":7,"media_item_id":3,"issue_type":"playback","scope":"item","status":"open","state":"OPEN","reopen_count":0,"participants_count":2,"thread":{"unread":1,"last_event_at":"2026-10-15T10:00:00"},"reports":[{"id":11,"problem":"WONT_PLAY","version":{"id":5,"tier":"HD-1080p"},"scope":"item","state":"AWAITING_USER","verdict_summary":{"text":"The file is missing 30%","verified":true},"choices":[{"id":"search_missing","label":"Search for a new copy","permission":"allowed"}],"created_at":"2026-10-15T09:00:00","mine":true,"check_generation":1},{"id":12,"problem":"LANGUAGE","version":{"id":6,"tier":"UHD-2160p"},"scope":"item","state":"OPEN","verdict_summary":{"text":"x"},"choices":[],"created_at":"2026-10-15T09:00:00","mine":true}],"media_title":"Dune","media_year":2021}"#
        let issue = try APIClient.decoder.decode(MediaIssue.self, from: Data(json.utf8))
        XCTAssertEqual(issue.reports?.count, 2)
        XCTAssertEqual(IssueFormat.pickReport(issue.reports ?? [], problem: "WONT_PLAY", versionId: 5)?.id, 11)
        XCTAssertEqual(IssueFormat.pickReport(issue.reports ?? [])?.id, 12)
        XCTAssertEqual(issue.reports?.first?.choices.first?.allowed, true)
        let marker = RequestThreadEvent(id: 1, kind: "SYSTEM", eventType: "rescan", data: .init(action: "rescan"))
        XCTAssertTrue(IssueFormat.isMarkerLine(marker))
    }
}

final class ThreadLogicTests: XCTestCase {
    private func report(_ id: Int, _ state: String, problem: String = "WONT_PLAY", reporter: Int? = nil, guardState: String? = nil,
                        choices: [IssueChoice] = [], staged: IssueStagedCopy? = nil) -> IssueReport {
        let person = reporter.map { try! APIClient.decoder.decode(RequestPerson.self, from: Data(#"{"id":\#($0),"display_name":"P\#($0)"}"#.utf8)) }
        return IssueReport(id: id, problem: problem, state: state, verdictSummary: .init(text: "Said \(id)", verified: true),
                           choices: choices, reporter: person, stagedCopy: staged, guardState: guardState)
    }

    func testLeadAndBanner() throws {
        let reports = [report(1, "CHECKING"), report(2, "NEEDS_ADMIN"), report(3, "RESOLVED")]
        XCTAssertEqual(ThreadBanner.leadReport(reports)?.id, 2)
        let json = #"{"id":9,"media_item_id":1,"issue_type":"playback","scope":"item","status":"open","state":"OPEN","reports":[]}"#
        var issue = try APIClient.decoder.decode(MediaIssue.self, from: Data(json.utf8))
        XCTAssertEqual(ThreadBanner.banner(issue).text, "Open")
        let waiting = #"{"id":9,"media_item_id":1,"issue_type":"playback","scope":"item","status":"open","state":"OPEN","reports":[{"id":4,"problem":"WONT_PLAY","version":{},"scope":"item","state":"AWAITING_USER","verdict_summary":{"text":"x"},"choices":[{"id":"search_missing","label":"Search for a new copy"}],"reporter":{"id":2,"display_name":"Sam"}}]}"#
        issue = try APIClient.decoder.decode(MediaIssue.self, from: Data(waiting.utf8))
        let b = ThreadBanner.banner(issue)
        XCTAssertEqual(b.text, "Waiting on Sam")
        XCTAssertEqual(b.detail, "A fix is on offer: “Search for a new copy”. They haven’t chosen yet.")
    }

    func testOpenWithNoReportsIsNeverResolved() throws {
        let json = #"{"id":9,"media_item_id":1,"issue_type":"playback","scope":"item","status":"open","state":"OPEN","reports":[]}"#
        let b = ThreadBanner.banner(try APIClient.decoder.decode(MediaIssue.self, from: Data(json.utf8)))
        XCTAssertEqual(b.tone, .needs)
        XCTAssertEqual(b.text, "Open")
        XCTAssertEqual(b.detail, "An admin will take a look.")
        XCTAssertFalse(b.verified)
    }

    func testResolvedWithNoReports() throws {
        let json = #"{"id":9,"media_item_id":1,"issue_type":"playback","scope":"item","status":"resolved","state":"RESOLVED","reports":[]}"#
        let b = ThreadBanner.banner(try APIClient.decoder.decode(MediaIssue.self, from: Data(json.utf8)))
        XCTAssertEqual(b.tone, .ok)
        XCTAssertEqual(b.text, "Resolved")
        XCTAssertEqual(b.detail, "Nothing more needs doing.")
    }

    func testGuardrailHeldLanguage() throws {
        let staged = IssueStagedCopy(old: .init(fileId: 1, audioLanguages: ["ja"]), new: .init(fileId: 2, audioLanguages: ["ja", "en"]),
                                     state: "held", kind: "language")
        let lead = report(5, "NEEDS_ADMIN", reporter: 3, guardState: "held", staged: staged)
        let json = #"{"id":9,"media_item_id":1,"issue_type":"playback","scope":"item","status":"open","state":"OPEN"}"#
        let issue = try APIClient.decoder.decode(MediaIssue.self, from: Data(json.utf8))
        XCTAssertEqual(ThreadBanner.guardrail(issue, lead)?.text, "A copy with English audio is ready")
        XCTAssertTrue(StagedFacts.addsAudio(staged.old, staged.new))
    }

    func testStagedGates() {
        let use = IssueChoice(id: "use_new_copy", label: "Use")
        let verifying = IssueStagedCopy(old: nil, new: .init(fileId: 2), state: "verifying", kind: "dead")
        XCTAssertEqual(StagedFacts.stagedReason(report(1, "NEEDS_ADMIN", choices: [use], staged: verifying), use: true),
                       "The new copy is still being checked")
        XCTAssertNil(StagedFacts.stagedReason(report(1, "NEEDS_ADMIN", choices: [use],
                                                     staged: .init(old: nil, new: .init(fileId: 2), state: "held", kind: "dead")), use: true))
        XCTAssertEqual(StagedFacts.stagedReason(report(1, "NEEDS_ADMIN"), use: false), "Not available for this report")
        XCTAssertEqual(StagedFacts.regrabReason(report(1, "FIXING"), IssueChoice(id: "regrab", label: "R")), "A fix is already running")
    }

    func testAudienceAndEvidence() {
        let reports = [report(1, "NEEDS_ADMIN", reporter: 7), report(2, "AWAITING_USER", reporter: 8), report(3, "RESOLVED", reporter: 9)]
        XCTAssertEqual(IssueChipRules.reporters(reports).compactMap(\.id), [9, 8, 7])
        XCTAssertEqual(IssueChipRules.defaultAudience(reports, openerId: 7, authorId: 8), 7)
        XCTAssertNil(IssueChipRules.defaultAudience([], openerId: 5, authorId: 5))
        let diag = JSONValue.object(["verdict": .string("dead"), "missingPct": .number(30), "summary": .string("x"),
                                     "evidence": .array([.object(["path": .string("/a")])])])
        let rows = EvidenceRows.rows(diag)
        XCTAssertTrue(rows.contains { $0.label == "missing_pct" && $0.value == "30" })
        XCTAssertTrue(rows.contains { $0.label == "path" && $0.value == "/a" })
        XCTAssertFalse(rows.contains { $0.label == "summary" })
    }
}
