import Foundation

// Manual Import grouped by problem (v2 slice S9, mock activity-mi.js). A held
// pack's files become a few cards, one per problem ("21 upgrades", "2 are
// shorter than yours", "2 share one file"). Every file sits in exactly one
// group: `problem` checks the problems in precedence order and the first
// that applies wins. Each group offers only the choices its files can take,
// and Fusionha's pick is shown only where the server states one
// (`recommended`); the client never guesses a pick.

/// What a file's group is about, in precedence order (the first that applies wins).
public enum MIProblem: String, CaseIterable, Sendable, Hashable, Identifiable {
    /// Already imported by this scan: nothing to decide.
    case imported
    /// No library title matched.
    case noMatch
    /// The library already holds this file (the server's `keep_current` pick,
    /// an `in_library` badge, or a title naming an episode that holds this release).
    case inLibrary
    /// The file's own title names another episode (`title_check.names_other`).
    case otherEpisode
    /// One file covers several episodes another file also fills (`would_orphan`).
    case sharedFile
    /// The file runs about two episodes (the server's `assign_episodes`).
    case twoEpisodes
    /// It runs clearly shorter than your copy (both runtimes probed).
    case shorter
    /// The probe measured something other than the name claims.
    case mislabeled
    /// Not better than your copy (`verdict.upgrade == false`).
    case notUpgrade
    /// Needs a look before it can import: no quality, an unvouched weak match, no episode.
    case needsLook
    /// Replaces your copy and is better.
    case upgrade
    /// Fills an empty slot.
    case new

    public var id: String { rawValue }

    /// The order the cards show in: what imports first, then the problems,
    /// then what is settled.
    public static let displayOrder: [MIProblem] = [
        .upgrade, .new, .shorter, .notUpgrade, .mislabeled, .otherEpisode, .twoEpisodes,
        .sharedFile, .needsLook, .noMatch, .inLibrary, .imported,
    ]
}

/// What one file does when the footer commits.
public enum MIChoice: String, CaseIterable, Sendable, Hashable, Identifiable {
    /// Import the file (over your copy only where the group says so).
    case importFile
    /// Keep your copy (a file with a copy on disk).
    case keep
    /// Import nothing for this file.
    case skip
    /// Assign the episodes the server recommends, then import.
    case assign
    /// Re-match to the episode the title names; the file is then decided on its new slot.
    case rematch

    public var id: String { rawValue }

    /// Imports a file (the footer's "Import N").
    public var imports: Bool { self == .importFile || self == .assign }
}

/// One card: a problem and its files, in scan order.
public struct MIGroup: Sendable, Equatable, Identifiable {
    public let problem: MIProblem
    public let rows: [ManualImportRow]
    public var id: MIProblem { problem }
    public var rowIds: [Int] { rows.map(\.rowId) }

    public init(problem: MIProblem, rows: [ManualImportRow]) {
        self.problem = problem
        self.rows = rows
    }
}

public enum MIProblemGrouping {

    // MARK: Problem

    /// The file's one group, by precedence.
    public static func problem(_ r: ManualImportRow) -> MIProblem {
        if r.committed { return .imported }
        if r.match.itemId == nil || r.status == "no_match" { return .noMatch }
        if inLibrary(r) { return .inLibrary }
        if ManualImportRules.titleBlocked(r) { return .otherEpisode }
        if r.wouldOrphan != nil { return .sharedFile }
        if r.recommended == "assign_episodes", (r.recommendedEpisodes?.count ?? 0) > 1 { return .twoEpisodes }
        if r.existingFile != nil, runtimes(r)?.shorter == true { return .shorter }
        if r.measured?.mislabeled == true, r.mismatchChoice == nil { return .mislabeled }
        if r.existingFile?.verdict?.upgrade == false { return .notUpgrade }
        if needsLook(r) { return .needsLook }
        return r.existingFile != nil ? .upgrade : .new
    }

    static func inLibrary(_ r: ManualImportRow) -> Bool {
        if ManualImportDecide.keepRecommended(r) { return true }
        if (r.badges ?? []).contains(where: { $0.code == "in_library" }) { return true }
        return r.titleCheck?.status == "names_other" && r.titleCheck?.sameReleaseExists == true
    }

    static func needsLook(_ r: ManualImportRow) -> Bool {
        if ManualImportBulk.ownBlockers(r) { return true }
        if r.match.confidence == "medium", r.itemOverridden != true { return true }
        let status = ManualImportRules.status(r)
        return status == .lowConfidence || status == .noEpisode
    }

    /// Both runtimes in whole minutes, when both files were probed. `shorter`
    /// when this file runs at least 15% and 3 minutes under your copy.
    public static func runtimes(_ r: ManualImportRow) -> (yours: Int, this: Int, shorter: Bool)? {
        guard let mine = r.existingFile?.probe?.runtimeSeconds, let theirs = r.probe?.runtimeSeconds,
              mine > 0, theirs > 0 else { return nil }
        let shorter = theirs < mine * 0.85 && mine - theirs >= 180
        return (Int((mine / 60).rounded()), Int((theirs / 60).rounded()), shorter)
    }

    // MARK: Groups

    /// The pack's cards, in display order; empty problems are left out.
    public static func groups(_ rows: [ManualImportRow]) -> [MIGroup] {
        let by = Dictionary(grouping: rows, by: problem)
        return MIProblem.displayOrder.compactMap { p -> MIGroup? in
            guard let rows = by[p], !rows.isEmpty else { return nil }
            return MIGroup(problem: p, rows: rows)
        }
    }

