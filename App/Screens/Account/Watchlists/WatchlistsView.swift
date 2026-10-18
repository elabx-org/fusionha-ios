import SwiftUI
import FusionhaKit

/// Account › Watchlists & lists (the web Account page's "Automatic requests",
/// `/account#watchlist`): the Plex watchlist & lists card, then Letterboxd.
/// Each card shows only when it has something to show, like the web.
struct WatchlistsView: View {
    @Environment(AppModel.self) private var model
    @State private var store = WatchlistsStore()

    private var plexVisible: Bool {
        guard let plex = store.plex else { return false }
        return PlexWatchlistState(plex) != .notPlexUser || plex.granted
    }

    private var letterboxdVisible: Bool {
        store.letterboxd.map(LetterboxdLogic.visible) ?? false
    }

    var body: some View {
        List {
            if !store.loaded {
                HStack(spacing: 10) { ProgressView(); Text("Loading…").foregroundStyle(Theme.mut) }
                    .listRowBackground(AccountStyle.cell)
            } else if !plexVisible && !letterboxdVisible {
                Section {
                    Text("Automatic requests from a Plex watchlist or Letterboxd aren’t available for this account. You can still request titles yourself from Discover.")
                        .foregroundStyle(Theme.mut)
                }
                .listRowBackground(AccountStyle.cell)
            } else {
                if plexVisible, let plex = store.plex {
                    PlexWatchlistSection(store: store, read: plex)
                }
                if letterboxdVisible, let letterboxd = store.letterboxd {
                    LetterboxdSection(store: store, read: letterboxd)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tint(Theme.i2)
        .navigationTitle("Watchlists & lists")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.load(model.client) }
        .task { await store.load(model.client) }
        .overlay(alignment: .bottom) { ToastHost().padding(.bottom, 24) }
    }
}

/// Watchlists & lists as its own sheet: from Account and You, and for the
/// `fusionha://account#watchlist` deep link.
struct WatchlistsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WatchlistsView()
                .background(Theme.bg.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { SheetDoneButton { dismiss() } }
                }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }
}
