import SwiftUI

/// v2's signed-in shell: v1's tab shell, with the v2 screens swapped in slice
/// by slice (`docs/v2.md`). Slice S4: the Library tab's root is
/// `V2LibraryView`. Slice S5: every open title is `V2TitleView` (sheet or
/// column), and on the flat open Duo the list keeps a third beside it.
/// Slice S6: seasons and episodes push over it, with v2's interactive
/// search and delete sheets. Every other tab is still v1's.
struct V2RootView: View {
    var body: some View {
        RootView()
            .environment(\.libraryTabRoot, LibraryTabRootOverride { AnyView(V2LibraryView()) })
            .environment(\.titlePage, TitlePageOverride(make: { store, onClose in
                AnyView(V2TitleView(store: store, onClose: onClose))
            }, flatOpenListShare: 1.0 / 3, seamHandle: { context in
                AnyView(V2SplitHandle(context: context))
            }))
    }
}
