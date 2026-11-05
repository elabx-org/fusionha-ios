import Foundation

// The grouped Manual Import's words (v2 slice S9, mock activity-mi.js): each
// card's title, its one sentence, its files, each choice and what it does,
// and the toast when Manual Import closes itself. Built only from what the
// server sent; nothing is guessed.

public enum MIProblemCopy {

    /// "21 upgrades", "2 are shorter than yours", "1 already in your library".
    public static func title(_ p: MIProblem, count n: Int) -> String {
        let one = n == 1
        switch p {
        case .upgrade: return one ? "1 upgrade" : "\(n) upgrades"
        case .new: return one ? "1 is new" : "\(n) are new"
        case .shorter: return one ? "1 is shorter than yours" : "\(n) are shorter than yours"
        case .notUpgrade: return one ? "1 isn’t an upgrade" : "\(n) aren’t upgrades"
        case .mislabeled: return one ? "1 isn’t what its name says" : "\(n) aren’t what their names say"
        case .otherEpisode: return one ? "1 is another episode" : "\(n) are other episodes"
        case .twoEpisodes: return one ? "1 holds two episodes" : "\(n) hold two episodes"
        case .sharedFile: return one ? "1 shares a file" : "\(n) share one file"
        case .needsLook: return one ? "1 needs a look" : "\(n) need a look"
        case .noMatch: return one ? "1 has no match" : "\(n) have no match"
        case .inLibrary: return "\(n) already in your library"
        case .imported: return "\(n) imported"
        }
    }

    /// The problem in a few words, for a file's row ("shorter than yours").
    public static func short(_ p: MIProblem) -> String {
        switch p {
        case .upgrade: return "upgrade"
        case .new: return "new"
        case .shorter: return "shorter than yours"
        case .notUpgrade: return "not an upgrade"
        case .mislabeled: return "not what its name says"
        case .otherEpisode: return "another episode"
        case .twoEpisodes: return "holds two episodes"
        case .sharedFile: return "shares a file"
        case .needsLook: return "needs a look"
        case .noMatch: return "no match"
        case .inLibrary: return "already in your library"
        case .imported: return "imported"
        }
    }

    /// A sentence with its lead in bold ("**EPSiLON Remux (+4,700)** replaces …").
    public struct Sentence: Sendable, Equatable {
        public let lead: String
        public let rest: String
        public var plain: String { [lead, rest].filter { !$0.isEmpty }.joined(separator: " ") }
    }

    /// The card's one sentence, from the first file's facts (with its code when the card has several).
    public static func why(_ g: MIGroup) -> Sentence? {
        guard let r = g.rows.first else { return nil }
        let code = g.rows.count > 1 ? ManualImportBulk.shortCode(r) + ": " : ""
        switch g.problem {
        case .upgrade:
            guard let ef = r.existingFile else { return nil }
            let theirs = releaseName(r.parsed.releaseGroup, r.quality) + cf(r.incomingCf?.score)
            let yours = releaseName(ef.releaseGroup, ef.quality) + cf(ef.cfScore)
            return Sentence(lead: theirs, rest: "replaces your \(yours).")
        case .new: return Sentence(lead: "", rest: "Nothing is in \(g.rows.count == 1 ? "this slot" : "these slots") yet.")
        case .shorter:
            let times = g.rows.compactMap(MIProblemGrouping.runtimes)
            guard let first = times.first else { return nil }
            let same = times.allSatisfy { $0.yours == first.yours && $0.this == first.this }
            return same
                ? Sentence(lead: "", rest: "\(g.rows.count == 1 ? "This file runs" : "These files run") \(first.this) min; yours \(g.rows.count == 1 ? "runs" : "run") \(first.yours) min.")
                : Sentence(lead: "", rest: "Each runs well under the copy you have.")
        case .notUpgrade:
            return ManualImportDecide.replaceConfirm(r).map { Sentence(lead: code, rest: $0 + ".") }
        case .inLibrary:
            let said = r.badges?.first(where: { $0.code == "in_library" })?.text
                ?? "this exact file is already in your library."
            return Sentence(lead: ManualImportBulk.shortCode(r) + ":", rest: said)
        case .imported: return nil
        default:
            let line = ManualImportDecide.sentences(r).first ?? ManualImportRules.advisory(r) ?? ManualImportRules.statusLong(r)
            return Sentence(lead: code, rest: line)
        }
    }

    /// "EPSiLON Remux" from the group and quality.
    public static func releaseName(_ group: String?, _ quality: String?) -> String {
        let q = quality == nil ? "" : DetailText.quality(quality)
        let remux = q.lowercased().contains("remux") ? "Remux" : q
        return [group, remux.isEmpty ? nil : remux].compactMap { $0 }.joined(separator: " ")
    }

    static func cf(_ score: Int?) -> String {
        score.map { " (\(signed($0)))" } ?? ""
    }

    /// "+2,800" / "-150".
    public static func signed(_ score: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.positivePrefix = "+"
        return f.string(from: NSNumber(value: score)) ?? "\(score)"
    }

