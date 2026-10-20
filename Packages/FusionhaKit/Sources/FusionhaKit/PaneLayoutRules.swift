import Foundation

/// The web's `useIsMobile` breakpoint (`max-width: 720px`) applied to the
/// width a pane really has, never the viewport or the size class (rulings L17,
/// S2, R4): a Library in the shell's leading column stays the phone layout
/// even on a wide display.
public enum PaneWidthRule {
    public static let mobileMax = 720.0

    /// Above 720 a pane takes the web's desktop layout.
    public static func isWide(_ width: Double) -> Bool {
        width > mobileMax
    }
}

/// The Calendar's three layouts (`routes/calendar/layout.ts` `layoutFor`),
/// from the Calendar's own width.
public enum CalendarLayout: String, Equatable, Sendable {
    case phone, tablet, desktop

    public static func of(width: Double) -> CalendarLayout {
        width < 720 ? .phone : width < 1000 ? .tablet : .desktop
    }
}

/// The login stages side by side (Login.module.css): the split hero beside the
/// form above 760, the Living art beside it above 720; stacked below.
public enum SignInLayoutRule {
    public static func splitSideBySide(width: Double) -> Bool { width > 760 }
    public static func livingSideBySide(width: Double) -> Bool { width > 720 }
}

/// The shell's status cluster (TopBar `statusCluster`): Activity, Needs
/// attention and the backend light, shown only above the web's 900 (it hides
/// the cluster from 721 to 900; D2b follow-up ruling) and only to a user who
/// manages the server.
public enum StatusClusterRule {
    public static let minWidth = 900.0

    public static func shows(width: Double, requestScoped: Bool) -> Bool {
        !requestScoped && width > minWidth
    }
}
