import Foundation

/// Column maths that keeps the iPhone Duo's fold in a gutter, flat open or
/// half open, so no column (a Board stage, a month's weekday) straddles it.
///
/// The fold is a reserved `.division` region running top to bottom. Flat open
/// it is inactive and zero wide; half open it is active and has a width. Either
/// way the layouts here leave `gutter` around it (half each side, the device
/// kit's 40 pt fold gutter) and keep their columns out of that gap.
public enum FoldColumns {
    /// The gap kept around the fold: 20 pt each side of it.
    public static let gutter = 40.0

    /// One column: its leading x and its width, in the container's coordinates.
    public struct Track: Equatable, Sendable {
        public var x: Double
        public var width: Double
        public var maxX: Double { x + width }

        public init(x: Double, width: Double) {
            self.x = x
            self.width = width
        }
    }

    /// The gap the columns keep clear: the fold plus half the gutter each side.
    public static func gap(around fold: ClosedRange<Double>, gutter: Double = gutter) -> ClosedRange<Double> {
        (fold.lowerBound - gutter / 2)...(fold.upperBound + gutter / 2)
    }

    /// Two panes meeting at the fold: the leading one ends half a gutter before
    /// it, the trailing one starts half a gutter after it.
    public struct Panes: Equatable, Sendable {
        public var lead: Double
        /// The fold and its gutter, between the panes.
        public var gap: Double
    }

    /// Two panes split at `fold` (its x-range in a container `width` wide).
    /// `nil` when either pane would be under its minimum: keep the usual split.
    public static func panes(width: Double, fold: ClosedRange<Double>, minLead: Double, minTrail: Double,
                             gutter: Double = gutter) -> Panes? {
        let gap = gap(around: fold, gutter: gutter)
        guard gap.lowerBound >= minLead, width - gap.upperBound >= minTrail else { return nil }
        return Panes(lead: gap.lowerBound, gap: gap.upperBound - gap.lowerBound)
    }

    /// `count` columns across `width`, split into a leading group before `gap`
    /// and a trailing group after it, equal widths inside each group and
    /// `spacing` between neighbours. The split is the one whose two column
    /// widths are closest (ties go to the smaller leading group, so a centred
    /// fold splits five as 2 | 3 and seven as 3 | 4). `nil` when the gap isn't
    /// inside the container or a column would have no width: lay out as usual.
    public static func split(count: Int, width: Double, spacing: Double, gap: ClosedRange<Double>) -> [Track]? {
        guard count >= 2, gap.lowerBound > 0, gap.upperBound < width else { return nil }
        let lead = gap.lowerBound
        let trail = width - gap.upperBound
        guard let k = leadingCount(count: count, lead: lead, trail: trail, spacing: spacing) else { return nil }
        let leadWidth = groupWidth(lead, columns: k, spacing: spacing)
        let trailWidth = groupWidth(trail, columns: count - k, spacing: spacing)
        var tracks: [Track] = []
        for i in 0..<k {
            tracks.append(Track(x: Double(i) * (leadWidth + spacing), width: leadWidth))
        }
        for i in 0..<(count - k) {
            tracks.append(Track(x: gap.upperBound + Double(i) * (trailWidth + spacing), width: trailWidth))
        }
        return tracks
    }

    /// How many of `count` columns go before the gap: the split with the
    /// closest column widths either side. `nil` when no split leaves every
    /// column a positive width.
    public static func leadingCount(count: Int, lead: Double, trail: Double, spacing: Double) -> Int? {
        guard count >= 2 else { return nil }
        var best: (k: Int, diff: Double)?
        for k in 1..<count {
            let l = groupWidth(lead, columns: k, spacing: spacing)
            let r = groupWidth(trail, columns: count - k, spacing: spacing)
            guard l > 0, r > 0 else { continue }
            let diff = abs(l - r)
            if best == nil || diff < best!.diff - 1e-9 { best = (k, diff) }
        }
        return best?.k
    }

    /// Columns that scroll sideways a page at a time (the Board when five
    /// stages don't fit): each page holds `perPage` columns filling exactly the
    /// space before the gap, so at every resting position a page ends at the
    /// gap and the next starts after it. As many columns per page as fit at
    /// `minimum` (at least one, at most `count`).
    public struct Pages: Equatable, Sendable {
        public var perPage: Int
        public var columnWidth: Double
        /// One page's width: the space before the gap.
        public var pageWidth: Double
        /// From one page's leading edge to the next: the page plus the gap.
        public var stride: Double
        public var pageCount: Int
        public var count: Int
        public var spacing: Double

        /// Every column's place: page `i / perPage`, slot `i % perPage`.
        public var tracks: [Track] {
            (0..<count).map { i in
                let page = Double(i / perPage), slot = Double(i % perPage)
                return Track(x: page * stride + slot * (columnWidth + spacing), width: columnWidth)
            }
        }

        /// The scrolling content's width in a `viewport` this wide: long enough
        /// that the last page can rest on the leading side, so every resting
        /// offset is a whole number of strides.
        public func contentWidth(viewport: Double) -> Double {
            max(Double(pageCount - 1) * stride + viewport, pageWidth)
        }

        /// The furthest resting offset: the last page on the leading side.
        public var lastOffset: Double { Double(pageCount - 1) * stride }
    }

    public static func pages(count: Int, gap: ClosedRange<Double>, minimum: Double, spacing: Double) -> Pages? {
        let lead = gap.lowerBound
        guard count >= 1, lead > 0 else { return nil }
        let fit = Int(((lead + spacing) / (minimum + spacing)).rounded(.down))
        let perPage = min(max(fit, 1), count)
        let width = groupWidth(lead, columns: perPage, spacing: spacing)
        guard width > 0 else { return nil }
        let pageCount = (count + perPage - 1) / perPage
        return Pages(perPage: perPage, columnWidth: width, pageWidth: lead,
                     stride: gap.upperBound, pageCount: pageCount, count: count, spacing: spacing)
    }

    /// `count` equal columns, at least `minimum` wide, filling `width` when
    /// they fit (the web's Board without a fold); wider content scrolls.
    public static func even(count: Int, width: Double, spacing: Double, minimum: Double) -> [Track] {
        guard count > 0 else { return [] }
        let w = max(minimum, groupWidth(width, columns: count, spacing: spacing))
        return (0..<count).map { Track(x: Double($0) * (w + spacing), width: w) }
    }

    /// The width of each of `columns` equal columns filling `space` with `spacing` between them.
    static func groupWidth(_ space: Double, columns: Int, spacing: Double) -> Double {
        guard columns > 0 else { return 0 }
        return (space - Double(columns - 1) * spacing) / Double(columns)
    }
}
