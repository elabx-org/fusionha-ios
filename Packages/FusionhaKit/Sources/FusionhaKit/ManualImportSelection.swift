import Foundation

// The verdict strip's filters, the title blocks and the batch decisions, ported
// from the web's `routes/manual-import/filters.ts`, `group-rows.ts`,
// `selection.ts` and `medium-blocks.ts`.

/// The verdict strip's filter chips (`medium` is the Review filter and has no chip).
public enum ManualImportFilter: String, CaseIterable, Sendable, Hashable {
    case all, ready, attention, nomatch, diff, medium

    /// The five chips, in the web's order.
    public static let chips: [ManualImportFilter] = [.all, .ready, .attention, .nomatch, .diff]

    public var label: String {
        switch self {
        case .all: return "All"
        case .ready: return "Ready"
        case .attention: return "Needs attention"
        case .nomatch: return "No match"
        case .diff: return "Name ≠ file"
        case .medium: return "To confirm"
        }
    }

    /// `diff` counts every advisory name-vs-file disagreement, Ready rows included.
    public func matches(_ row: ManualImportRow) -> Bool {
        switch self {
        case .all: return true
        case .ready: return row.status == "ready"
        case .attention: return row.status == "needs_attention"
        case .nomatch: return row.status == "no_match"
        case .diff: return !(row.nameVsFile ?? []).isEmpty
        case .medium: return ManualImportBatch.confirmEligible(row)
        }
    }

    public static func counts(_ rows: [ManualImportRow]) -> [ManualImportFilter: Int] {
        Dictionary(uniqueKeysWithValues: allCases.map { key in (key, rows.filter(key.matches).count) })
    }
}

/// One title's files (the web's `Block`): matched titles in first-seen order, Unmatched last.
public struct ManualImportBlock: Sendable, Hashable, Identifiable {
    public let key: String
    public let itemId: Int?
    public let title: String
    public let year: Int?
    /// `movie`, `series`, or nil for Unmatched.
    public let kind: String?
    public let posterUrl: String?
    public let confidence: String
    public let alternative: ManualImportAlternative?
    public let rows: [ManualImportRow]
    public let tiers: [String]

    public var id: String { key }
    public var unmatched: Bool { itemId == nil }
    /// A medium/low title with a row the user hasn't vouched for: shows the "? medium" ask.
    public var needsConfirm: Bool {
        !unmatched && confidence != "high" && rows.contains(where: ManualImportBatch.confirmEligible)
    }

    public static func group(_ rows: [ManualImportRow]) -> [ManualImportBlock] {
        var order: [String] = []
        var byKey: [String: [ManualImportRow]] = [:]
        for row in rows {
            let key = row.match.itemId.map(String.init) ?? "none"
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(row)
        }
        order = order.filter { $0 != "none" } + order.filter { $0 == "none" }
        return order.compactMap { key in
            guard let group = byKey[key], let first = group.first else { return nil }
            let matched = key != "none"
            var tiers: [String] = []
            for tier in group.map(\.target.tier) where !tiers.contains(tier) { tiers.append(tier) }
            return ManualImportBlock(
                key: key, itemId: first.match.itemId,
                title: matched ? (first.match.title ?? first.parsed.title ?? "—") : "Unmatched",
                year: matched ? first.match.year : nil,
                kind: matched ? (first.target.isSeries ? "series" : "movie") : nil,
                posterUrl: first.match.posterUrl, confidence: first.match.confidence ?? "none",
                alternative: first.match.alternative, rows: group, tiers: tiers)
        }
    }

    /// "2019 · Series · 6 files · HD + 4K", or "3 files" for Unmatched.
    public var meta: String {
        let files = rows.count == 1 ? "1 file" : "\(rows.count) files"
        guard !unmatched else { return files }
        let kindLabel = kind == "movie" ? "Movie" : "Series"
        return "\(year.map(String.init) ?? "") · \(kindLabel) · \(files)\(tiers.count > 1 ? " · HD + 4K" : "")"
    }

    /// "Also matches Dark (2017) · Series".
    public var alternativeLine: String? {
        guard let alt = alternative else { return nil }
        return "Also matches \(alt.title)\(alt.year.map { " (\($0))" } ?? "") · \(alt.kind == "movie" ? "Movie" : "Series")"
    }
}

/// The batch decisions over a selection (the web's `selection.ts`).
public enum ManualImportBatch {

    public enum CheckState: Sendable, Equatable { case on, off, mixed, none }

    /// Any uncommitted row can be ticked; only importable rows import.
    public static func isPickable(_ row: ManualImportRow) -> Bool { !row.committed }

    /// Confirm applies: a matched medium/low row the user hasn't vouched for.
    public static func confirmEligible(_ row: ManualImportRow) -> Bool {
        !row.committed && row.match.itemId != nil && row.match.confidence != "high" && row.itemOverridden != true
    }

    /// Keep current / Import anyway apply: a folder-scan row that is not an upgrade over a
    /// current file with a known id (Import anyway is always bound to that file).
    public static func replaceEligible(_ row: ManualImportRow) -> Bool {
        !row.committed && row.held == nil && !ManualImportRules.titleBlocked(row)
            && row.existingFile?.mediaFileId != nil && row.existingFile?.verdict?.upgrade == false
    }

    /// Selected not-an-upgrade rows still waiting for their choice.
    public static func notAnUpgrade(_ rows: [ManualImportRow], selected: Set<Int>) -> [ManualImportRow] {
        rows.filter { selected.contains($0.rowId) && replaceEligible($0) && $0.replaceChoice == nil }
    }

    public static func checkState(_ rows: [ManualImportRow], selected: Set<Int>) -> CheckState {
        let pickable = rows.filter(isPickable)
        guard !pickable.isEmpty else { return .none }
        let on = pickable.filter { selected.contains($0.rowId) }.count
        return on == 0 ? .off : on == pickable.count ? .on : .mixed
    }

    /// Every pickable row of a block on, or (when all are already on) all off.
    public static func toggleBlock(_ rows: [ManualImportRow], selected: Set<Int>) -> Set<Int> {
        let ids = rows.filter(isPickable).map(\.rowId)
        let allOn = !ids.isEmpty && ids.allSatisfy(selected.contains)
        return allOn ? selected.subtracting(ids) : selected.union(ids)
    }

    /// The rows' shared value, "Mixed" when they differ, nil with no rows.
    public static func shared(_ rows: [ManualImportRow], _ pick: (ManualImportRow) -> String) -> String? {
        let values = Set(rows.map(pick))
        guard !values.isEmpty else { return nil }
        return values.count == 1 ? values.first : "Mixed"
    }
}
