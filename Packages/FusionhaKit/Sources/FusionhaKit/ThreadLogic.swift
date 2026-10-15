import Foundation

/// Row facts for the managers' threads list (web `thread-meta.ts`).
public enum ThreadMeta {
    public struct Person: Sendable, Hashable {
        public let id: Int?
        public let name: String
    }

    /// Everyone on the thread, newest report first; a request has its requester.
    public static func people(_ item: ThreadItem) -> [Person] {
        if item.type == "issue", let issue = item.issue {
            let named = (issue.reports ?? []).sorted { $0.id > $1.id }.compactMap(\.reporter)
            let pool = named.isEmpty ? [issue.reporter].compactMap { $0 } : named
            var seen = Set<String>()
            return pool.compactMap { p in
                let key = p.id.map { "u\($0)" } ?? "n\(p.displayName)"
                return seen.insert(key).inserted ? Person(id: p.id, name: p.displayName) : nil
            }
        }
        return item.request?.requester.map { [Person(id: $0.id, name: $0.displayName)] } ?? []
    }

    /// The person an AWAITING_USER issue is waiting on.
    public static func waitingOn(_ item: ThreadItem) -> String? {
        guard item.type == "issue", let issue = item.issue,
              let waiting = issue.reports?.first(where: { $0.state == "AWAITING_USER" }) else { return nil }
        return waiting.reporter?.displayName ?? issue.reporter?.displayName
    }

    public static func tiers(_ item: ThreadItem) -> [QualityTier] {
        if item.type == "request" { return item.request?.tiers ?? [] }
        var out: [QualityTier] = []
        for t in (item.issue?.reports ?? []).compactMap(\.version.tier) where !out.contains(t) { out.append(t) }
        return out
    }

    public static func hasUnread(_ item: ThreadItem) -> Bool {
        ((item.type == "issue" ? item.issue?.thread?.unread : item.request?.thread?.unread) ?? 0) > 0
    }

    /// An issue's state word, or a request's step.
    public static func stateLabel(_ item: ThreadItem) -> String {
        if item.type == "issue", let issue = item.issue {
            return IssueFormat.stateLabel(issue.state ?? "OPEN", reopenCount: issue.reopenCount ?? 0)
        }
        guard let r = item.request else { return "" }
        if r.status == "approved" || r.status == "fulfilled", let lead = RequestLifecycle.lead(r.lifecycle ?? []) {
            let word = RequestLifecycle.versionWord(lead)
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return RequestBoard.statusLabel(r.status)
    }

    public static func title(_ item: ThreadItem) -> String {
        item.title ?? item.issue?.mediaTitle ?? item.request?.title ?? "Untitled"
    }

    public static func lineLabel(_ item: ThreadItem) -> String {
        if item.type == "issue", let lead = item.issue?.reports?.first { return IssueFormat.problemLabel(lead.problem) }
        return "Request"
    }
}

/// Where an issue thread stands, in the manager's words (web `thread-banner.ts`
/// and `guardrail-banner.ts`).
public enum ThreadBanner {
    public enum Tone: Sendable, Hashable { case checking, fixing, needs, ok, neutral }

    public struct Banner: Sendable, Hashable {
        public let tone: Tone
        public let text: String
        public let detail: String
        public let verified: Bool
        public let symbol: String?
    }

    /// The report most in need of a person.
    public static func leadReport(_ reports: [IssueReport]) -> IssueReport? {
        let urgency = ["NEEDS_ADMIN", "AWAITING_USER", "FIXING", "CHECKING", "OPEN"]
        let open = reports.filter { $0.state != "RESOLVED" }
        let pool = open.isEmpty ? reports : open
        return pool.enumerated().min { a, b in
            let ra = urgency.firstIndex(of: a.element.state) ?? 99, rb = urgency.firstIndex(of: b.element.state) ?? 99
            return ra == rb ? a.offset < b.offset : ra < rb
        }?.element
    }

