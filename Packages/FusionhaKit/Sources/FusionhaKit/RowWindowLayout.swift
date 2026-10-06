import Foundation

/// Window-virtualization math for the Library A–Z grid, mirroring the web's
/// `routes/library-virtual.ts`: every row has a known height and a cumulative
/// `y`, so a jump scrolls to an exact offset and only the rows inside the
/// viewport (plus overscan) are ever rendered. Pure, so it is unit-tested here.
public struct RowWindowLayout: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public let id: String
        public let y: Double
        public let height: Double
        public var maxY: Double { y + height }
    }

    public private(set) var rows: [Row] = []
    public private(set) var totalHeight: Double = 0
    private var indexById: [String: Int] = [:]

    public init() {}

    /// Stacks rows of the given heights top to bottom.
    public init(_ entries: [(id: String, height: Double)]) {
        var y = 0.0
        rows.reserveCapacity(entries.count)
        for (i, entry) in entries.enumerated() {
            let h = max(0, entry.height)
            rows.append(Row(id: entry.id, y: y, height: h))
            indexById[entry.id] = i
            y += h
        }
        totalHeight = y
    }

    public static func == (a: Self, b: Self) -> Bool { a.rows == b.rows }

    public func index(of id: String) -> Int? { indexById[id] }

    /// The half-open range of rows intersecting `top..<bottom` (grid space),
    /// both edges widened by `overscan`. Binary-searched; clamped to the rows.
    public func range(top: Double, bottom: Double, overscan: Double) -> Range<Int> {
        guard !rows.isEmpty else { return 0..<0 }
        let start = firstRow(endingAfter: top - overscan)
        let end = max(start, firstRow(startingAtOrAfter: bottom + overscan))
        return start..<end
    }

    /// The rows a viewport of `height` shows when `index` sits at its top.
    public func range(landingAt index: Int, viewport height: Double, overscan: Double) -> Range<Int> {
        guard rows.indices.contains(index) else { return 0..<0 }
        let top = rows[index].y
        return range(top: top, bottom: top + height, overscan: overscan)
    }

    /// The first row whose bottom edge is below `top`.
    private func firstRow(endingAfter top: Double) -> Int {
        var lo = 0, hi = rows.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if rows[mid].maxY > top { hi = mid } else { lo = mid + 1 }
        }
        return lo
    }

    /// The first row whose top edge is at or beyond `bottom`.
    private func firstRow(startingAtOrAfter bottom: Double) -> Int {
        var lo = 0, hi = rows.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if rows[mid].y >= bottom { hi = mid } else { lo = mid + 1 }
        }
        return lo
    }
}

/// Grid row heights by coverage-rail count ("slots"), the web's
/// `rowH + railExtra(slots)`: each row is as tall as its own tallest card.
/// Heights are learned from rows as they render (the tallest seen per slot
/// count); until then they are estimated from the card width.
public struct GridRowHeights: Equatable, Sendable {
    /// Height per extra stacked rail before two slot counts have been measured.
    public static let defaultRailPitch = 20.0

    /// The card width these heights are for; a new width starts over.
    public private(set) var cardWidth: Double
    public private(set) var measured: [Int: Double] = [:]

    public init(cardWidth: Double = 0) { self.cardWidth = cardWidth }

    /// Records a rendered row's natural height. Returns true when it changed
    /// the model (a new slot count, or a row taller by more than half a point).
    @discardableResult
    public mutating func observe(slots: Int, height: Double) -> Bool {
        let s = max(1, slots)
        guard height > 0 else { return false }
        if let old = measured[s], height <= old + 0.5 { return false }
        measured[s] = height
        return true
    }

    /// Starts over for a new card width.
    public mutating func reset(cardWidth: Double) {
        guard abs(cardWidth - self.cardWidth) >= 0.5 else { return }
        self.cardWidth = cardWidth
        measured = [:]
    }

    /// The extra height per stacked rail, from two measured slot counts.
    public var railPitch: Double {
        let known = measured.keys.sorted()
        guard let lo = known.first, let hi = known.last, hi > lo,
              let a = measured[lo], let b = measured[hi] else { return Self.defaultRailPitch }
        return max(0, (b - a) / Double(hi - lo))
    }

    /// The row height for `slots` rails.
    public func height(slots: Int) -> Double {
        let s = max(1, slots)
        if let h = measured[s] { return h }
        let pitch = railPitch
        if let nearest = measured.keys.min(by: { abs($0 - s) < abs($1 - s) }), let h = measured[nearest] {
            return h + Double(s - nearest) * pitch
        }
        // 2:3 poster, title + meta block, one rail, 18pt row gap.
        return cardWidth * 1.5 + 66 + Double(s - 1) * pitch + 18
    }
}
