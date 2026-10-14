import SwiftUI
import FusionhaKit

// MARK: - Logic (tasks-format.ts)

enum TaskIconKind { case search, rss, refresh, fail }

struct FactPart: Hashable {
    enum Tone { case grab, up, miss }
    let text: String
    var tone: Tone?
}

enum TasksLogic {
    static func iconKind(_ run: ActivityRun) -> TaskIconKind {
        if run.status == "failed" { return .fail }
        if run.trigger == "rss" { return .rss }
        if run.trigger == "scheduled" { return .refresh }
        return .search
    }

    static func isStuckNoGrab(_ run: ActivityRun) -> Bool {
        run.status == "completed" && run.releases > 0 && run.grabbed == 0 && run.upgraded == 0
    }

    static func factParts(_ run: ActivityRun) -> [FactPart] {
        if run.status == "failed" {
            var parts = [FactPart(text: "Failed", tone: .miss)]
            if run.errors > 0 { parts.append(FactPart(text: ActFmt.plural(run.errors, "error"))) }
            return parts
        }
        if run.status == "running", let phase = run.phase, !phase.isEmpty {
            let label = phase.prefix(1).uppercased() + phase.dropFirst()
            let total = run.progressTotal ?? 0
            return [FactPart(text: total > 0 ? "\(label) \(run.progressCurrent ?? 0)/\(total)" : label)]
        }
        if run.status != "running" {
            if run.grabbed > 0 || run.upgraded > 0 {
                var parts: [FactPart] = []
                if run.grabbed > 0 { parts.append(FactPart(text: "Grabbed \(run.grabbed)", tone: .grab)) }
                if run.upgraded > 0 { parts.append(FactPart(text: "\(run.upgraded) upgraded", tone: .up)) }
                parts.append(FactPart(text: "\(run.releases) found"))
                if run.rejected > 0 { parts.append(FactPart(text: "\(run.rejected) rejected", tone: .miss)) }
                return parts
            }
            if isStuckNoGrab(run) {
                return [FactPart(text: "Nothing grabbed — \(run.releases) found, all rejected", tone: .miss)]
            }
            if run.releases == 0, run.skippedInFlight == true {
                return [FactPart(text: "Already downloading — nothing to search")]
            }
            if run.releases == 0 { return [FactPart(text: "No releases found")] }
            return [FactPart(text: "\(run.releases) found")]
        }
        var parts: [FactPart] = []
        if run.grabbed > 0 { parts.append(FactPart(text: "Grabbed \(run.grabbed)", tone: .grab)) }
        if run.upgraded > 0 { parts.append(FactPart(text: "\(run.upgraded) upgraded", tone: .up)) }
        if run.evaluated > 0 {
            parts.append(FactPart(text: run.releases > 0 ? "\(run.evaluated) / \(run.releases) evaluated" : "\(run.evaluated) evaluated"))
        } else if run.releases > 0 {
            parts.append(FactPart(text: "\(run.releases) releases"))
        }
        if parts.isEmpty { parts.append(FactPart(text: "Searching…")) }
        return parts
    }

    static func factualLine(_ run: ActivityRun) -> String {
        let text = factParts(run).map(\.text).joined(separator: " · ")
        return text.isEmpty ? "Done" : text
    }

    static func progressPct(_ run: ActivityRun) -> Double? {
        guard run.releases > 0 else { return nil }
        return min(1, max(0, Double(run.evaluated) / Double(run.releases)))
    }

    static func targetDetail(_ run: ActivityRun) -> String? { run.targetSummary ?? run.targetTitle }

    static func targetCountLabel(_ run: ActivityRun) -> String? {
        run.targetCount.map { ActFmt.plural($0, "target") }
    }

    struct RunGroup: Identifiable {
        let key: String
        let latest: ActivityRun
        var older: [ActivityRun]
        var id: String { key }
    }

    static func groupKey(_ run: ActivityRun) -> String {
        if run.trigger == "rss" || run.trigger == "scheduled" { return "\(run.trigger)::\(run.name)" }
        return "\(run.trigger)::\(run.name)::\(run.targetTitle ?? "#\(run.id)")"
    }