    /// `reopenedBy`: the newest "reopened" line's actor name and whether an admin.
    public static func banner(_ issue: MediaIssue, reopenedBy: (name: String?, admin: Bool)? = nil) -> Banner {
        let reports = issue.reports ?? []
        let lead = leadReport(reports)
        let said = lead?.verdictSummary.text ?? ""
        let verified = lead?.verdictSummary.verified == true && !said.isEmpty
        let name = lead?.reporter?.displayName ?? issue.reporter?.displayName ?? "the reporter"
        func make(_ tone: Tone, _ text: String, _ detail: String, _ tag: Bool? = nil) -> Banner {
            Banner(tone: tone, text: text, detail: detail, verified: tag ?? verified, symbol: nil)
        }
        if let lead, let guardBanner = guardrail(issue, lead) { return guardBanner }
        guard let lead, issue.state != "RESOLVED" else {
            return make(.ok, lead?.resolution ?? (said.isEmpty ? "Resolved" : said), "Nothing more needs doing.")
        }
        if (issue.reopenCount ?? 0) > 0 {
            if reopenedBy?.admin == true {
                return make(.needs, reopenedBy?.name.map { "Reopened by \($0)" } ?? "Reopened by an admin",
                            "It was resolved earlier. An admin reopened it to take another look.", false)
            }
            return make(.needs, reopenedBy?.name.map { "Reopened by \($0) · “Didn’t help”" } ?? "Reopened · “Didn’t help”",
                        "It was resolved earlier, and they say it still isn’t right.", false)
        }
        switch lead.state {
        case "CHECKING":
            return make(.checking, "Checking the file", "The check usually takes a few seconds. Nothing for you to do yet.")
        case "FIXING":
            let detail: String
            switch lead.problem {
            case "NOT_IN_PLEX": detail = "The file is on disk. fusionha re-checks Plex at 2, 5, 10 and 20 minutes, then asks an admin."
            case "MISSING_EPS": detail = "fusionha is searching for the missing episodes. No one needs to act."
            default: detail = "We’re on it. We’ll message the reporter when something changes."
            }
            return make(.fixing, said, detail)
        case "AWAITING_USER":
            let offer = lead.choices.first?.label
            return make(.needs, "Waiting on \(name)",
                        offer.map { "A fix is on offer: “\($0)”. They haven’t chosen yet." } ?? "They haven’t chosen yet.")
        case "NEEDS_ADMIN":
            if lead.verdictSummary.code == "needs_decypharr" {
                return make(.needs, "Automatic file checks need fusionha’s decypharr build",
                            "This title downloads through a client that can’t be checked.")
            }
            return make(.needs, said, "Automatic replacement arrives with file-check fixes. For now this one is yours.")
        default:
            return make(.needs, said, "An admin will take a look.")
        }
    }

    static func number(_ v: JSONValue?) -> Double? {
        if case .number(let n)? = v { return n }
        return nil
    }

