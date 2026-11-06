import SwiftUI

/// v2's signed-in shell: v1's tab shell, with the v2 screens swapped in slice
/// by slice (`docs/v2.md`). Slice S4: the Library tab's root is
/// `V2LibraryView`. Slice S5: every open title is `V2TitleView` (sheet or
/// column), and on the flat open Duo the list keeps a third beside it.
/// Slice S6: seasons and episodes push over it, with v2's interactive
/// search and delete sheets. Slice S8: Activity's Queue tab is `V2QueueView`
/// and the downloads bar is `V2DownloadsAccessory`. Slice S10: Activity's
/// other scopes (`V2ScopeTabs`). Slice S9: Manual Import for held downloads
/// is `V2ManualImportView` (grouped by problem). Slice S11 (Add): the shared
/// Add flow in v2's dress (`V2AddLook`). Slice S14: the shell chrome
/// (`V2ShellChrome`: the open Duo's sidebar, the column's own minimize,
/// Activity's needs-you badge, the Duo's downloads capsule). Every other tab
/// is still v1's.
struct V2RootView: View {
    var body: some View {
        RootView()
            .environment(\.libraryTabRoot, LibraryTabRootOverride { AnyView(V2LibraryView()) })
            .environment(\.titlePage, TitlePageOverride(make: { store, onClose in
                AnyView(V2TitleView(store: store, onClose: onClose))
            }, flatOpenListShare: 1.0 / 3, seamHandle: { context in
                AnyView(V2SplitHandle(context: context))
            }, shellGround: { id in
                AnyView(V2TitleShellGround(itemId: id))
            }))
            .environment(\.activityQueueTab, ActivityQueueTabOverride { search in AnyView(V2QueueView(search: search)) })
            .environment(\.activityScopeTab, V2ScopeTabs.override)
            .environment(\.downloadsBarContent, DownloadsBarContentOverride { state in
                AnyView(V2DownloadsAccessory(state: state))
            })
            .environment(\.manualImportSheet, V2ManualImportView.override)
            .environment(\.addLook, V2AddLook.override)
            .environment(\.shellChrome, V2ShellChrome.override)
    }
}

/// v2's shell chrome (plan S14, mock minimize.js).
enum V2ShellChrome {
    static let override = ShellChromeOverride(
        sidebar: { toggle in AnyView(ShellSidebar(toggle: toggle)) },
        downloadsCapsule: { state in AnyView(DuoDownloadsCapsule(state: state)) })
}
