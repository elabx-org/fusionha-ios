import Foundation

/// A count badge's text (web `DiscoverTabBadge`, the Activity nav badge):
/// nothing at zero, the number up to 99, then "99+".
public enum BadgeCount {
    public static func text(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count > 99 ? "99+" : String(count)
    }
}
