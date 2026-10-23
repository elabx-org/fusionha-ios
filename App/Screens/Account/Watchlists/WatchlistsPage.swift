import SwiftUI
import FusionhaKit

/// A `fusionha://account/lists[/<source-id>]` link waiting for the page.
struct ListsLink: Equatable {
    var sourceId: String?
}

/// Watchlists & lists (web `ListsPage`, fusionha 0.4.226), pushed from
/// Account's Automatic requests row: the grouped sources; a source opens its
/// detail (pushed on a phone, beside the list at the open Duo's fold). Follow
/// is the toolbar's `plus`; Sync now is `arrow.clockwise` and pull to refresh.
struct WatchlistsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: WatchlistsStore
    /// The source a link asked for.
    var initialSource: String?
    @State private var pushed: String?
    @State private var splitId: String?
    @State private var panes: FoldColumns.Panes?
    @State private var following = false
    @State private var profile = false
    @State private var importing = false
    @State private var remembered = false
    @State private var told = false

    private var admin: Bool { model.me?.isAdmin == true && !model.requestScoped }
    private var unavailable: Bool { model.me.map { !$0.hasCapability("request") } ?? false }
    private var busy: Bool { store.allSyncing || store.summary?.syncing != nil }

    var body: some View {
        WatchlistsSplit(panes: panes) {
            list
        } detail: {
            if let id = splitId ?? store.summary?.defaultSourceId {
                SourceDetailView(store: store, sourceId: id, inSplit: true) { splitId = nil }
            } else {
                Theme.bg
            }
        }
        .background(Theme.bg)
        .onGeometryChange(for: FoldColumns.Panes?.self) { proxy in
            FoldInfo.verticalFold(proxy).flatMap { x in
                FoldColumns.panes(width: Double(proxy.size.width), fold: Double(x.lowerBound)...Double(x.upperBound),
                                  minLead: 280, minTrail: 320)
            }
        } action: { panes = $0 }
        .navigationTitle(AutomaticRequestsCopy.title)
        // Beside its detail the title sits on the left page, never on the fold.
        .toolbarTitleDisplayMode(panes == nil ? .inline : .inlineLarge)
        .toolbar { toolbar }
        .navigationDestination(item: $pushed) { id in
            SourceDetailView(store: store, sourceId: id) { pushed = nil }
        }
        .navigationDestination(isPresented: $remembered) { RememberedMatchesView(store: store) }
        .sheet(isPresented: $following) { FollowSheet(store: store) }
        .sheet(isPresented: $profile) { LetterboxdProfileSheet(store: store) }
        .sheet(isPresented: $importing) {
            LetterboxdImportSheet { Task { await store.load(model.client) } }
        }
        .task(id: admin) { if admin { await store.loadMatches(model.client) } }
        .onChange(of: store.summary != nil, initial: true) { openLinked() }
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
                WatchlistsSourceList(views: views, selectedId: panes == nil ? nil : (splitId ?? store.summary?.defaultSourceId),
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
        } else if panes != nil {
            splitId = view.sourceId
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
        if panes != nil { splitId = id } else { pushed = id }
    }
}