    /// A keep-old replacement's state, or nil when the server names none.
    static func guardrail(_ issue: MediaIssue, _ lead: IssueReport) -> Banner? {
        let verified = lead.verdictSummary.verified == true && !lead.verdictSummary.text.isEmpty
        func b(_ tone: Tone, _ symbol: String, _ text: String, _ detail: String) -> Banner {
            Banner(tone: tone, text: text, detail: detail, verified: verified, symbol: symbol)
        }
        let reporter = lead.reporter?.displayName ?? issue.reporter?.displayName ?? "The reporter"
        switch lead.guardState {
        case "replacing":
            let dead = lead.stagedCopy.map { $0.kind == "dead" } ?? (lead.problem == "WONT_PLAY")
            let attempts = Int(number(lead.diagnosis?.value.object?["fix"]?.object?["attempts"]) ?? 0)
            return b(.fixing, "arrow.clockwise",
                     dead ? "Replacing a copy that’s broken at the source" : "Replacing it · the current copy is kept",
                     "The current copy stays in the library while fusionha finds, downloads and checks a new one." + (attempts > 0 ? " Attempt \(attempts + 1)." : ""))
        case "held":
            let langs = lead.stagedCopy.flatMap { $0.kind == "language" ? StagedFacts.addedLanguages($0) : nil } ?? []
            if !langs.isEmpty {
                let names = langs.joined(separator: " and ")
                return b(.needs, "character.bubble", "A copy with \(names) audio is ready",
                         "\(reporter) chose “Find a release with \(names) audio”. fusionha downloaded one, checked it plays and checked it has \(names) audio. The current copy is untouched until you decide.")
            }
            return b(.needs, "checkmark.shield", "A new copy is ready · held for your confirmation",
                     "fusionha downloaded a replacement and checked that it plays. The current copy is untouched until you decide.")
        case "swapped":
            return b(.ok, "checkmark", "Replaced with a checked copy",
                     "The new copy passed its check, then took the old one’s place. The title was never without a file.")
        case "paused":
            return b(.needs, "pause", "Auto-fix paused · needs review",
                     "Repeated fixes for this copy failed, so fusionha stopped trying on its own. The current copy is kept. Your Re-grab clears the pause and starts a keep-old replacement; Resolve clears it too. The reporter can’t restart it.")
        case "autofix_off":
            return b(.needs, "power", "Auto-fix is off · the current copy is kept",
                     "Reports are still checked, but every confirmed problem goes to an admin. Re-grab needs Auto-fix back on.")
        case "inconclusive":
            return b(.neutral, "clock", "Couldn’t check the file · nothing changes automatically",
                     "decypharr didn’t answer in time. fusionha checks again every hour for 24 hours. If a later check says the file is dead, the fix starts by itself; until then the file is left exactly as it is.")
        case "second_check":
            let at = lead.diagnosis?.value.object?["nextRecheckAt"]?.string.flatMap(ServerTime.parse)
            let clock = at.map { d -> String in
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                return f.string(from: d)
            }
            return b(.checking, "clock", clock.map { "Debrid second check · again at \($0)" } ?? "Debrid second check",
                     "The debrid link looked dead once. Debrid links can come back, so fusionha needs a second dead verdict at least 10 minutes later before it replaces anything. A second check that says it plays closes this as plays fine.")
        case "plays_fine":
            return b(.needs, "play", "Plays fine in our check · verify it",
                     "decypharr read the file cleanly. If it really won’t play, Re-grab replaces it, and the current copy stays until the new one checks out.")
        default:
            return nil
        }
    }
}

/// A staged copy's words and gates (web `staged-facts.ts`, `staged-gate.ts`).
public enum StagedFacts {
    public static func list(_ xs: [String]?) -> String { (xs ?? []).isEmpty ? "—" : (xs ?? []).joined(separator: " + ") }

    public static func size(_ c: IssueCopyFacts) -> String { (c.size ?? 0) > 0 ? DetailText.bytes(c.size) : "—" }