    static func groupRuns(_ runs: [ActivityRun]) -> [RunGroup] {
        var order: [String] = []
        var byKey: [String: RunGroup] = [:]
        for run in runs {
            let key = groupKey(run)
            if byKey[key] != nil {
                byKey[key]?.older.append(run)
            } else {
                byKey[key] = RunGroup(key: key, latest: run, older: [])
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }
    }

    static func earlierLabel(_ group: RunGroup) -> String {
        let n = group.older.count
        return "\(n) earlier \(group.latest.name)\(n == 1 ? "" : "s")"
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func isRss(_ name: String) -> Bool { normalize(name).contains("rsssync") }
    static func isEnrichment(_ name: String) -> Bool { normalize(name).contains("enrichment") }

    static func scheduledTasks(_ tasks: [ActivitySystemTask], limit: Int = 2) -> [ActivitySystemTask] {
        tasks.filter { !isRss($0.name) && !isEnrichment($0.name) }
            .sorted { (ActFmt.date($0.nextRun) ?? .distantFuture) < (ActFmt.date($1.nextRun) ?? .distantFuture) }
            .prefix(limit)
            .map { $0 }
    }

    /// `schedulerTaskForRun`: only an unambiguous label match for a background sweep.
    static func schedulerTask(for run: ActivityRun, in tasks: [ActivitySystemTask]) -> ActivitySystemTask? {
        guard run.trigger == "scheduled" || run.trigger == "rss" else { return nil }
        let wanted = run.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !wanted.isEmpty else { return nil }
        let matches = tasks.filter { ActFmt.taskLabel($0.name).lowercased() == wanted }
        return matches.count == 1 ? matches[0] : nil
    }

    // Backlog search card
    static func searchingCount(_ s: SearchProgress) -> Int { s.targets.filter { $0.state == "searching" }.count }

    static func searchPct(_ s: SearchProgress) -> Int {
        guard s.total > 0 else { return 0 }
        return min(100, max(0, Int((Double(s.processed) / Double(s.total) * 100).rounded())))
    }

    static func scopeLine(_ s: SearchProgress) -> String {
        var titles: [String] = []
        for t in s.targets where !titles.contains(t.group) { titles.append(t.group) }
        let targets = ActFmt.plural(s.total, "target")
        guard !titles.isEmpty else { return targets }
        let shown = titles.prefix(3).joined(separator: ", ")
        let extra = titles.count - 3
        return "\(targets) across \(ActFmt.plural(titles.count, "title")) · \(extra > 0 ? "\(shown) +\(extra)" : shown)"
    }

    struct ScopeGroup: Identifiable {
        let key: String
        let group: String
        let tier: String?
        var targets: [SearchScopeTarget]
        var id: String { key }
    }

    static func groupTargets(_ targets: [SearchScopeTarget]) -> [ScopeGroup] {
        var order: [String] = []
        var byKey: [String: ScopeGroup] = [:]
        for t in targets {
            let key = "\(t.group) \(t.tier ?? "")"
            if byKey[key] != nil { byKey[key]?.targets.append(t) } else {
                byKey[key] = ScopeGroup(key: key, group: t.group, tier: t.tier, targets: [t])
                order.append(key)
            }
        }
        return order.compactMap { byKey[$0] }
    }

    static func isUhd(_ tier: String?) -> Bool {
        guard let tier else { return false }
        return tier.range(of: "2160|uhd|4k", options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func duration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return "a while" }
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s)s" }
        if s < 3600 { return s % 60 == 0 ? "\(s / 60)m" : "\(s / 60)m \(s % 60)s" }
        let m = (s % 3600) / 60
        return m > 0 ? "\(s / 3600)h \(m)m" : "\(s / 3600)h"
    }

    // Decision trail (trail-grouping.ts)
    enum BucketTone { case wrong, notbetter, skip, blocked, grab
        var color: Color {
            switch self {
            case .wrong: return Theme.miss
            case .notbetter: return Theme.stuck
            case .skip: return Theme.unmonitored
            case .blocked: return Theme.danger
            case .grab: return Theme.done
            }
        }
    }

    struct Bucket { let key: String; let label: String; let tone: BucketTone }

    static func bucket(_ c: RunCandidate) -> Bucket {
        let r = c.reason.lowercased()
        if c.blocklisted == true || r.contains("blocklist") { return Bucket(key: "blocklisted", label: "Blocklisted", tone: .blocked) }
        if r.contains("already") || r.contains("in flight") || r.contains("pre-excluded")
            || (r.contains("download for this release") && r.contains("exists")) {
            return Bucket(key: "already", label: "Already grabbed", tone: .skip)
        }
        if r.contains("download client unavailable") || r.contains("database busy") || r.hasPrefix("not grabbed") {
            return Bucket(key: "grab-failed", label: "Couldn't be grabbed", tone: .blocked)
        }
        if r.contains("not an upgrade") { return Bucket(key: "upgrade", label: "No upgrade over your file", tone: .notbetter) }
        if r.contains("not wanted in the quality profile") { return Bucket(key: "quality", label: "Not in your quality profile", tone: .wrong) }
        if r.contains("custom format score") || r.contains("profile minimum") {
            return Bucket(key: "cf-floor", label: "Below the custom-format floor", tone: .wrong)
        }
        if r.contains("rejected on size") || r.contains("size window") { return Bucket(key: "size", label: "Outside the size window", tone: .wrong) }
        if r.contains("edition") && r.contains("does not match") { return Bucket(key: "edition", label: "Wrong edition", tone: .wrong) }
        return Bucket(key: "other:\(r)", label: c.reason.isEmpty ? "Passed over" : c.reason, tone: .skip)
    }

    struct DedupRow: Identifiable {
        let rep: RunCandidate
        let count: Int
        let indexers: Int
        var id: Int { rep.id }
    }

    static func dedupe(_ cands: [RunCandidate]) -> [DedupRow] {
        func key(_ title: String) -> String {
            title.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        var order: [String] = []
        var members: [String: [RunCandidate]] = [:]
        for c in cands {
            let k = key(c.releaseTitle)
            if members[k] == nil { order.append(k); members[k] = [] }
            members[k]?.append(c)
        }
        return order.compactMap { k in
            guard let m = members[k], let first = m.first else { return nil }
            let rep = m.reduce(first) { ($1.cfScore ?? Int.min) > ($0.cfScore ?? Int.min) ? $1 : $0 }
            return DedupRow(rep: rep, count: m.count, indexers: Set(m.compactMap(\.indexer)).count)
        }
    }

    struct ReasonGroup: Identifiable {
        let bucket: Bucket
        let rows: [DedupRow]
        let total: Int
        let qualifier: String?
        var id: String { bucket.key }
    }

    static func groupByReason(_ cands: [RunCandidate]) -> [ReasonGroup] {
        var order: [String] = []
        var byKey: [String: (Bucket, [RunCandidate])] = [:]
        for c in cands {
            let b = bucket(c)
            if byKey[b.key] == nil { order.append(b.key); byKey[b.key] = (b, []) }
            byKey[b.key]?.1.append(c)
        }
        let groups: [ReasonGroup] = order.compactMap { k in
            guard let entry = byKey[k] else { return nil }
            return ReasonGroup(bucket: entry.0, rows: dedupe(entry.1), total: entry.1.count, qualifier: qualifier(entry.0, entry.1))
        }
        return groups.enumerated().sorted { a, b in
            a.element.total != b.element.total ? a.element.total > b.element.total : a.offset < b.offset
        }.map(\.element)
    }

    private static func qualifier(_ b: Bucket, _ members: [RunCandidate]) -> String? {
        switch b.key {
        case "quality":
            var seen: [String] = []
            for m in members { if let q = m.quality.map(ActFmt.quality), !seen.contains(q) { seen.append(q) } }
            let qs = Array(seen.prefix(4))
            guard !qs.isEmpty else { return nil }
            let phrase: String
            if qs.count == 1 { phrase = qs[0] } else if qs.count == 2 { phrase = "\(qs[0]) and \(qs[1])" } else {
                phrase = qs.dropLast().joined(separator: ", ") + " and " + (qs.last ?? "")
            }
            return "\(phrase) \(qs.count > 1 ? "aren't" : "isn't") in the ladder"
        case "upgrade":
            let reason = members.first?.reason ?? ""
            if let range = reason.range(of: "existing (.+?) file", options: [.regularExpression, .caseInsensitive]) {
                let match = String(reason[range])
                let inner = match.dropFirst("existing ".count).dropLast(" file".count)
                return "current file: \(inner)"
            }
            return nil
        case "already":
            return "a download for this release already exists"
        default:
            return nil
        }
    }
}