    // MARK: Choices

    /// Not importing: keep your copy when there is one, else skip.
    static func notImporting(_ r: ManualImportRow) -> MIChoice { r.existingFile != nil ? .keep : .skip }

    /// The file can import on its own: a match, a quality, a vouched match,
    /// and (outside a title block, which Import dismisses first) no shared file.
    static func canImport(_ r: ManualImportRow) -> Bool {
        guard ManualImportDecide.importAction(r) != nil, r.quality != nil else { return false }
        let unvouched = ["low", "none"].contains(r.match.confidence ?? "none") && r.itemOverridden != true
        return !unvouched
    }

    /// A shared file imports only with every file of its joint span.
    static func spanImports(_ r: ManualImportRow, _ rows: [ManualImportRow]) -> Bool {
        let span = r.jointRows ?? []
        guard r.match.itemId != nil, r.quality != nil, !span.isEmpty else { return false }
        let byId = Dictionary(rows.map { ($0.rowId, $0) }, uniquingKeysWith: { a, _ in a })
        return span.allSatisfy { id in
            guard let p = byId[id], !p.committed else { return false }
            return p.match.itemId != nil && p.quality != nil && !ManualImportRules.titleBlocked(p)
        }
    }

    /// What this file can take, in the order its card offers them.
    public static func options(_ r: ManualImportRow, rows: [ManualImportRow]) -> [MIChoice] {
        let not = notImporting(r)
        let imports = canImport(r)
        var out: [MIChoice] = []
        switch problem(r) {
        case .imported: break
        case .noMatch, .needsLook: out = [not]
        case .inLibrary: out = [.skip]
        case .otherEpisode:
            if ManualImportRules.rematchFields(r) != nil { out.append(.rematch) }
            out.append(not)
            if imports { out.append(.importFile) }
        case .sharedFile:
            if spanImports(r, rows) { out.append(.importFile) }
            out.append(not)
        case .twoEpisodes: out = [.assign, not]
        case .shorter, .mislabeled, .notUpgrade:
            out.append(not)
            if imports { out.append(.importFile) }
        case .upgrade, .new:
            if imports { out.append(.importFile) }
            out.append(not)
        }
        return out
    }

    /// Fusionha's pick for this file, only where the server states one.
    public static func pick(_ r: ManualImportRow, rows: [ManualImportRow]) -> MIChoice? {
        guard !r.committed else { return nil }
        let offered = options(r, rows: rows)
        let choice: MIChoice?
        switch r.recommended ?? "" {
        case "keep_current" where r.existingFile != nil: choice = problem(r) == .inLibrary ? .skip : .keep
        case "assign_episodes": choice = .assign
        case "rematch": choice = .rematch
        default: choice = nil
        }
        return choice.flatMap { offered.contains($0) ? $0 : nil }
    }

    /// Where a file starts: a choice the server already holds, else
    /// Fusionha's pick, else the server's own tick for a file that imports
    /// without replacing a better copy, else undecided.
    public static func initial(_ r: ManualImportRow, rows: [ManualImportRow]) -> MIChoice? {
        guard !r.committed else { return nil }
        let offered = options(r, rows: rows)
        if r.replaceChoice == "keep_current" {
            let held: MIChoice = problem(r) == .inLibrary ? .skip : notImporting(r)
            return offered.contains(held) ? held : offered.first { !$0.imports && $0 != .rematch }
        }
        if let pick = pick(r, rows: rows) { return pick }
        // Never over your copy by default: an "Import anyway" is always the owner's.
        if r.selected, ManualImportRules.isBulkSelectable(r), offered.contains(.importFile),
           ManualImportBulk.kind(r) != .down, !MICommitPlan.anyway.contains(problem(r)) {
            return .importFile
        }
        return nil
    }

    /// The same choice in this file's words: Keep yours on a file with no
    /// copy is Skip; nil when the file can't take it.
    public static func fit(_ choice: MIChoice, _ r: ManualImportRow, rows: [ManualImportRow]) -> MIChoice? {
        let offered = options(r, rows: rows)
        if offered.contains(choice) { return choice }
        if choice == .keep, offered.contains(.skip) { return .skip }
        if choice == .skip, offered.contains(.keep) { return .keep }
        return nil
    }

    /// Choices the group's card offers: every choice any of its files can take, in card order.
    public static func groupOptions(_ g: MIGroup, rows: [ManualImportRow]) -> [MIChoice] {
        var out: [MIChoice] = []
        for r in g.rows {
            for c in options(r, rows: rows) where !out.contains(c) { out.append(c) }
        }
        // Keep yours and Skip read as one "not importing" choice on a card of both kinds.
        if out.contains(.keep) && out.contains(.skip) { out.removeAll { $0 == .skip } }
        return out
    }

    /// The group's pick when the server states the same pick for every file
    /// of the card; nil when any file has none (no pick is ever guessed).
    public static func groupPick(_ g: MIGroup, rows: [ManualImportRow]) -> MIChoice? {
        let offered = groupOptions(g, rows: rows)
        var picks = Set<MIChoice>()
        for r in g.rows where !r.committed {
            guard let p = pick(r, rows: rows) else { return nil }
            picks.insert(offered.contains(p) ? p : p == .skip ? .keep : p == .keep ? .skip : p)
        }
        guard picks.count == 1, let only = picks.first, offered.contains(only) else { return nil }
        return only
    }
}
