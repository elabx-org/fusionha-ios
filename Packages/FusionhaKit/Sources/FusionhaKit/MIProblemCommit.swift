import Foundation

// What the grouped Manual Import's footer sends (v2 slice S9): the overrides
// a choice needs first (Import anyway bound to the copy on screen, a title
// check dismissed, the recommended episodes assigned, a re-match), then ONE
// all-or-nothing `POST /scan/{id}/decide` for every decided file.

public struct MICommitPlan: Sendable, Equatable {
    public struct Patch: Sendable, Equatable {
        public let rowId: Int
        public let fields: [String: SettingsJSON]
    }

    /// Overrides sent one at a time before the decide.
    public private(set) var patches: [Patch] = []
    /// The decide's rows.
    public private(set) var rows: [ManualImportDecideRequest.Row] = []
    /// Files whose import replaces a copy that is as good or better, or longer: asked first.
    public private(set) var replaces: [Int] = []
    /// Files that keep the copy on disk: their downloads take the disposition.
    public private(set) var kept: [Int] = []
    /// Files only re-matched: decided again on their new episode.
    public private(set) var rematched: [Int] = []

    public var isEmpty: Bool { patches.isEmpty && rows.isEmpty }
    public var imports: Bool { rows.contains { $0.action == .importFile } }

    /// Problems whose Import is an "Import anyway" over your copy.
    static let anyway: Set<MIProblem> = [.shorter, .notUpgrade, .mislabeled, .otherEpisode]

    public init(draft: MIDraft, rows all: [ManualImportRow]) {
        for r in all where !r.committed {
            guard let choice = draft.choice(r, rows: all) else { continue }
            let problem = MIProblemGrouping.problem(r)
            switch choice {
            case .importFile:
                if problem == .otherEpisode { patch(r, ["dismiss_episode_title": .bool(true)]) }
                if Self.anyway.contains(problem), r.existingFile != nil {
                    if ManualImportDecide.replaceConfirm(r) != nil { patch(r, ["replace_choice": .string("import")]) }
                    replaces.append(r.rowId)
                }
                rows.append(.init(rowId: r.rowId, action: .importFile))
            case .assign:
                let eps = r.recommendedEpisodes ?? []
                patch(r, ["episodes": .array(eps.map { .int($0) })])
                rows.append(.init(rowId: r.rowId, action: .importFile))
            case .rematch:
                if let fields = ManualImportRules.rematchFields(r) { patch(r, fields) }
                rematched.append(r.rowId)
            case .keep, .skip:
                // Already kept on the server: nothing changes, and a leave on it stands.
                if r.replaceChoice == "keep_current" { continue }
                if r.existingFile != nil {
                    rows.append(.init(rowId: r.rowId, action: .keepCurrent))
                    kept.append(r.rowId)
                } else {
                    rows.append(.init(rowId: r.rowId, action: .skip))
                }
            }
        }
    }

    private mutating func patch(_ r: ManualImportRow, _ fields: [String: SettingsJSON]) {
        patches.append(Patch(rowId: r.rowId, fields: fields))
    }

    /// The decide call; nil when no file is decided. The import mode goes
    /// only with an import, the dispositions only for kept files' downloads.
    public func request(dispositions: [Int: FinishDisposition], mode: ManualImportMode) -> ManualImportDecideRequest? {
        guard !rows.isEmpty else { return nil }
        return ManualImportDecideRequest(rows: rows, dispositions: kept.isEmpty ? [:] : dispositions,
                                         importMode: imports ? mode : nil)
    }
}

extension MIDraft.Counts {
    /// The footer's words: "Import 23 · keep 2 · skip 1", then what is left.
    public var footer: String {
        var parts: [String] = []
        if imports > 0 { parts.append("import \(imports)") }
        if keeps > 0 { parts.append("keep \(keeps)") }
        if skips > 0 { parts.append("skip \(skips)") }
        if rematches > 0 { parts.append("re-match \(rematches)") }
        if undecided > 0 { parts.append("\(undecided) to decide") }
        guard let first = parts.first else { return "Nothing to decide" }
        parts[0] = first.prefix(1).uppercased() + first.dropFirst()
        return parts.joined(separator: " · ")
    }
}