    /// "Remux-2160p · 48.1 GB".
    public static func qualitySize(_ c: IssueCopyFacts) -> String {
        let parts = [c.quality, (c.size ?? 0) > 0 ? DetailText.bytes(c.size) : nil].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    public static func checkSentence(_ c: IssueCopyFacts) -> String {
        if let s = c.verdictSummary, !s.isEmpty { return s }
        return c.verdict ?? "Not checked"
    }

    public static func shortRelease(_ c: IssueCopyFacts) -> String {
        let r = c.release ?? ""
        return r.count > 48 ? "…" + r.suffix(44) : r
    }

    public static func addsAudio(_ old: IssueCopyFacts?, _ new: IssueCopyFacts) -> Bool {
        guard let old else { return false }
        return (new.audioLanguages ?? []).contains { !(old.audioLanguages ?? []).contains($0) }
    }

    /// The audio languages the new copy adds, by name.
    public static func addedLanguages(_ staged: IssueStagedCopy) -> [String] {
        let have = Set(staged.old?.audioLanguages ?? [])
        return (staged.new.audioLanguages ?? []).filter { !have.contains($0) }.map {
            Locale(identifier: "en").localizedString(forLanguageCode: $0) ?? $0
        }
    }

    public static func headline(_ state: String) -> String {
        state == "held" ? "New copy downloaded and checked" : (state == "unknown" ? "New copy couldn’t be checked" : "New copy being checked")
    }

    /// Why Use / Discard is off, or nil when it's on.
    public static func stagedReason(_ report: IssueReport, use: Bool) -> String? {
        guard let choice = report.choices.first(where: { $0.id == (use ? "use_new_copy" : "discard_new_copy") }) else {
            return "Not available for this report"
        }
        if !choice.allowed { return IssueFormat.permissionHint(choice.permission, manager: true) }
        if use {
            if report.stagedCopy?.stuck != nil { return "This new copy is stuck · discard it instead" }
            if report.stagedCopy?.state == "verifying" { return "The new copy is still being checked" }
            if report.stagedCopy?.state == "unknown" { return "The new copy couldn’t be checked" }
        }
        return nil
    }

    public static func regrabReason(_ report: IssueReport, _ choice: IssueChoice) -> String? {
        if choice.permission == "not_enabled" { return "Re-grab needs Auto-fix back on" }
        if !choice.allowed { return IssueFormat.permissionHint(choice.permission, manager: true) }
        if report.stagedCopy?.stuck != nil { return "Discard the stuck new copy first" }
        if report.fixBusy == true { return "A download for this copy is already on its way" }
        if report.state == "FIXING" { return "A fix is already running" }
        return nil
    }

    public static func findReason(_ choice: IssueChoice) -> String? {
        if choice.allowed { return nil }
        if choice.permission == "not_enabled", let sub = choice.sub { return sub }
        return IssueFormat.permissionHint(choice.permission, manager: true, choiceId: choice.id)
    }

    /// Why a stuck copy is stuck.
    public static func stuckWhy(_ s: IssueStagedCopy.Stuck) -> String {
        switch s.reason {
        case "no_root": return "its folder can’t be found"
        case "swap_published": return "a swap was interrupted after it moved into place"
        default: return "a swap was interrupted part-way"
        }
    }

    /// The refusal's list; each server `reason` lights the line it names.
    public static let refusalReasons: [(text: String, reasons: [String])] = [
        ("The new copy didn’t play in a fresh check", ["staged_dead"]),
        ("The new copy hasn’t passed a check yet", ["staged_unverified"]),
        ("The new copy isn’t on disk, or is still being put in place", ["staged_missing", "staged_landing"]),
        ("The copies or the report changed meanwhile", ["staged_changed", "swap_overtaken"]),
        ("The current copy couldn’t be set aside safely", ["swap_not_preserved", "swap_preserve_failed"]),
        ("Another file already has the new copy’s name", ["swap_final_taken"]),
    ]

    /// Codes that mean the dialog's snapshot is no longer true.
    public static let staleCodes: Set<String> = ["staged_changed", "no_staged_copy", "swap_refused", "swap_restore_refused"]
}

/// The manager's chips and their rules (web `IssueChips.tsx`, `file-offers.ts`, `participants.ts`).
public enum IssueChipRules {
    /// The report a chip acts on: the open one on the problem, else the lead.
    public static func actionReport(_ reports: [IssueReport], problem: String) -> IssueReport? {
        let open = reports.filter { $0.state != "RESOLVED" }
        return open.first { $0.problem == problem } ?? reports.first { $0.problem == problem } ?? open.first ?? reports.first
    }

    /// The open report the server offers "request_version" (Add 4K) on.
    public static func fourKOffer(_ reports: [IssueReport]) -> (report: IssueReport, choice: IssueChoice)? {
        for r in reports where r.state != "RESOLVED" {
            if let c = r.choices.first(where: { $0.id == "request_version" }) { return (r, c) }
        }
        return nil
    }

    public enum FileKind: String, CaseIterable, Sendable { case use, discard, regrab, find }

    static func choiceId(_ kind: FileKind) -> String {
        switch kind {
        case .use: return "use_new_copy"
        case .discard: return "discard_new_copy"
        case .regrab: return "regrab"
        case .find: return "find_language_release"
        }
    }

