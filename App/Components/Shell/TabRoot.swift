import SwiftUI

/// A tab's root: its own `NavigationStack` inside its `Tab`, so the tab has a
/// system navigation bar the toolbar migration (D1) can fill and iOS 27.1 can
/// turn into a vertical bar on iPhone Duo. The stack sits inside the `Tab`, not
/// around the `TabView`, so the tab view keeps its identity and every tab its
/// scroll position across the shell's split (`FoldSplitLayout`).
///
/// Each page fills the bar with `.shellPage(_:)`: its title (`.inlineLarge`,
/// one row with the items on a phone) and its toolbar items (D1). Pages
/// presented from a tab bring their own stacks only inside sheets and covers,
/// never inside this one.
struct TabRoot<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            content
                // The tab bar's top, for the shell's toasts (D3).
                .publishesToastAnchor()
        }
    }
}
