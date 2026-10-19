import SwiftUI
import FusionhaKit

/// The Plex watchlist & lists card (web `PlexWatchlistCard`): the state head,
/// the master switch, one body per read-model state, then the lists. Turning
/// it on asks "only new additions / also what's already on it"; turning it off
/// asks first. Hidden for a password-only user without the grant.
struct PlexWatchlistSection: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: PlexWatchlistRead
    @State private var reconnect = PlexReconnect()
    @State private var choosingOn = false
    @State private var confirmingOff = false

    private var state: PlexWatchlistState { PlexWatchlistState(read) }
    private var checking: Bool { state == .on && read.status == "PENDING" && read.lastCheckedAt == nil }

    var body: some View {
        if state == .notPlexUser {
            if read.granted {
                Section {
                    Label("Sign in with Plex to use your watchlist", systemImage: "key")
                        .foregroundStyle(Theme.mut)
                }
                .listRowBackground(AccountStyle.cell)
            }
        } else {
            Section {
                head
                if state.switchable { masterToggle }
                PlexWatchlistStateBody(store: store, read: read, state: state, reconnect: reconnect)
            } header: {
                Text("Plex")
            } footer: {
                if [.on, .off, .error].contains(state) { neverCancels }
            }
            .listRowBackground(WatchlistWashBackground(token: state.wash(syncing: syncing)))
            if state == .on || state == .off {
                PlexListsSection(store: store, lists: read.lists)
            }
        }
    }

    /// 0.4.215: a pass in flight on the watchlist or a list reads Syncing.
    private var syncing: Bool { state == .on && !checking && SyncProgress.plexRunning(read) }

    private var head: some View {
        let color = checking || syncing ? Theme.grab : Self.color(state)
        let pill = syncing ? SyncProgress.syncing
            : checking ? "Checking" : (state == .off && choosingOn ? "Setting up" : state.label)
        return WatchlistCardHead(mark: .list, title: "Plex watchlist & lists",
                                 sub: state.sub, pill: pill, pillColor: color)
            .sheet(item: Binding(get: { reconnect.authURL }, set: { reconnect.authURL = $0 })) { url in
                SafariView(url: url).ignoresSafeArea()
            }
    }

    private var masterToggle: some View {
        Toggle("Auto-request from my Plex watchlist", isOn: Binding(
            get: { state != .off || choosingOn },
            set: { on in switchChanged(on) }
        ))
        .disabled(store.plexBusy)
        .confirmationDialog("Turn on the watchlist", isPresented: $choosingOn, titleVisibility: .visible) {
            Button("Only new additions (recommended)") { turnOn(existing: false) }
            Button("Also request what’s already on my watchlist") { turnOn(existing: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(turnOnMessage)
        }
        .confirmationDialog("Turn off the watchlist?", isPresented: $confirmingOff, titleVisibility: .visible) {
            Button("Turn off", role: .destructive) { turnOff() }
            Button("Keep it on", role: .cancel) {}
        } message: {
            Text("fusionha stops checking and removes your saved Plex sign-in. Requests already made stay.")
        }
    }

    private var turnOnMessage: String {
        var text = "Only new additions: start from now. Titles already on your watchlist are noted and left alone.\n\nAlso request what’s already on it: a few at a time so nothing floods the server. Titles over your weekly limit wait."
        // The token is kept only while a Plex source is on, so with nothing on
        // yet the server asks for one more sign-in.
        if !read.lists.sources.contains(where: { $0.enabled && !$0.deleted }) {
            text += "\n\nYou’ll be asked to sign in with Plex once more to finish connecting."
        }
        return text
    }

    private var neverCancels: some View {
        Text("**Removing a title from your Plex watchlist or a list never cancels a request.** Anything already requested keeps going. To cancel one, withdraw it under My requests.")
    }

    private func switchChanged(_ on: Bool) {
        switch state {
        case .off: if on { choosingOn = true }
        case .on: if !on { confirmingOff = true }
        default: if !on { turnOff() }
        }
    }

    private func turnOn(existing: Bool) {
        Task {
            await store.plexChange(model, success: { next in
                next.reason == "needs_sign_in" ? "Almost there. Sign in with Plex once more to connect." : "Watchlist turned on"
            }) { try await $0.updatePlexWatchlist(enabled: true, requestExisting: existing) }
        }
    }

    private func turnOff() {
        Task {
            await store.plexChange(model, success: { _ in "Watchlist turned off · saved Plex sign-in removed" }) {
                try await $0.updatePlexWatchlist(enabled: false)
            }
        }
    }

    static func color(_ state: PlexWatchlistState) -> Color {
        switch state {
        case .on: return Theme.done
        case .needsSignIn, .tokenInvalid, .error: return Theme.stuck
        default: return Theme.dim
        }
    }
}
