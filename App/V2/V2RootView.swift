import SwiftUI

/// v2's signed-in shell: v1's tab shell, with the v2 screens swapped in slice
/// by slice (`docs/v2.md`). Slice S4: the Library tab's root is v2's own;
/// since the Home mock (2026-11-06) it is Home (`V2HomeView`, tab "Home",
/// `house`) with All titles (`V2LibraryView`) pushed from it. Slice S5: every open title is `V2TitleView` (sheet or
/// column), and on the flat open Duo the list keeps a third beside it.
/// Slice S6: seasons and episodes push over it, with v2's interactive
/// search and delete sheets. Slice S8: Activity's Queue tab is `V2QueueView`
/// and the downloads bar is `V2DownloadsAccessory`. Slice S10: Activity's
/// other scopes (`V2ScopeTabs`). Slice S9: Manual Import for held downloads
/// is `V2ManualImportView` (grouped by problem). Slice S11 (Add): the shared
/// Add flow in v2's dress (`V2AddLook`). Slice S14: the shell chrome
/// (`V2ShellChrome`: Activity's needs-you badge, the Duo's downloads
/// capsule; the sidebar and column minimize were removed). Slice S11
/// (browse): Discover, Calendar, Search and the Add-collection page in v2's
/// dress (`V2BrowseLook`). Every other tab is still v1's.
///
/// Fold continuity (`docs/v2.md`): the window's `FoldKeep` and title stacks
/// (`V2TitleStacks`) hold what a fold's layout swap would otherwise reset.
struct V2RootView: View {
    @Environment(AppModel.self) private var model
    @State private var stacks = V2TitleStacks()
    @State private var keep = FoldKeep()

    var body: some View {
        RootView()
            .environment(\.libraryTabRoot, LibraryTabRootOverride(title: "Home", systemImage: "house") {
                AnyView(V2HomeView())
            })
            .environment(\.titlePage, TitlePageOverride(make: { store, onClose in
                AnyView(V2TitleView(store: store, onClose: onClose))
            }, flatOpenListShare: 1.0 / 3, seamHandle: { context in
                AnyView(V2SplitHandle(context: context))
            }, shellGround: { id in
                AnyView(V2TitleShellGround(itemId: id))
            }, stackPath: { [stacks, model] id, host in
                stacks.path(id) { model.detailHostAccepts(host) }
            }))
            .environment(stacks)
            .environment(\.foldKeep, keep)
            .onChange(of: model.presentedItem?.id) { old, _ in
                if let old { stacks.close(old) }
            }
            .environment(\.activityQueueTab, ActivityQueueTabOverride { search in AnyView(V2QueueView(search: search)) })
            .environment(\.activityScopeTab, V2ScopeTabs.override)
            .environment(\.downloadsBarContent, DownloadsBarContentOverride { state in
                AnyView(V2DownloadsAccessory(state: state))
            })
            .environment(\.manualImportSheet, V2ManualImportView.override)
            .environment(\.addLook, V2AddLook.override)
            .environment(\.shellChrome, V2ShellChrome.override)
            .environment(\.browseLook, V2BrowseLook.override)
    }
}

/// v2's shell chrome (plan S14).
enum V2ShellChrome {
    static let override = ShellChromeOverride(
        downloadsCapsule: { state in AnyView(DuoDownloadsCapsule(state: state)) })
}
