/// The web's mobile bottom-nav destinations (shell/destinations.tsx).
enum AppTab: Hashable {
    case library, discover, calendar, activity
    /// The iOS 26 search tab (the old top bar's omni search).
    case search
    /// Requester accounts (REQUESTOR_DESTINATIONS).
    case requests, you
}

enum SearchScope: Hashable {
    case library, everything
}
