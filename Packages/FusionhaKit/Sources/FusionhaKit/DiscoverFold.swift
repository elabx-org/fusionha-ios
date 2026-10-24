import Foundation

/// Discover, Search and the Add / Request modals on the iPhone Duo, open:
/// where each piece goes so nothing sits on the fold, in a Spread and in the
/// Web layout ("either mode: nothing on the fold"). Pure maths: the app reads
/// the fold (`FoldInfo`) in each container's own coordinates and lays out
/// with these. Without a fold inside the container every answer is the usual
/// layout.
public enum DiscoverFold {
    // MARK: Browse's controls

    /// Browse's kind lens, search and "Add as".
    public enum Controls: Equatable, Sendable {
        /// Stacked: the phone's layout, and a Spread's left page.
        case stacked
        /// One row, the search growing between the lens and "Add as" (the web's 721+).
        case oneRow
        /// The fold runs through the row: the lens before it, the search and
        /// "Add as" after it.
        case split(FoldColumns.Panes)
    }

    /// The lens's room (four segments) and the search's, either side of the fold.
    public static let minLensPane = 300.0
    public static let minSearchPane = 260.0

    /// The controls' arrangement in a row `width` wide with the fold at `fold`.
    public static func controls(width: Double, fold: ClosedRange<Double>?) -> Controls {
        guard DiscoverWidthRule.controlsOneRow(width) else { return .stacked }
        guard let fold, fold.lowerBound > 0, fold.upperBound < width else { return .oneRow }
        if let panes = FoldColumns.panes(width: width, fold: fold, minLead: minLensPane, minTrail: minSearchPane) {
            return .split(panes)
        }
        return .stacked
    }

    // MARK: Rails

    /// A rail cell's width: the web's rule for the page's width, or, while
    /// Browse spans a Spread, for one page (the cards a page holds, not 158s
    /// sized for the whole spread).
    public static func railCell(paneWidth: Double, spanPage: Double?) -> Double {
        DiscoverWidthRule.cellWidth(spanPage ?? paneWidth)
    }

    /// A rail with the fold inside its viewport (`viewport` wide, the fold at
    /// `fold` in its coordinates): cards in pages that each end before the
    /// fold's gutter, scrolling a page at a time, so no card rests on the fold.
    /// The cards per page are the count whose width comes closest to `cell`
    /// (never under 80 % of it), so a page holds 3 of the web's 158s at 129
    /// rather than 2 stretched to 200. `fixed` cards keep their own width, so
    /// a page holds only as many as fit whole. `nil` without a fold inside.
    public static func railPages(count: Int, viewport: Double, fold: ClosedRange<Double>?, cell: Double,
                                 spacing: Double, fixed: Bool = false,
                                 gutter: Double = FoldColumns.gutter) -> FoldColumns.Pages? {
        guard count > 0, cell > 0, let fold, fold.lowerBound > 0, fold.upperBound < viewport else { return nil }
        let gap = FoldColumns.gap(around: fold, gutter: gutter)
        let lead = gap.lowerBound
        guard lead >= cell else { return nil }
        let whole = fit(lead, minimum: cell, spacing: spacing)
        var perPage = whole
        if !fixed {
            let width = { (k: Int) in FoldColumns.groupWidth(lead, columns: k, spacing: spacing) }
            let more = whole + 1
            if width(more) >= cell * 0.8, abs(width(more) - cell) < abs(width(whole) - cell) { perPage = more }
        }
        // The page's column width, a hair under so the page holds exactly `perPage`.
        let minimum = FoldColumns.groupWidth(lead, columns: perPage, spacing: spacing) - 0.01
        return FoldColumns.pages(count: count, gap: gap, minimum: minimum, spacing: spacing)
    }

    // MARK: Grids

    /// The filter fields (`repeat(auto-fit, minmax(150px, 1fr))`, 12 apart)
    /// across a panel `width` wide with the fold at `fold`: as many fields as
    /// fit each side of the fold's gutter, at least 150 each, so no field
    /// straddles it. `nil` without a fold inside (lay out as usual).
    public static func fieldTracks(fields: Int, width: Double, fold: ClosedRange<Double>?,
                                   minimum: Double = 150, spacing: Double = 12,
                                   gutter: Double = FoldColumns.gutter) -> [FoldColumns.Track]? {
        guard fields >= 2, let fold, fold.lowerBound > 0, fold.upperBound < width else { return nil }
        let gap = FoldColumns.gap(around: fold, gutter: gutter)
        let lead = fit(gap.lowerBound, minimum: minimum, spacing: spacing)
        let trail = fit(width - gap.upperBound, minimum: minimum, spacing: spacing)
        guard lead >= 1, trail >= 1 else { return nil }
        let count = min(fields, lead + trail)
        return FoldColumns.split(count: count, width: width, spacing: spacing, gap: gap,
                                 leading: min(lead, count - 1))
    }

    /// How many columns of at least `minimum` fit in `space`.
    static func fit(_ space: Double, minimum: Double, spacing: Double) -> Int {
        guard space >= minimum else { return 0 }
        return Int(((space + spacing) / (minimum + spacing)).rounded(.down))
    }

    // MARK: Modals

    /// Where a modal goes while the Duo is open with a top-to-bottom fold.
    public enum ModalPlacement: Equatable, Sendable {
        /// One page: the Spread's right page (the Add sheet, a preview, a trailer).
        case rightPage
        /// Both pages: the content splits itself at the fold (the request
        /// modal: the title on the left page, the options on the right).
        case twoPages
    }

    /// The frame a modal sits in, in a window-sized container `width` wide
    /// with the fold at `fold`: the right page (from the fold's gutter to the
    /// trailing edge) or the whole width. `nil` without room for two pages
    /// (present it as the usual sheet).
    /// Flat (`posture`), the right page is the detail's two thirds (`DuoSplit`).
    public static func modalTrack(_ placement: ModalPlacement, width: Double,
                                  fold: ClosedRange<Double>?, posture: DuoPosture = .book) -> FoldColumns.Track? {
        guard let fold, let pages = DuoSplit.pages(width: width, fold: fold, posture: posture) else { return nil }
        switch placement {
        case .rightPage: return pages.right
        case .twoPages: return FoldColumns.Track(x: 0, width: width)
        }
    }

    /// The request modal's two panes across the fold: the title's art and
    /// summary before it, the options after it. `nil`: no fold inside, keep
    /// the web's 300 | 1fr (or one column).
    public static func requestPanes(width: Double, fold: ClosedRange<Double>?) -> FoldColumns.Panes? {
        guard let fold else { return nil }
        return FoldColumns.panes(width: width, fold: fold, minLead: 260, minTrail: 320)
    }
}
