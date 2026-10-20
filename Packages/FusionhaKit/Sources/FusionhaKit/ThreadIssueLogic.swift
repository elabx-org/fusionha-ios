import Foundation

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

    /// The server's flat `evidence_list` (0.4.203), for a report without a diagnosis the app can walk.
    public static func rows(list: [IssueEvidenceItem]?) -> [(label: String, value: String)] {
        (list ?? []).filter { !skip.contains($0.key) }.map { (label: $0.key, value: $0.value) }
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
