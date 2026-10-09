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
public enum ShellSplitRule {
    /// Below this width the title is a sheet (iPhone Duo's outer display is ~466pt).
    public static let minWidth = 560.0
    /// Below this height the title is a sheet (a phone in landscape is ~400pt).
    public static let minHeight = 500.0
    /// The title column's share of the width, and its bounds.
    public static let detailShare = 0.56
    public static let detailMin = 360.0
    public static let detailMax = 620.0

    /// Whether a container this size shows the open title as a trailing column.
    public static func splits(width: Double, height: Double, hasItem: Bool) -> Bool {
        hasItem && width >= minWidth && height >= minHeight
    }

    /// The title column's width in a container this wide.
    public static func detailWidth(for width: Double) -> Double {
        min(max(width * detailShare, detailMin), detailMax)
    }
}
