import Foundation

/// The web's width rules, decided on the width a pane actually gets (rulings
/// L17, R4 and S2), never the device, its size class or orientation. On iPhone
/// Duo's inner display that is about 669 in portrait and 951 in landscape, so
/// portrait keeps the phone layouts and landscape crosses the web's 720 into
/// its desktop layouts (ruling Q-DC3, which re-rules A1 there).
public enum PaneRule {
    /// The web's `useIsMobile` (`max-width: 720px`): 720 and under is the phone.
    public static let phoneMax = 720.0

    /// Above 720: the web's desktop layout.
    public static func isDesktop(_ width: Double) -> Bool {
        width > phoneMax
    }

    /// The web's split-capable touch screen (`ShellSplitRule`, 560 x 500).
    public static func splitCapable(width: Double, height: Double) -> Bool {
        width >= ShellSplitRule.minWidth && height >= ShellSplitRule.minHeight
    }

    /// `repeat(auto-fit|auto-fill, minmax(min, 1fr))` with `gap`: how many
    /// columns fit, at least one. `items` caps it the way auto-fit collapses
    /// empty tracks (pass nil for auto-fill).
    public static func autoColumns(width: Double, min: Double, gap: Double, items: Int? = nil) -> Int {
        guard width > 0, min > 0 else { return 1 }
        let fit = Swift.max(1, Int(((width + gap) / (min + gap)).rounded(.down)))
        guard let items else { return fit }
        return Swift.max(1, Swift.min(fit, items))
    }

    /// Columns for `items` tiles that never leave a lone tile on the last row
    /// (5 tiles at 4 across become 3 + 2), and never more than fit.
    public static func balancedColumns(fitting columns: Int, items: Int) -> Int {
        guard items > 0, columns > 1 else { return Swift.max(1, columns) }
        let cols = Swift.min(columns, items)
        let rows = (items + cols - 1) / cols
        return (items + rows - 1) / rows
    }
}

/// Activity › Queue on iPhone Duo (web `queue/duo/use-queue-duo.ts`): a tapped
/// card opens as a trailing column beside the list, on a split-capable screen
/// still in the phone layout (the inner display in portrait). Above 720 the
/// desktop card layout takes over and cards open the title as before.
public enum QueueDuoRule {
    /// The list | card columns (mock v4 "Duo · 669": 294 | 375).
    public static let listShare = 44.0 / 100.0

    public static func splits(width: Double, height: Double) -> Bool {
        !PaneRule.isDesktop(width) && PaneRule.splitCapable(width: width, height: height)
    }

    /// The queue card's own desktop grid (`@container queuecard (min-width: 720px)`):
    /// poster column, title + actions on one row, body beneath.
    public static func cardIsWide(_ cardWidth: Double) -> Bool {
        cardWidth >= 720
    }
}

/// Manual Import's layout (web `useManualImportLayout.ts`), from the sheet's
/// own width (ruling R4): the split on a split-capable screen at 720 and
/// under, the desktop table above it, phone cards otherwise.
public enum ManualImportLayout: String, Sendable, Equatable {
    case cards, split, table

    public static func mode(width: Double, height: Double) -> ManualImportLayout {
        if PaneRule.isDesktop(width) { return .table }
        return PaneRule.splitCapable(width: width, height: height) ? .split : .cards
    }

    /// The open iPhone Duo: the split's list before the fold's gutter, the
    /// file (or the decision panel) after it. `nil` without a fold inside, or
    /// when a pane would be too narrow: the usual layout by size.
    public static func foldPanes(width: Double, fold: ClosedRange<Double>?) -> FoldColumns.Panes? {
        guard let fold else { return nil }
        return FoldColumns.panes(width: width, fold: fold, minLead: 300, minTrail: 320)
    }

    /// Option A: book pose splits at the fold (`foldPanes`); flat open nothing
    /// is reserved, so the sheet keeps its own list | file split by size, with
    /// no fold gutter. `fold` is the open Duo's fold, active or not.
    public static func duoPanes(width: Double, fold: ClosedRange<Double>?, posture: DuoPosture?) -> FoldColumns.Panes? {
        guard posture?.reservesFold == true else { return nil }
        return foldPanes(width: width, fold: fold)
    }

    /// The table drops Audio and Group · service under 1100 (`COLUMNS_NARROW`).
    public static func tableIsNarrow(_ width: Double) -> Bool {
        width < 1100
    }
}

/// Discover's widths (web `Rail.module.css`, `DiscoverBrowseControls.module.css`,
/// `DiscoverFilters.module.css`), on the page's own width.
public enum DiscoverWidthRule {
    /// A rail cell: 158 on desktop, 128 to 720, 116 on phones (540 and under).
    public static func cellWidth(_ width: Double) -> Double {
        if PaneRule.isDesktop(width) { return 158 }
        return width > 540 ? 128 : 116
    }

    /// Browse's kind lens, search and "Add as" on one row (`min-width: 721px`).
    public static func controlsOneRow(_ width: Double) -> Bool {
        PaneRule.isDesktop(width)
    }

    /// The filter fields: `repeat(auto-fit, minmax(150px, 1fr))`, 12 apart.
    public static func filterColumns(_ width: Double, fields: Int) -> Int {
        PaneRule.autoColumns(width: width, min: 150, gap: 12, items: fields)
    }

    /// The request modal's art | options panes (`grid-template-columns: 300px 1fr` above 720).
    public static func requestTwoPanes(_ width: Double) -> Bool {
        PaneRule.isDesktop(width)
    }
}
