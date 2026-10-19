import SwiftUI
import FusionhaKit

/// The diary (web `LetterboxdDiary`): its switch with the baseline choice,
/// stats, rewatches, UHD·4K and the schedule hint.
struct LetterboxdDiarySection: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: LetterboxdRead
    @Binding var choosing: Bool

    var body: some View {
        if let diary = read.diary, let user = read.username {
            Section("Diary") {
                Toggle(isOn: Binding(get: { diary.enabled || choosing }, set: { on in switchChanged(on, diary: diary, user: user) })) {
                    HStack(spacing: 8) {
                        let pill = Self.pill(diary)
                        Text("Request films from my Letterboxd diary")
                        WatchlistPill(text: pill.text, color: pill.color)
                    }
                }
                .disabled(store.letterboxdBusy)
                .confirmationDialog("What to request when you turn the diary on", isPresented: $choosing,
                                    titleVisibility: .visible) {
                    Button("Only new entries (recommended)") { turnOn(user, baseline: "new") }
                    Button("Also request my recent entries") { turnOn(user, baseline: "existing") }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Only new entries: start from now. Entries already in your diary are noted and left alone.\n\nAlso request my recent entries: the 50 latest entries in your public feed, a few at a time. Films already in the library are skipped.")
                }
                if diary.enabled {
                    onRows(diary, user: user)
                } else if !choosing {
                    Text("Off. Turn it on to request new entries from your public diary on its own.")
                        .font(.footnote).foregroundStyle(Theme.mut)
                }
            }
            .listRowBackground(AccountStyle.cell)
        }
    }

    @ViewBuilder
    private func onRows(_ diary: LetterboxdDiary, user: String) -> some View {
        WatchlistStatsRow(items: [
            (value: "\(diary.requestedCount)", label: "Requested from diary"),
            (value: WatchlistTime.lastRun(diary.lastCheckedAt), label: "Last checked"),
            (value: WatchlistTime.until(diary.nextCheckAt), label: "Next check"),
        ])
        SyncStatusView(sync: diary.sync, requested: diary.counts?.requested ?? diary.requestedCount,
                       lastCheckedAt: diary.lastCheckedAt, nextCheckAt: diary.nextCheckAt,
                       errorLead: "Couldn’t read the diary", note: SyncProgress.baselineNote(diary.counts?.baseline),
                       barLabel: "Diary sync progress")
        Toggle(isOn: Binding(get: { diary.requestRewatches }, set: { on in save(user, rewatches: on) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Also request rewatches")
                Text("Normally only first-time watches are requested. Turn this on to also request films you log as a rewatch that aren’t in the library.")
                    .font(.caption).foregroundStyle(Theme.mut)
            }
        }
        .disabled(store.letterboxdBusy)
        Toggle(isOn: Binding(get: { diary.alsoUhd && read.alsoUhdAllowed }, set: { on in save(user, uhd: on) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Also request UHD·4K")
                Text(read.alsoUhdAllowed ? "Adds a 4K version of each film you are allowed it for"
                                         : "Not available: your account can request HD·1080p only")
                    .font(.caption).foregroundStyle(Theme.mut)
            }
        }
        .disabled(!read.alsoUhdAllowed || store.letterboxdBusy)
        Text(LetterboxdLogic.diaryHint(hours: LetterboxdLogic.scheduleHours(last: diary.lastCheckedAt, next: diary.nextCheckAt)))
            .font(.footnote).foregroundStyle(Theme.mut)
    }

    /// Off, or Syncing / Error / Active from the diary's sync (web `LetterboxdDiary`).
    static func pill(_ diary: LetterboxdDiary) -> (text: String, color: Color) {
        guard diary.enabled else { return ("Off", Theme.dim) }
        switch SyncProgress.variant(diary.sync) {
        case .running: return (SyncProgress.syncing, SyncVariant.running.color)
        case .error: return ("Error", SyncVariant.error.color)
        default: return ("Active", Theme.done)
        }
    }

    private func switchChanged(_ on: Bool, diary: LetterboxdDiary, user: String) {
        if diary.enabled && !on {
            Task {
                await store.letterboxdChange(model, success: { _ in "Diary turned off · nothing already requested is affected" }) {
                    try await $0.updateLetterboxd(username: user, diaryEnabled: false)
                }
            }
        } else if !diary.enabled {
            choosing = on
        }
    }

    private func turnOn(_ user: String, baseline: String) {
        Task {
            await store.letterboxdChange(model, success: { _ in "Diary on · first check is running" }) {
                try await $0.updateLetterboxd(username: user, diaryEnabled: true, baseline: baseline)
            }
        }
    }

    private func save(_ user: String, rewatches: Bool? = nil, uhd: Bool? = nil) {
        Task {
            await store.letterboxdChange(model, success: { _ in "Saved" }) {
                try await $0.updateLetterboxd(username: user, requestRewatches: rewatches, alsoUhd: uhd)
            }
        }
    }
}

/// "My watchlist" (web `WatchlistFollow`): follow your own public watchlist
/// (best effort), with its status and the not-public / blocked / cut-off notes.
struct LetterboxdFollowSection: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let read: LetterboxdRead
    @State private var choosing = false

    private var follow: LetterboxdWatchlistFollow { read.watchlistFollow }

    var body: some View {
        Section("My watchlist") {
            Toggle(isOn: Binding(get: { follow.enabled || choosing }, set: { on in switchChanged(on) })) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Follow my public watchlist")
                        if follow.enabled {
                            let pill = LetterboxdFollowState.pill(follow)
                            WatchlistPill(text: pill.text, color: pill.color)
                        }
                    }
                    Text("Reads your public watchlist page about every 12 hours and keeps it in sync. **Best effort:** Letterboxd can block this (the diary can’t be blocked).")
                        .font(.caption).foregroundStyle(Theme.mut)
                }
            }
            .disabled(store.letterboxdBusy)
            .accessibilityLabel("Follow my public Letterboxd watchlist")
            .confirmationDialog("What to request when you follow your watchlist", isPresented: $choosing,
                                titleVisibility: .visible) {
                Button("Only new additions (recommended)") { turnOn("new") }
                Button("Also request what’s already on it") { turnOn("existing") }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only new additions: films already on your watchlist are noted and left alone.\n\nAlso request what’s already on it: a few at a time; titles over your weekly limit wait.")
            }
            if follow.enabled { LetterboxdFollowState(follow: follow) }
        }
        .listRowBackground(AccountStyle.cell)
    }

    private func switchChanged(_ on: Bool) {
        if follow.enabled && !on {
            Task {
                await store.letterboxdChange(model, success: { _ in "Watchlist follow off · nothing already requested is affected" }) {
                    try await $0.followLetterboxdWatchlist(enabled: false)
                }
            }
        } else if !follow.enabled {
            choosing = on
        }
    }

    private func turnOn(_ baseline: String) {
        Task {
            await store.letterboxdChange(model, success: { _ in "Following your watchlist · first check is running" }) {
                try await $0.followLetterboxdWatchlist(enabled: true, baseline: baseline)
            }
        }
    }
}
