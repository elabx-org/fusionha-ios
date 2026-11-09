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
    @Environment(\.tabContentSizeClass) private var contentClass

    var body: some View {
        NavigationStack {
            content
                // Room for the downloads pill where it floats over the tab (D3).
                .reservesDownloadsPillSpace()
        }
        // The shell may give the tab bar a compact form (`ShellTabs`); the
        // page keeps the display's own size class.
        .transformEnvironment(\.horizontalSizeClass) { value in
            if let contentClass { value = contentClass }
        }
    }
}

extension EnvironmentValues {
    /// The display's real horizontal size class, for a tab's pages while the
    /// shell gives its tab bar another one (`ShellTabs.narrowColumn`).
    @Entry var tabContentSizeClass: UserInterfaceSizeClass? = nil
}
