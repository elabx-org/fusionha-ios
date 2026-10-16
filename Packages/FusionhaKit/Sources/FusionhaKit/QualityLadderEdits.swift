import Foundation

// Ladder mutations for the quality-profile editor (web quality-groups.ts):
// allow/disallow, group/ungroup, rename, and reorder. All pure.

extension QualityLadder {
    /// Allow or disallow one row (a standalone quality or a whole group) by row id.
    public static func setAllowed(_ rows: [QualityLadderRow], rowID: String, _ on: Bool) -> [QualityLadderRow] {
        rows.map { r in
            guard r.id == rowID else { return r }
            switch r {
            case .quality(var q): q.allowed = on; return .quality(q)
            case .group(var g): g.allowed = on; return .group(g)
            }
        }
    }

    public static func renameGroup(_ rows: [QualityLadderRow], id: String, _ name: String) -> [QualityLadderRow] {
        rows.map { r in
            guard case .group(var g) = r, g.id == id else { return r }
            g.name = name
            return .group(g)
        }
    }

    /// Pull a quality out of wherever it lives, dropping a group that empties.
    /// Returns the rows and the slot a replacement should go in.
    static func removeQuality(_ rows: [QualityLadderRow], _ quality: String) -> (rows: [QualityLadderRow], at: Int) {
        var out: [QualityLadderRow] = []
        var at = rows.count
        for r in rows {
            switch r {
            case .quality(let q):
                if q.quality == quality { at = out.count } else { out.append(r) }
            case .group(var g):
                if g.qualities.contains(quality) {
                    g.qualities.removeAll { $0 == quality }
                    if !g.qualities.isEmpty { out.append(.group(g)) }
                    at = out.count
                } else {
                    out.append(r)
                }
            }
        }
        return (out, at)
    }

    /// Group targets for `assign`: standalone, a fresh group, or an existing group id.
    public enum GroupTarget: Hashable, Sendable {
        case standalone
        case new
        case group(String)
    }

    /// Move a quality to a target. Landing standalone or seeding a new group keeps
    /// its allowed flag; joining a group inherits the group's. Returns the group it
    /// moved into (nil when it went standalone or nothing changed).
    public static func assign(_ rows: [QualityLadderRow], _ quality: String,
                              to target: GroupTarget) -> (rows: [QualityLadderRow], groupID: String?) {
        let wasAllowed = isAllowed(rows, quality)
        let source = groupOf(rows, quality)
        if target == .standalone && source == nil { return (rows, nil) }
        if let source, target == .group(source.id) { return (rows, nil) }
        let removed = removeQuality(rows, quality)
        var next = removed.rows
        switch target {
        case .new:
            let id = newGroupId()
            let g = QualityLadderGroup(id: id, name: nextGroupName(removed.rows), allowed: wasAllowed, qualities: [quality])
            next.insert(.group(g), at: min(removed.at, next.count))
            return (next, id)
        case .standalone:
            next.insert(.quality(QualityLadderQuality(quality: quality, allowed: wasAllowed)), at: min(removed.at, next.count))
            return (next, nil)
        case .group(let id):
            next = next.map { r in
                guard case .group(var g) = r, g.id == id else { return r }
                g.qualities.append(quality)
                return .group(g)
            }
            return (next, id)
        }
    }

    /// Dissolve a group: its members return as standalone rows, in place.
    public static func dissolve(_ rows: [QualityLadderRow], id: String) -> [QualityLadderRow] {
        rows.flatMap { r -> [QualityLadderRow] in
            guard case .group(let g) = r, g.id == id else { return [r] }
            return g.qualities.map { .quality(QualityLadderQuality(quality: $0, allowed: g.allowed)) }
        }
    }

    /// Swap a top-level row with its neighbour. No-op at the ends.
    public static func moveRow(_ rows: [QualityLadderRow], at index: Int, by delta: Int) -> [QualityLadderRow] {
        let j = index + delta
        guard rows.indices.contains(index), rows.indices.contains(j) else { return rows }
        var next = rows
        next.swapAt(index, j)
        return next
    }

    /// Swap two members within a group. No-op at the ends.
    public static func moveMember(_ rows: [QualityLadderRow], groupID: String, at index: Int, by delta: Int) -> [QualityLadderRow] {
        rows.map { r in
            guard case .group(var g) = r, g.id == groupID else { return r }
            let j = index + delta
            guard g.qualities.indices.contains(index), g.qualities.indices.contains(j) else { return r }
            g.qualities.swapAt(index, j)
            return .group(g)
        }
    }
}
