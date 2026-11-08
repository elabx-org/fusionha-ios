import Foundation

/// Manual Import's Files list without the mouse (v2 S9 leftovers): a drag
/// down the tick column ticks (or unticks) every row it passes, and j/k
/// move a cursor row on an iPad keyboard. Rows are given in list order.
public enum MIRowSweep {
    /// The row under `y`: the one whose span holds it, else the nearest
    /// (above the first row is the first, below the last is the last).
    public static func row(at y: Double, ids: [Int], spans: [Int: ClosedRange<Double>]) -> Int? {
        var best: (id: Int, distance: Double)?
        for id in ids {
            guard let span = spans[id] else { continue }
            let distance = span.contains(y) ? 0 : min(abs(y - span.lowerBound), abs(y - span.upperBound))
            if best == nil || distance < best!.distance { best = (id, distance) }
            if distance == 0 { break }
        }
        return best?.id
    }

    /// The run from `anchor` to `target`, inclusive, in list order (either
    /// direction); empty when either is not in the list.
    public static func run(from anchor: Int, to target: Int, ids: [Int]) -> [Int] {
        guard let a = ids.firstIndex(of: anchor), let b = ids.firstIndex(of: target) else { return [] }
        return Array(ids[min(a, b)...max(a, b)])
    }

    /// The selection while sweeping: what was ticked when the drag began,
    /// with the run ticked (`on`) or unticked. `locked` rows (imported)
    /// never change.
    public static func selection(base: Set<Int>, run: [Int], on: Bool, locked: Set<Int> = []) -> Set<Int> {
        let swept = Set(run).subtracting(locked)
        return on ? base.union(swept) : base.subtracting(swept)
    }

    /// The cursor after j (`by` +1) or k (-1): from nothing, j lands on the
    /// first row and k on the last; it stops at either end.
    public static func step(_ cursor: Int?, by: Int, ids: [Int]) -> Int? {
        guard !ids.isEmpty else { return nil }
        guard let cursor, let index = ids.firstIndex(of: cursor) else { return by >= 0 ? ids.first : ids.last }
        return ids[min(max(index + by, 0), ids.count - 1)]
    }
}
