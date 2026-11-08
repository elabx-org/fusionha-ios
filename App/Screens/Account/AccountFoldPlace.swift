import SwiftUI

// v2's fold continuity for Account (`docs/v2.md`, "Fold continuity"). In
// the Spread layout Account is a sheet folded and both pages open, so a
// fold builds it again. Its inner page rides across here: Watchlists &
// lists (pushed folded, the right page open) and the source pushed inside
// it. The shell sets it only while Account is open in v2 (`FoldKeep`); v1
// and the You tab never see one.

@MainActor
final class AccountFoldPlace {
    static let key = "account"
    /// Watchlists & lists was opened (pushed folded, asked for on the right page open).
    var listsOpen = false
    /// The source pushed inside Watchlists & lists.
    var source: String?
    /// The Account page on screen: only its pushes and pops count.
    var listsHost: UUID?
    /// The Watchlists & lists page on screen: only its pushed source counts.
    var pageHost: UUID?

    /// The new host opens Watchlists & lists again (with `source`).
    var reopensLists: Bool { listsOpen || source != nil }
}

extension EnvironmentValues {
    @Entry var accountFoldPlace: AccountFoldPlace?
}
