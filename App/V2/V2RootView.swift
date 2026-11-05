import SwiftUI

/// v2's signed-in shell: v1's tab shell, with the v2 screens swapped in slice
/// by slice (`docs/v2.md`). Slice S4: the Library tab's root is
/// `V2LibraryView`; every other tab is still v1's.
struct V2RootView: View {
    var body: some View {
        RootView()
            .environment(\.libraryTabRoot, LibraryTabRootOverride { AnyView(V2LibraryView()) })
    }
}
