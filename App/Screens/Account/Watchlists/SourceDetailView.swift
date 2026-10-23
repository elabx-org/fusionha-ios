import SwiftUI
import FusionhaKit

/// The selected source in full (web `SourceDetail`): head, state line and
/// bar, the five counts, the quiet unmatched row with Review, Options, and
/// Pause or remove. Pushed on a phone; the right pane at the Duo's fold.
struct SourceDetailView: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let sourceId: String
    /// Beside the list at the fold: the name shows in the head, not the bar.
    var inSplit = false
    var onRemoved: () -> Void = {}
    @State private var reviewing = false
    @State private var reconnect = PlexReconnect()

    var body: some View {
        let view = store.view(sourceId)
        List {
            if let view {
                content(view)
            } else if store.summary != nil {
                Text(AutomaticRequestsCopy.badSource).foregroundStyle(Theme.mut).listRowBackground(AccountStyle.cell)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .tint(Theme.i2)
        .modifier(SourceDetailBar(store: store, view: view, shown: !inSplit))
        .task {
            #if DEBUG
            // CI screenshots: Pick the right title over the source.
            if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_PICK"] != nil {
                try? await Task.sleep(for: .seconds(2))
                reviewing = true
            }
            #endif
        }
        .duoPageSheet(isPresented: $reviewing) {
            if let view { PickTitleSheet(store: store, view: view) }
        }
        .duoPageSheet(item: Binding(get: { reconnect.authURL }, set: { reconnect.authURL = $0 })) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func content(_ view: AutoSourceView) -> some View {
        let data = AutoSourceDetail(view)
        Section {
            SourceDetailHead(view: view, showsName: inSplit)
            SourceDetailStateLine(view: view, data: data)
            if Self.wantsPlexSignIn(view) { signIn }
            SyncCountsView(counts: data.counts)
            if let hint = data.hint(ownWatchlist: view.kind == .ownWatchlist) {
                Text(hint).font(.footnote).foregroundStyle(Theme.mut)
            }
        }
        .listRowBackground(Color.clear.actWash(view.state.tone?.color, mono: view.state.tone, radius: 0,
                                               base: AccountStyle.cell, border: .clear))
        if data.unmatched > 0 {
            Section { unmatchedRow(data.unmatched, film: !view.isPlex) }
                .listRowBackground(AccountStyle.cell)
                .transition(.opacity)
        }
        SourceOptionsSection(store: store, view: view, data: data)
        SourceManageSection(store: store, view: view, enabled: data.enabled, onRemoved: onRemoved)
    }

    /// Any Plex source that needs a fresh sign-in, and the not-connected watchlist.
    static func wantsPlexSignIn(_ view: AutoSourceView) -> Bool {
        view.isPlex && (view.state == .needsSignIn || (view.state == .notConnected && view.kind == .plexWatchlist))
    }

    private var signIn: some View {
        Button {
            reconnect.start(model) { await store.load(model.client) }
        } label: {
            if reconnect.busy {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Waiting for Plex…") }
            } else {
                Label(SourceDetailCopy.signInPlex, systemImage: "key")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(reconnect.busy)
    }

    private func unmatchedRow(_ n: Int, film: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle").foregroundStyle(Theme.missText)
            Text(SourceDetailCopy.unmatched(n, film: film)).font(.subheadline).foregroundStyle(Theme.txt)
            Spacer(minLength: 8)
            Button(SourceDetailCopy.review) { reviewing = true }
                .buttonStyle(.bordered)
        }
    }
}

/// The detail's head: tile, (name,) owner or provider, the dot and word.
struct SourceDetailHead: View {
    let view: AutoSourceView
    var showsName = false

    var body: some View {
        HStack(spacing: 12) {
            ProviderTile(isPlex: view.isPlex, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                if showsName {
                    Text(view.name).font(.headline).foregroundStyle(Theme.txt)
                }
                Text(view.owner ?? view.provider).font(.subheadline).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 8)
            SourceStateLabel(state: view.state)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The shipped sync line and bar; a private Letterboxd source gets the
/// attention line with its "Open on Letterboxd" (web `DetailStateLine`).
struct SourceDetailStateLine: View {
    let view: AutoSourceView
    let data: AutoSourceDetail

    var body: some View {
        if view.state == .notPublic {
            VStack(alignment: .leading, spacing: 6) {
                WatchlistAttention(lead: SourceDetailCopy.privateLead, rest: SourceDetailCopy.privateRest,
                                   color: Theme.missText)
                if let url = data.url.flatMap(URL.init(string:)) {
                    Link(SourceDetailCopy.openOn, destination: url).font(.footnote.weight(.semibold))
                }
            }
        } else {
            SyncStatusView(sync: data.sync, requested: data.requested, lastCheckedAt: data.lastCheckedAt,
                           nextCheckAt: data.nextCheckAt, lastError: data.lastError, errorLead: lead,
                           paused: view.state.idle, pausedText: view.state.pausedText,
                           note: view.kind == .diary ? SyncProgress.baselineNote(data.counts.baseline) : nil,
                           barLabel: "Sync progress")
        }
    }

    private var lead: String {
        switch view.kind {
        case .diary: return "Couldn’t read the diary"
        case .ownWatchlist, .watchlist: return "Couldn’t read the watchlist"
        case .plexWatchlist: return "Couldn’t read your Plex watchlist"
        case .list, .plexList: return "Couldn’t read the list"
        }
    }
}

/// The pushed detail's bar: the source's name and Sync this source. Beside
/// the list at the fold the page's own bar stays (title and Sync now).
private struct SourceDetailBar: ViewModifier {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let view: AutoSourceView?
    let shown: Bool

    func body(content: Content) -> some View {
        if shown {
            content
                .navigationTitle(view?.name ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if let view, store.canSync(view) {
                        ToolbarItem(placement: .primaryAction) {
                            Button(AutomaticRequestsCopy.syncSource, systemImage: "arrow.clockwise") {
                                Task { await store.syncOne(view, model) }
                            }
                            .disabled(store.syncingSource != nil || view.state.skipsSync)
                        }
                    }
                }
        } else {
            content
        }
    }
}
