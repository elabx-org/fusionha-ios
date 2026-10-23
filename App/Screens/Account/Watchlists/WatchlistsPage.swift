import SwiftUI
import FusionhaKit

/// A `fusionha://account/lists[/<source-id>]` link waiting for the page.
struct ListsLink: Equatable {
    var sourceId: String?
}

/// Watchlists & lists (web `ListsPage`, fusionha 0.4.226), pushed from
/// Account's Automatic requests row: the grouped sources; a source pushes its
/// detail. On the open Duo in a Spread the page is Account's right page and
/// the detail pushes inside it (`AccountSpreadSheet`), never a split. Follow
/// is the toolbar's `plus`; Sync now is `arrow.clockwise` and pull to refresh.
struct WatchlistsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: WatchlistsStore
    /// The source a link asked for.
    var initialSource: String?
    @State private var pushed: String?
    @State private var following = false
    @State private var profile = false
    @State private var importing = false
    @State private var remembered = false
    @State private var told = false

    private var admin: Bool { model.me?.isAdmin == true && !model.requestScoped }
    private var unavailable: Bool { model.me.map { !$0.hasCapability("request") } ?? false }
    private var busy: Bool { store.allSyncing || store.summary?.syncing != nil }

    var body: some View {
        list
            .background(Theme.bg)
        .navigationTitle(AutomaticRequestsCopy.title)
        // Leading, as Settings' pushed panels.
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar { toolbar }
        .navigationDestination(item: $pushed) { id in
            SourceDetailView(store: store, sourceId: id) { pushed = nil }
        }
        .navigationDestination(isPresented: $remembered) { RememberedMatchesView(store: store) }
        // On the open Duo these take the right page, never the fold (S3).
        .duoPageSheet(isPresented: $following) { FollowSheet(store: store) }
        .duoPageSheet(isPresented: $profile) { LetterboxdProfileSheet(store: store) }
        .duoPageSheet(isPresented: $importing) {
            LetterboxdImportSheet { Task { await store.load(model.client) } }
        }
        .task(id: admin) { if admin { await store.loadMatches(model.client) } }
        .onChange(of: store.summary != nil, initial: true) { openLinked() }
        // Account is hidden under this page, so its re-read loop stops: run it here.
        .task(id: store.anyRunning) {
            while store.anyRunning {
                try? await Task.sleep(for: .seconds(SyncProgress.runningPollSeconds))
                if Task.isCancelled { return }
                await store.refreshProgress(model.client)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button(AutomaticRequestsCopy.syncNow, systemImage: "arrow.clockwise") {
                Task { await store.syncAll(model) }
            }
            .symbolEffect(.rotate, options: .repeat(.continuous), isActive: busy && !reduceMotion)
            .disabled(busy || unavailable)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(AutomaticRequestsCopy.follow, systemImage: "plus") { following = true }
                .disabled(unavailable || store.letterboxd.map { !LetterboxdLogic.allowed($0) } ?? true)
        }
    }

    private var list: some View {
        List {
            if unavailable {
                Text(AutomaticRequestsCopy.unavailable).foregroundStyle(Theme.mut).listRowBackground(AccountStyle.cell)
            } else if let views = store.views {
                WatchlistsSourceList(views: views, selectedId: nil,
                                     admin: admin, remembered: store.matches.count,
                                     onOpen: open, onFollow: { following = true }, onProfile: { profile = true },
                                     onImport: { importing = true }, onRemembered: { remembered = true })
            } else if store.summaryFailed {
                Text(AutomaticRequestsCopy.loadFailed).foregroundStyle(Theme.mut).listRowBackground(AccountStyle.cell)
            } else {
                Text(AutomaticRequestsCopy.loading).foregroundStyle(Theme.mut).listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .tint(Theme.i2)
        .refreshable {
            // Pull to sync everything; the pass reports back with its toast.
            Task { await store.syncAll(model) }
            try? await Task.sleep(for: .milliseconds(600))
        }
        .animation(reduceMotion ? nil : .default, value: store.views)
    }

    /// A not-connected Letterboxd placeholder opens the profile; anything else selects it.
    private func open(_ view: AutoSourceView) {
        if view.state == .notConnected && !view.isPlex {
            profile = true
        } else {
            pushed = view.sourceId
        }
    }

    /// The link's source, once the summary says whether it exists.
    private func openLinked() {
        guard let summary = store.summary, !told, let id = initialSource else { return }
        told = true
        guard summary.source(id) != nil else {
            model.toast(AutomaticRequestsCopy.badSource, variant: .warning)
            return
        }
        pushed = id
    }
}
