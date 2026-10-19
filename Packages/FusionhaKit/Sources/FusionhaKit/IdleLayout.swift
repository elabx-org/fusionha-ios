import Foundation

// MARK: - Queue clear layout (web `QueueIdle.module.css` container queries + `balanceLayout`)
//
// Decided from the width the view actually gets (the web's `queueidle` size
// container), never the device: a folded Duo or a phone is `.phone`, the
// unfolded Duo / iPad list pane is `.medium` or `.wide`.

public enum IdleLayout {
    /// `≤ 680` the phone strip; `681–939` the full hero with auto-fit tiles;
    /// `≥ 940` the desktop grid with Coming up next | Recently finished.
    public enum Width: Sendable, Equatable { case phone, medium, wide }

    public enum Arrangement: Sendable, Equatable { case columns, stack }

    public struct Balance: Sendable, Equatable {
        public let arrangement: Arrangement
        public let recentCount: Int
    }

    public static func width(_ w: Double) -> Width {
        if w <= 680 { return .phone }
        return w < 940 ? .medium : .wide
    }

    /// Readiness tile columns. Phone: two (the Download clients tile folds into
    /// the strip, so four tiles make a 2 × 2 grid). Medium: the web's
    /// `repeat(auto-fit, minmax(150px, 1fr))` with 10 pt gaps. Wide: all five.
    public static func tileColumns(width w: Double, tiles: Int) -> Int {
        switch width(w) {
        case .phone: return min(2, tiles)
        case .medium: return Swift.max(1, Swift.min(tiles, Int((w + 10) / 160)))
        case .wide: return tiles
        }
    }

    /// Coming up next and Recently finished side by side (desktop, balanced).
    public static func sideBySide(width w: Double, _ balance: Balance) -> Bool {
        width(w) == .wide && balance.arrangement == .columns
    }

    /// Recent rows on screen: the balanced count when wide, six below that.
    public static func visibleRecent(width w: Double, _ balance: Balance) -> Int {
        width(w) == .wide ? balance.recentCount : Swift.min(balance.recentCount, IdleRecent.narrowLimit)
    }

    // Approximate rendered heights (pt), the web's measurements at 1440.
    static let comingChrome = 80.0, comingRow = 77.0, comingExtraRail = 24.0, comingDay = 34.0
    static let comingAside = 90.0, comingEmpty = 160.0, recentChrome = 50.0, recentRow = 62.0

    /// `balanceLayout`: Recently finished shows 6–16 rows to roughly match Coming
    /// up next's height; if the two columns would still be badly uneven (over
    /// 1.8×), they stack at the content width instead.
    public static func balance(coming: ComingUp?, recent: [FinishedRow]?) -> Balance {
        let rows = coming?.rows ?? []
        let hasAside = coming.map { !$0.already.isEmpty || !$0.later.isEmpty } ?? false
        let aside = hasAside ? comingAside : 0
        let comingPx: Double = rows.isEmpty
            ? comingEmpty + aside
            : comingChrome
                + rows.reduce(0) { $0 + comingRow + comingExtraRail * Double(Swift.max(0, $1.tiers.count - 1)) }
                + Double(coming?.days.count ?? 0) * comingDay + aside
        let fit = Int(((comingPx - recentChrome) / recentRow).rounded(.down))
        let recentCount = Swift.min(recent?.count ?? 0,
                                    Swift.max(IdleRecent.narrowLimit, Swift.min(IdleRecent.max, fit)))
        let recentPx = recentCount > 0 ? recentChrome + Double(recentCount) * recentRow : 150
        let ratio = Swift.max(comingPx, recentPx) / Swift.min(comingPx, recentPx)
        return Balance(arrangement: ratio > 1.8 ? .stack : .columns, recentCount: recentCount)
    }
}
