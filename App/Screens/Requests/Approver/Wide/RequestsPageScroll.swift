import SwiftUI

// No scroll inside scroll (owner, D2a follow-up): when a wide Requests view
// fills the screen with panes that scroll on their own, the Discover page
// around it stops scrolling. Narrow, or on Browse, the page scrolls as before.

/// True while a wide Requests view lays out its own scrolling panes.
struct RequestsFillsPageKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

extension View {
    /// On the page's scroll view (Discover): locks it at the top while a
    /// wide Requests view fills the page.
    func requestsWidePageScroll() -> some View { modifier(RequestsPageScroll()) }

    /// On the wide Requests content: its panes scroll even though the page doesn't.
    func requestsFillsPage(_ fills: Bool) -> some View {
        preference(key: RequestsFillsPageKey.self, value: fills)
            .environment(\.isScrollEnabled, true)
    }
}

private struct RequestsPageScroll: ViewModifier {
    @State private var locked = false
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .scrollDisabled(locked)
            .onPreferenceChange(RequestsFillsPageKey.self) { fills in
                guard fills != locked else { return }
                locked = fills
                if fills { position.scrollTo(edge: .top) }
            }
    }
}
