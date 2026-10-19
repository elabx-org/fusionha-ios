import SwiftUI
import FusionhaKit

/// The Account page's "Automatic requests" (web `AutomaticRequests`, ruling
/// S1): the heading, then the Plex watchlist & lists card and the Letterboxd
/// card, inline in Account's list. The heading shows only when either card
/// has something to show, like the web; it is the `#watchlist` anchor.
struct AutomaticRequestsSection: View {
    let store: WatchlistsStore

    static let anchor = "watchlist"

    /// Either card has something to show.
    static func visible(_ store: WatchlistsStore) -> Bool {
        plexVisible(store) || letterboxdVisible(store)
    }

    private static func plexVisible(_ store: WatchlistsStore) -> Bool {
        guard let plex = store.plex else { return false }
        return PlexWatchlistState(plex) != .notPlexUser || plex.granted
    }

    private static func letterboxdVisible(_ store: WatchlistsStore) -> Bool {
        store.letterboxd.map(LetterboxdLogic.visible) ?? false
    }

    var body: some View {
        if store.loaded, Self.visible(store) {
            AccountSectionHeading("Automatic requests")
                .id(Self.anchor)
            if Self.plexVisible(store), let plex = store.plex {
                PlexWatchlistSection(store: store, read: plex)
            }
            if Self.letterboxdVisible(store), let letterboxd = store.letterboxd {
                LetterboxdSection(store: store, read: letterboxd)
            }
        }
    }
}

/// The web's `.sec` heading (11 pt, uppercase, `--dim`, a hairline after it)
/// as a bare list row.
struct AccountSectionHeading: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Theme.dim)
                .accessibilityAddTraits(.isHeader)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .padding(.top, 14)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
        .listRowSeparator(.hidden)
    }
}

extension View {
    /// Loads the Automatic requests cards and, while a source is mid-pass,
    /// re-reads them every 2 s (web `syncPollMs`); the loop ends once all are
    /// idle and restarts when one runs again.
    func automaticRequestsLoading(_ store: WatchlistsStore, client: APIClient?) -> some View {
        task { await store.load(client) }
            .task(id: store.anyRunning) {
                while store.anyRunning {
                    try? await Task.sleep(for: .seconds(SyncProgress.runningPollSeconds))
                    if Task.isCancelled { return }
                    await store.refreshProgress(client)
                }
            }
    }
}
