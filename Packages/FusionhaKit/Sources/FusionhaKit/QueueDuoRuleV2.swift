import Foundation

/// v2's queue split (plan S8; v1's `QueueDuoRule` stays as it is): the
/// queue list beside the right page (a held download's decision, the bulk
/// remove panel or the idle page). It splits on the open iPhone Duo and on
/// any pane from 720pt. Flat open is one seamless display, the list about a
/// third; book pose keeps equal pages either side of the fold's gutter.
public enum QueueDuoRuleV2 {
    /// The list's share of a flat or wide pane (mock: 330 of 951).
    public static let listShare = 1.0 / 3
    /// The list never gets narrower than a folded phone column.
    public static let minimumList = 300.0
    /// The book pose's fold gutter, nothing interactive in it.
    public static let bookGutter = 40.0
    /// The pane width from which any device splits.
    public static let wideWidth = 720.0

    public static func splits(width: Double, duoOpen: Bool) -> Bool {
        guard width >= minimumList * 2 else { return false }
        return duoOpen || width >= wideWidth
    }

    /// The list column's width in a split pane.
    public static func listWidth(width: Double, bookPose: Bool) -> Double {
        if bookPose { return max(0, (width - bookGutter) / 2) }
        return min(width / 2, max(minimumList, (width * listShare).rounded()))
    }

    /// Space between the list and the right page: the fold's gutter in
    /// book pose, a hairline otherwise.
    public static func gap(bookPose: Bool) -> Double { bookPose ? bookGutter : 0 }
}
