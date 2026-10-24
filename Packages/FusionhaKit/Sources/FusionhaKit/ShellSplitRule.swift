import Foundation

/// When the shell opens a title as a trailing column instead of a sheet, with
/// no fold in play (folded, flat open, any device without a hinge).
///
/// One rule with the web's foldable layout (`lib/fold/fold-geometry.ts`:
/// `SPLIT_MIN_WIDTH`, `SPLIT_MIN_HEIGHT`, `detailColumnWidth`), decided only
/// from the space the app has: never the device, its idiom, orientation or size
/// class. So a phone held sideways (wide but short) keeps its sheet, iPhone
/// Duo's outer display stays a phone, its inner display splits, and a window
/// shared with another app splits only while it is roomy enough.
///
/// Portrait-shaped containers never split (ruling Q-DC3, the HIG's horizontal
/// bars in inner portrait): at iPhone Duo's 669 x 951 the 560/360 rule left a
/// tabs column narrower than any iPhone, so there the tab bar stays at the
/// bottom and the title opens as the phone's sheet.
///
/// The same idea in landscape (D2b follow-up): when the column left beside the
/// title would be under `primaryMin` (360, a phone's width), the title opens
/// as the sheet instead of squeezing the tab's pane.
public enum ShellSplitRule {
    /// Below this width the title is a sheet (iPhone Duo's outer display is ~466pt).
    public static let minWidth = 560.0
    /// Below this height the title is a sheet (a phone in landscape is ~400pt).
    public static let minHeight = 500.0
    /// The title column's share of the width, and its bounds.
    public static let detailShare = 0.56
    public static let detailMin = 360.0
    public static let detailMax = 620.0
    /// The narrowest the tab's pane beside the title may be.
    public static let primaryMin = 360.0
    /// The hairline between the two columns.
    public static let divider = 1.0

    /// Whether a container this size shows the open title as a trailing column.
    public static func splits(width: Double, height: Double, hasItem: Bool) -> Bool {
        hasItem && width >= minWidth && height >= minHeight && width > height
            && primaryWidth(for: width) >= primaryMin
    }

    /// The tab's pane width beside the title column (and its hairline).
    public static func primaryWidth(for width: Double) -> Double {
        max(width - detailWidth(for: width) - divider, 0)
    }

    /// The title column's width in a container this wide.
    public static func detailWidth(for width: Double) -> Double {
        min(max(width * detailShare, detailMin), detailMax)
    }

    /// Where the split goes when a fold runs top to bottom through the
    /// container in book pose (flat open nothing is reserved, option A): `splits` still decides whether, this
    /// decides where.
    public struct FoldSplit: Equatable, Sendable {
        /// The tab's pane: it ends half a gutter before the fold.
        public var primary: Double
        /// The fold and the gutter around it, kept empty; the title column starts after it.
        public var gap: Double
    }

    /// The split at the fold (`fold`, its x-range; zero wide when flat): the
    /// tabs before it, the title after it, `gutter` around it. `nil` when the
    /// fold isn't inside the container or either side would be narrower than
    /// its minimum (then the web's split applies).
    public static func foldSplit(width: Double, fold: ClosedRange<Double>,
                                 gutter: Double = FoldColumns.gutter) -> FoldSplit? {
        guard let panes = FoldColumns.panes(width: width, fold: fold, minLead: primaryMin,
                                            minTrail: detailMin, gutter: gutter) else { return nil }
        return FoldSplit(primary: panes.lead, gap: panes.gap)
    }
}

/// When Settings shows its sidebar beside the open panel (the web's desktop
/// Settings) instead of the phone's push list. Ruling S2: the web's 720 of the
/// space Settings has, never the size class, so iPhone Duo's inner display in
/// portrait (669) keeps the phone list and only wider windows split.
public enum SettingsSplitRule {
    public static let minWidth = 720.0

    public static func splits(width: Double) -> Bool {
        width >= minWidth
    }
}