    public struct FileOffer: Sendable, Hashable {
        public let kind: FileKind
        public let report: IssueReport
        public let choice: IssueChoice
    }

    /// One file-action chip per choice the server lists on an open report.
    public static func fileOffers(_ issue: MediaIssue) -> [FileOffer] {
        guard issue.state != "RESOLVED" else { return [] }
        return FileKind.allCases.compactMap { kind in
            for r in issue.reports ?? [] where r.state != "RESOLVED" {
                if let c = r.choices.first(where: { $0.id == choiceId(kind) }) { return FileOffer(kind: kind, report: r, choice: c) }
            }
            return nil
        }
    }

    /// The reporters of a thread's reports, newest report first, once each.
    public static func reporters(_ reports: [IssueReport]) -> [RequestPerson] {
        var seen = Set<Int>()
        return reports.sorted { $0.id > $1.id }.compactMap(\.reporter).filter { p in p.id.map { seen.insert($0).inserted } ?? false }
    }

    /// Who a reply goes to with nobody picked: the newest open report's reporter
    /// (not the author), else the opener unless that's the author; nil = everyone.
    public static func defaultAudience(_ reports: [IssueReport], openerId: Int?, authorId: Int?) -> Int? {
        let open = reports.filter { $0.state != "RESOLVED" }
        let pool = authorId == nil ? open : open.filter { $0.reporter?.id != nil && $0.reporter?.id != authorId }
        if let rid = pool.max(by: { $0.id < $1.id })?.reporter?.id { return rid }
        return openerId == authorId ? nil : openerId
    }
}

/// The manager's Evidence rows from a diagnosis (web `evidence-rows.ts`).
public enum EvidenceRows {
    static let skip: Set<String> = ["summary", "actedBy", "note", "mediaFileId", "auditId", "acted_by", "media_file_id", "audit_id"]

    /// "missingPct" → "missing_pct" (the decoder camel-cases keys).
    static func snake(_ key: String) -> String {
        var out = ""
        for ch in key {
            if ch.isUppercase { out += "_" + ch.lowercased() } else { out.append(ch) }
        }
        return out
    }

    static func scalar(_ v: JSONValue) -> String {
        switch v {
        case .null: return "—"
        case .bool(let b): return b ? "yes" : "no"
        case .number(let n): return n.rounded() == n && abs(n) < 1e15 ? String(Int(n)) : String(n)
        case .string(let s): return s
        default: return ""
        }
    }

    static func isScalar(_ v: JSONValue) -> Bool {
        if case .array = v { return false }
        if case .object = v { return false }
        return true
    }

    public static func rows(_ diagnosis: JSONValue?) -> [(label: String, value: String)] {
        guard let object = diagnosis?.object else { return [] }
        var out: [(String, String)] = []
        for key in object.keys.sorted() where !skip.contains(key) {
            walk(object[key]!, key == "evidence" ? "" : snake(key), 0, &out)
        }
        return out
    }

    static func walk(_ value: JSONValue, _ label: String, _ depth: Int, _ out: inout [(String, String)]) {
        if isScalar(value) { out.append((label, scalar(value))); return }
        if let list = value.array {
            if list.allSatisfy(isScalar) {
                let shown = list.prefix(10).map(scalar).joined(separator: ", ")
                out.append((label, list.isEmpty ? "none" : (list.count > 10 ? "\(shown) +\(list.count - 10) more" : shown)))
                return
            }
            if depth >= 3 { out.append((label, "\(list.count) entries")); return }
            for (i, entry) in list.enumerated() { walk(entry, join(label, list.count > 1 ? "file \(i + 1)" : ""), depth + 1, &out) }
            return
        }
        let entries = (value.object ?? [:]).filter { !skip.contains($0.key) }
        if depth >= 3 { out.append((label, "\(entries.count) fields")); return }
        for key in entries.keys.sorted() { walk(entries[key]!, join(label, snake(key)), depth + 1, &out) }
    }

    static func join(_ parent: String, _ key: String) -> String {
        parent.isEmpty ? key : (key.isEmpty ? parent : "\(parent) · \(key)")
    }
}
