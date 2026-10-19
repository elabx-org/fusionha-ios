import SwiftUI
import FusionhaKit

/// The Letterboxd card (web `LetterboxdCard`): the head and pill, the
/// not-allowed state, then profile, diary, own watchlist, linked sources,
/// Sync now and the one-time import. Every switch saves on its own.
struct LetterboxdSection: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: LetterboxdRead
    @State private var diaryChoosing = false
    @State private var importing = false

    private var connection: LetterboxdLogic.Connection { LetterboxdLogic.connection(read) }

    var body: some View {
        if LetterboxdLogic.allowed(read) {
            Section {
                head
                LetterboxdProfileRows(store: store, read: read, diaryChoosing: $diaryChoosing)
            } header: {
                Text("Letterboxd")
            } footer: {
                Text("**fusionha can only follow what’s public on Letterboxd.** Set your watchlist or a list to public to keep it in sync. Diary, watchlist and lists all update on a schedule, and Sync now checks them right away.")
            }
            .listRowBackground(AccountStyle.cell)
            if connection == .ok {
                LetterboxdDiarySection(store: store, read: read, choosing: $diaryChoosing)
                LetterboxdFollowSection(store: store, read: read)
            }
            LinkedSourcesSection(store: store, read: read)
            if connection == .ok || read.linkedCount > 0 { syncSection }
            advanced
        } else {
            Section {
                head
                Text("An admin hasn’t allowed automatic requests from Letterboxd for your account. Ask an admin to turn on **Letterboxd & linked lists** for you. That covers your diary, your watchlist, and any lists or other people’s watchlists you would link. You can still request titles yourself from Discover.")
                    .font(.footnote).foregroundStyle(Theme.mut)
            } header: {
                Text("Letterboxd")
            }
            .listRowBackground(AccountStyle.cell)
            advanced
        }
    }

    private var head: some View {
        let pill: (String, Color)
        let sub: String
        if !LetterboxdLogic.allowed(read) {
            pill = ("Not allowed", Theme.dim)
            sub = "An admin has to allow this first"
        } else {
            switch connection {
            case .none:
                pill = ("Not connected", Theme.dim)
                sub = "Request films from your diary, watchlist and lists"
            case .ok:
                pill = store.letterboxdRunning ? (SyncProgress.syncing, SyncVariant.running.color) : ("Active", Theme.done)
                sub = "@\(read.username ?? "") · reading public data"
            case .bad:
                pill = ("Can’t read profile", Theme.stuck)
                sub = "Checks paused until the profile can be read"
            }
        }
        return WatchlistCardHead(icon: "film.stack", tint: Theme.mut, title: "Letterboxd", sub: sub,
                                 pill: pill.0, pillColor: pill.1)
    }

    private var syncSection: some View {
        Section {
            WatchlistSyncRow(title: "Check now",
                             sub: "Checks your diary, watchlist and linked sources right away. Each source at most once every 5 minutes.",
                             retryAt: store.letterboxdRetryAt ?? read.syncAvailableAt,
                             syncing: store.letterboxdSyncing,
                             running: store.letterboxdRunning,
                             waitText: { LetterboxdLogic.checkAgain($0) }) {
                Task { await store.syncLetterboxd(model) }
            }
        } footer: {
            Text("**Removing a film from Letterboxd, or unlinking a list, never cancels a request.** To cancel one, withdraw it under My requests.")
        }
        .listRowBackground(AccountStyle.cell)
    }

    private var advanced: some View {
        Section("Advanced") {
            Button { importing = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("One-time import (CSV/ZIP export)").foregroundStyle(Theme.txt)
                        Text("A one-off backfill for private items, from Letterboxd’s “Export your data”. It doesn’t keep anything in sync; follow public pages above for that.")
                            .font(.caption).foregroundStyle(Theme.mut)
                    }
                    Spacer(minLength: 8)
                    Text("Import…").foregroundStyle(Theme.i2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $importing) {
                LetterboxdImportSheet { Task { await store.load(model.client) } }
            }
        }
        .listRowBackground(AccountStyle.cell)
    }
}
