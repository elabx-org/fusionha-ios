import Foundation

// The choices made on the grouped Manual Import before the footer commits
// them (v2 slice S9). A group's choice never replaces a choice made on one
// of its files: the file's own choice wins and the card reads "Mixed" until
// "Use for every file" clears the files' own choices on purpose (risk 12).

public struct MIDraft: Sendable, Equatable {
    /// A card's choice, set on the card.
    public private(set) var group: [MIProblem: MIChoice] = [:]
    /// A file's own choice, set on the file; it outranks its card's.
    public private(set) var file: [Int: MIChoice] = [:]

    public init() {}

    /// What the file does: its own choice, else its card's (in its words),
    /// else where it started (`MIProblemGrouping.initial`).
    public func choice(_ r: ManualImportRow, rows: [ManualImportRow]) -> MIChoice? {
        if r.committed { return nil }
        if let own = file[r.rowId] { return own }
        if let g = group[MIProblemGrouping.problem(r)], let fitted = MIProblemGrouping.fit(g, r, rows: rows) {
            return fitted
        }
        return MIProblemGrouping.initial(r, rows: rows)
    }

    /// Sets the card's choice; files with their own choice keep it.
    public mutating func setGroup(_ problem: MIProblem, _ choice: MIChoice) {
        group[problem] = choice
    }

    /// Sets the card's choice and clears its files' own choices.
    public mutating func setEveryFile(_ g: MIGroup, _ choice: MIChoice) {
        group[g.problem] = choice
        for r in g.rows { file[r.rowId] = nil }
    }

    /// One file's own choice. A shared file takes its whole joint span with
    /// it, so the files of one library file always import (or not) together.
    public mutating func setFile(_ r: ManualImportRow, _ choice: MIChoice, rows: [ManualImportRow]) {
        file[r.rowId] = choice
        guard MIProblemGrouping.problem(r) == .sharedFile else { return }
        for id in r.jointRows ?? [] {
            guard let p = rows.first(where: { $0.rowId == id }) else { continue }
            file[id] = MIProblemGrouping.fit(choice, p, rows: rows)
        }
    }

    /// Fusionha's pick for every file that has one (the Decide menu's first item).
    public mutating func usePicks(_ targets: [ManualImportRow], rows: [ManualImportRow]) {
        for r in targets {
            if let p = MIProblemGrouping.pick(r, rows: rows) { file[r.rowId] = p }
        }
    }

    /// Drops choices for files that are gone or imported.
    public mutating func prune(_ rows: [ManualImportRow]) {
        let open = Set(rows.filter { !$0.committed }.map(\.rowId))
        file = file.filter { open.contains($0.key) }
    }

    // MARK: Reading a card

    public enum GroupState: Sendable, Equatable {
        /// Every open file does the same (nil: undecided).
        case uniform(MIChoice?)
        /// The files differ; `overridden` are the files whose own choice differs from the card's.
        case mixed(overridden: [Int])
    }

    public func state(_ g: MIGroup, rows: [ManualImportRow]) -> GroupState {
        let open = g.rows.filter { !$0.committed }
        let choices = open.map { choice($0, rows: rows) }
        let normal = Set(choices.map { $0 == .skip ? MIChoice.keep : $0 })
        if normal.count <= 1 {
            // Keep and Skip on one card of both kinds read as one choice.
            let shown = choices.first ?? nil
            let both = Set(choices).count > 1
            return .uniform(both ? .keep : shown)
        }
        let cardChoice = group[g.problem]
        let overridden = open.filter { r in
            guard let own = file[r.rowId] else { return false }
            return cardChoice.flatMap { MIProblemGrouping.fit($0, r, rows: rows) } != own
        }
        return .mixed(overridden: overridden.map(\.rowId))
    }

    // MARK: Counting

    public struct Counts: Sendable, Equatable {
        public var imports = 0
        public var keeps = 0
        public var skips = 0
        public var rematches = 0
        public var undecided = 0

        public var decided: Int { imports + keeps + skips + rematches }
    }

    /// The open files by what they do (imported files are not counted).
    public func counts(_ rows: [ManualImportRow]) -> Counts {
        var c = Counts()
        for r in rows where !r.committed {
            switch choice(r, rows: rows) {
            case .importFile?, .assign?: c.imports += 1
            case .keep?: c.keeps += 1
            case .skip?: c.skips += 1
            case .rematch?: c.rematches += 1
            case nil: c.undecided += 1
            }
        }
        return c
    }
}
