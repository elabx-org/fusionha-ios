import SwiftUI
import FusionhaKit

/// "Your Plex lists" (web `PlexListsSection`): every `lists.state`, then one
/// switch per list; a list Plex deleted offers Remove instead (cancels nothing).
struct PlexListsSection: View {
    let store: WatchlistsStore
    let lists: PlexListsRead

    var body: some View {
        Section("Your Plex lists") {
            switch lists.state {
            case "managed":
                Label("Plex doesn’t offer Lists to managed accounts.", systemImage: "lock").foregroundStyle(Theme.mut)
            case "loading":
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Loading your lists…").foregroundStyle(Theme.mut) }
            case "error":
                Text("Couldn’t load your Plex lists. Your watchlist still works.").foregroundStyle(Theme.mut)
            case "unknown":
                Text("Your Plex lists show up after your next Plex sign-in.").foregroundStyle(Theme.mut)
            default:
                if lists.state == "empty" || lists.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You haven’t made any Plex lists yet.").foregroundStyle(Theme.mut)
                        Text("Lists you create on Plex show up here.").font(.caption).foregroundStyle(Theme.dim)
                    }
                } else {
                    ForEach(lists.sources) { PlexListRow(store: store, list: $0) }
                }
            }
        }
        .listRowBackground(AccountStyle.cell)
    }
}

/// One Plex list: name, visibility, counts and its own switch, with the
/// baseline choice when turned on.
private struct PlexListRow: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let list: PlexListSource
    @State private var choosing = false

    var body: some View {
        if list.deleted {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.miss)
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name).foregroundStyle(Theme.txt)
                    Text("This list no longer exists on Plex. Nothing already requested is affected.")
                        .font(.caption).foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 8)
                Button("Remove", role: .destructive) { remove() }
                    .buttonStyle(.bordered)
                    .disabled(store.plexBusy)
            }
        } else {
            Toggle(isOn: Binding(get: { list.enabled || choosing }, set: { on in switchChanged(on) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(list.name).foregroundStyle(Theme.txt)
                    Text(meta).font(.caption).foregroundStyle(Theme.mut)
                }
            }
            .disabled(store.plexBusy)
            .accessibilityLabel("Auto-request from list \(list.name)")
            .confirmationDialog("Turn on \(list.name)", isPresented: $choosing, titleVisibility: .visible) {
                Button("Only new additions (recommended)") { turnOn(existing: false) }
                Button("Also request what’s already on it") { turnOn(existing: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only new additions: titles already on this list are noted and left alone.\n\nAlso request what’s already on it: a few at a time; titles over your weekly limit wait.")
            }
        }
    }

    private var meta: String {
        var parts: [String] = []
        if let raw = list.visibility, let word = PlexWatchlistCopy.visibility[raw] { parts.append(word) }
        if let count = list.itemCount { parts.append("\(count) titles") }
        if list.enabled {
            parts.append("\(list.requestedCount) requested")
            if list.lastCheckedAt != nil { parts.append("checked \(WatchlistTime.lastRun(list.lastCheckedAt))") }
        }
        if let error = list.error { parts.append(error) }
        return parts.joined(separator: " · ")
    }

    private func switchChanged(_ on: Bool) {
        if on {
            choosing = true
            return
        }
        let id = list.listId
        Task {
            await store.plexChange(model, success: { _ in "List turned off · nothing already requested is affected" }) {
                try await $0.setPlexList(listId: id, enabled: false)
            }
        }
    }

    private func turnOn(existing: Bool) {
        let id = list.listId
        let name = list.name
        Task {
            await store.plexChange(model, success: { _ in PlexWatchlistCopy.listOnToast(name, existing: existing) }) {
                try await $0.setPlexList(listId: id, enabled: true, requestExisting: existing)
            }
        }
    }

    private func remove() {
        let id = list.listId
        Task {
            guard let client = model.client else { return }
            do {
                try await client.removePlexList(listId: id)
                await store.load(client)
            } catch {
                model.toast(WatchlistErrorCopy.plexMessage(for: error), variant: .error)
            }
        }
    }
}
