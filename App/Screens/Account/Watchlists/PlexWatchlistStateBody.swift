import SwiftUI
import FusionhaKit

/// The rows under the Plex card's switch, one set per state (web `WatchlistBody`).
struct PlexWatchlistStateBody: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: PlexWatchlistRead
    let state: PlexWatchlistState
    let reconnect: PlexReconnect

    var body: some View {
        switch state {
        case .notPlexUser:
            EmptyView()
        case .notGranted, .ineligible:
            Text("An admin hasn’t allowed automatic requests from the Plex watchlist for your account. Ask an admin to turn on **Auto-request from Plex watchlist** for you. You can still request titles yourself from Discover.")
                .font(.footnote).foregroundStyle(Theme.mut)
        case .disabled:
            Text("Your admin has paused watchlist requests for your account. Nothing is being checked right now. Requests you already have are unaffected.")
                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.txt)
        case .needsSignIn:
            WatchlistAttention(lead: "Sign in with Plex once more to connect your watchlist.",
                               rest: "fusionha only keeps your Plex sign-in while this is on, so it needs a fresh one. Nothing has been requested yet.")
            signInButton("Sign in with Plex")
        case .tokenInvalid:
            WatchlistAttention(lead: "Plex rejected your saved sign-in.",
                               rest: "Checks are paused until you sign in with Plex again. Last good check: \(WatchlistTime.lastRun(read.lastCheckedAt)). Everything already requested is unaffected.")
            signInButton("Sign in with Plex again")
        case .error:
            WatchlistAttention(lead: "Couldn’t check your watchlist. fusionha will retry.", rest: errorRest)
            WatchlistStatsRow(items: [
                (value: "\(read.requestedCount)", label: "Requested from watchlist"),
                (value: WatchlistTime.lastRun(read.lastSuccessAt), label: "Last good check"),
                (value: WatchlistTime.until(read.nextCheckAt), label: "Next try"),
            ])
        case .on:
            PlexWatchlistActive(store: store, read: read)
        case .off:
            Text("When you add a movie or show to your Plex watchlist, fusionha requests it for you, in the versions you’re allowed, within your weekly limits.")
                .font(.footnote).foregroundStyle(Theme.mut)
        }
    }

    private var errorRest: String {
        let why = read.lastError ?? "Plex didn’t answer."
        return "\(why) Last attempt \(WatchlistTime.lastRun(read.lastCheckedAt)) · next try \(WatchlistTime.until(read.nextCheckAt)). Nothing needs doing."
    }

    private func signInButton(_ title: String) -> some View {
        Button {
            reconnect.start(model) { await store.load(model.client) }
        } label: {
            if reconnect.busy {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Waiting for Plex…") }
            } else {
                Label(title, systemImage: "key")
            }
        }
        .disabled(reconnect.busy)
    }
}

/// The "on" rows: stats, the first-check line, the hint, Also UHD·4K and
/// Sync now (web `WatchlistActive`).
struct PlexWatchlistActive: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: PlexWatchlistRead

    private var checking: Bool { read.status == "PENDING" && read.lastCheckedAt == nil }
    private var enabledLists: Int { read.lists.sources.filter { $0.enabled && !$0.deleted }.count }

    var body: some View {
        if checking {
            Label("Reading your watchlist from Plex…", systemImage: "hourglass").font(.footnote).foregroundStyle(Theme.mut)
        } else {
            WatchlistStatsRow(items: [
                (value: "\(read.requestedTotal)", label: "Requested from Plex"),
                (value: WatchlistTime.lastRun(read.lastCheckedAt), label: "Last checked"),
                (value: WatchlistTime.until(read.nextCheckAt), label: "Next check"),
            ])
            if read.waitingCount > 0 {
                Text("\(read.waitingCount) waiting for your weekly limit").font(.footnote).foregroundStyle(Theme.miss)
            }
        }
        if let first = read.firstCheck {
            WatchlistInfo(icon: "checkmark.circle", lead: "First check done.", rest: PlexWatchlistCopy.firstCheck(first))
        }
        if !checking, let hint = PlexWatchlistCopy.watchlistHint(read) {
            Text(hint).font(.footnote).foregroundStyle(Theme.mut)
        }
        uhdToggle
        WatchlistSyncRow(title: "Check now", sub: PlexWatchlistCopy.checkNowSub(lists: enabledLists),
                         retryAt: store.plexRetryAt ?? read.syncAvailableAt,
                         syncing: store.plexSyncing || checking,
                         waitText: { "You can check again in \($0)s" }) {
            Task { await store.syncPlex(model) }
        }
    }

    private var uhdToggle: some View {
        Toggle(isOn: Binding(
            get: { read.alsoUhd && read.alsoUhdAllowed },
            set: { on in
                Task {
                    await store.plexChange(model, success: { _ in "Saved" }) { try await $0.updatePlexWatchlist(alsoUhd: on) }
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Also request UHD·4K")
                Text(read.alsoUhdAllowed ? "Adds a 4K version of each title you are allowed it for"
                                         : "Not available: your account can request HD·1080p only")
                    .font(.caption).foregroundStyle(Theme.mut)
            }
        }
        .disabled(!read.alsoUhdAllowed || store.plexBusy)
    }
}