    /// The card's files: "E2 to E5, E7 to E12, E15 to E26" or "E14 · E15".
    public static func files(_ rows: [ManualImportRow]) -> String {
        let nums = rows.compactMap { $0.target.isSeries ? ($0.target.episode ?? $0.parsed.episodes?.first) : nil }
        guard nums.count == rows.count, Set(rows.compactMap { $0.target.season }).count <= 1 else {
            return rows.map { ManualImportBulk.shortCode($0) }.joined(separator: " · ")
        }
        var runs: [(Int, Int)] = []
        for n in Set(nums).sorted() {
            if let last = runs.last, last.1 == n - 1 { runs[runs.count - 1].1 = n } else { runs.append((n, n)) }
        }
        let ranged = runs.contains { $0.1 - $0.0 >= 2 }
        let parts = runs.flatMap { run -> [String] in
            let (a, b) = run
            if b - a >= 2 { return ["E\(a) to E\(b)"] }
            return Array(a...b).map { "E\($0)" }
        }
        return parts.joined(separator: ranged ? ", " : " · ")
    }

    // MARK: Choices

    /// The choice's name on this card ("Import anyway", "Import both", "Skip").
    public static func label(_ c: MIChoice, _ p: MIProblem, count n: Int, row: ManualImportRow? = nil) -> String {
        switch c {
        case .importFile:
            if MICommitPlan.anyway.contains(p) { return "Import anyway" }
            if p == .sharedFile { return n == 2 ? "Import both" : "Import together" }
            return "Import"
        case .keep: return "Keep yours"
        case .skip: return p == .sharedFile ? (n == 2 ? "Skip both" : "Skip all") : "Skip"
        case .assign:
            if n == 1, let eps = row?.recommendedEpisodes { return "Assign \(ManualImportRules.episodesLabel(eps))" }
            return "Assign both episodes"
        case .rematch:
            if n == 1, let code = row?.titleCheck?.matchesEpisode?.code { return "Re-match to \(code)" }
            return "Re-match each file"
        }
    }

    /// What the choice does, and whether it costs you a copy (drawn as a loss).
    public static func consequence(_ c: MIChoice, _ g: MIGroup) -> (text: String, loss: Bool) {
        let one = g.rows.count == 1
        let r = g.rows.first
        let copies = one ? "copy" : "copies"
        switch c {
        case .importFile:
            switch g.problem {
            case .upgrade:
                let score = r?.existingFile?.cfScore.map { signed($0) + " " } ?? ""
                return ("Your \(score)\(copies) \(one ? "is" : "are") replaced", false)
            case .new: return ("Fills \(one ? "the empty slot" : "the empty slots")", false)
            case .shorter:
                if let t = r.flatMap(MIProblemGrouping.runtimes) {
                    return ("Deletes your \(t.yours)-min \(copies) and keeps the \(t.this)-min \(one ? "cut" : "cuts")", true)
                }
                return ("Deletes your longer \(copies)", true)
            case .notUpgrade, .mislabeled: return ("Replaces your better \(copies)", true)
            case .otherEpisode: return ("Imports as numbered and replaces what is there", r?.existingFile != nil)
            case .sharedFile: return ("One file fills \(files(g.rows).replacingOccurrences(of: " · ", with: " and "))", false)
            default: return ("Imports in place", false)
            }
        case .keep:
            if g.problem == .shorter, let t = r.flatMap(MIProblemGrouping.runtimes) {
                return ("Your \(t.yours)-min \(copies) \(one ? "stays" : "stay")", false)
            }
            return g.problem == .upgrade ? ("Your \(copies) \(one ? "stays" : "stay"); Fusionha keeps looking", false)
                : ("Your \(copies) \(one ? "stays" : "stay")", false)
        case .skip:
            if g.problem == .inLibrary { return ("Nothing changes", false) }
            if g.problem == .sharedFile { return ("\(files(g.rows).replacingOccurrences(of: " · ", with: " and ")) stay as they are", false) }
            return ("Nothing is imported", false)
        case .assign:
            if one, let eps = r?.recommendedEpisodes { return ("Imports it as \(ManualImportRules.episodesLabel(eps))", false) }
            return ("Imports each file as the episodes it holds", false)
        case .rematch: return ("Moves \(one ? "it" : "each file") to the episode the title names; decide \(one ? "it" : "them") there", false)
        }
    }

    // MARK: Done

    /// The toast when Manual Import closes itself: "The Office S05: imported
    /// 23, kept 2 of yours" over "Download removed · Manual Import closed". No Undo.
    public static func doneToast(_ rows: [ManualImportRow], finish: FinishRescueResult?) -> (title: String, detail: String) {
        let imported = rows.filter(\.committed).count
        let skipped = rows.filter { !$0.committed && $0.existingFile == nil }.count
        let kept = rows.count - imported - skipped
        var parts: [String] = []
        if imported > 0 { parts.append("imported \(imported)") }
        if kept > 0 { parts.append("kept \(kept) of yours") }
        if skipped > 0 { parts.append("skipped \(skipped)") }
        let name = ManualImportDecide.downloadName(rows) ?? "Manual Import"
        let title = parts.isEmpty ? name : "\(name): \(parts.joined(separator: ", "))"
        let tail = finish.map(ManualImportDecide.finishDetail) ?? "download finished"
        return (title, tail.prefix(1).uppercased() + tail.dropFirst() + " · Manual Import closed")
    }
}
