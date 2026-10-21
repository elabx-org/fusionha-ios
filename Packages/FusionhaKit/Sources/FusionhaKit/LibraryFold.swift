import Foundation

/// The Library's pieces around a top-to-bottom fold (iPhone Duo, open), in
/// both "iPhone Duo, open" layouts: nothing sits on the fold. Each function
/// takes the piece's own width and the fold in its coordinates (`nil`: no fold
/// inside the piece, lay it out as usual) and says where it splits.
///
/// - Spread: a span puts the header pieces in `FoldSpanRow` halves and the grid
///   on `PosterTracks`, so no piece has the fold inside it; with a title open
///   the Library is the left page and never sees the fold.
/// - Web layout: the desktop Library runs across both halves, so the filter
///   field stops at the fold, the pulse ribbon and the one-row toolbar become
///   two pieces meeting at the gutter, the A–Z and status rules break at it
///   and the compact table's rows split there.
public enum LibraryFold {
    /// The narrowest a piece either side of the fold may be, per element.
    public static let ribbonMin = (lead: 300.0, trail: 200.0)
    public static let toolbarMin = (lead: 280.0, trail: 180.0)
    public static let tableMin = (lead: 200.0, trail: 236.0)

    /// A piece that splits into two at the fold.
    public enum Piece: Sendable {
        case ribbon, toolbar, table
    }

    /// `piece`'s two halves (`ribbon`, `toolbar`, `table`).
    public static func panes(_ piece: Piece, width: Double, fold: ClosedRange<Double>?) -> FoldColumns.Panes? {
        switch piece {
        case .ribbon: return ribbon(width: width, fold: fold)
        case .toolbar: return toolbar(width: width, fold: fold)
        case .table: return table(width: width, fold: fold)
        }
    }

    /// The filter field's width: it ends half a gutter before the fold.
    public static func filterWidth(width: Double, fold: ClosedRange<Double>?) -> Double? {
        gap(width: width, fold: fold)?.lowerBound
    }

    /// The pulse ribbon as two cards (status pills and kinds | meters).
    public static func ribbon(width: Double, fold: ClosedRange<Double>?) -> FoldColumns.Panes? {
        panes(width: width, fold: fold, min: ribbonMin)
    }

    /// The desktop toolbar as two pieces (Select, tier, recency | the rest).
    public static func toolbar(width: Double, fold: ClosedRange<Double>?) -> FoldColumns.Panes? {
        panes(width: width, fold: fold, min: toolbarMin)
    }

    /// The compact table's rows as two pieces (poster and title | versions,
    /// size, monitor), each with its own card edge.
    public static func table(width: Double, fold: ClosedRange<Double>?) -> FoldColumns.Panes? {
        panes(width: width, fold: fold, min: tableMin)
    }

    /// The room a header's hairline leaves empty (the fold and its gutter).
    public static func gap(width: Double, fold: ClosedRange<Double>?) -> ClosedRange<Double>? {
        guard let fold else { return nil }
        let gap = FoldColumns.gap(around: fold)
        guard gap.lowerBound > 0, gap.upperBound < width else { return nil }
        return gap
    }

    private static func panes(width: Double, fold: ClosedRange<Double>?,
                              min: (lead: Double, trail: Double)) -> FoldColumns.Panes? {
        guard let fold else { return nil }
        return FoldColumns.panes(width: width, fold: fold, minLead: min.lead, minTrail: min.trail)
    }
}

extension SpreadGeometry {
    /// Whether the tab bar's bottom accessory (the downloads bar) would run
    /// across the fold: the tabs' column, `tabsWidth` wide from the shell's
    /// leading edge, has the top-to-bottom fold inside it. True for a Spread
    /// span and the Web layout with nothing open; false once a title takes
    /// the right page or column (the bar is on the left then).
    public static func tabsCrossFold(tabsWidth: Double, fold: ClosedRange<Double>?) -> Bool {
        guard let fold else { return false }
        return fold.lowerBound > 0 && fold.upperBound < tabsWidth
    }
}
