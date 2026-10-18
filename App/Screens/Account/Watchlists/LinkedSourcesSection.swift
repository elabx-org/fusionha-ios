import SwiftUI
import FusionhaKit

/// "Lists & other people's watchlists" (web `LinkedSources`): "3 of 5 linked",
/// one row per source, Add (with the preview sheet), the limit and the
/// best-effort note.
struct LinkedSourcesSection: View {
    let store: WatchlistsStore
    let read: LetterboxdRead
    @State private var adding = false

    private var linked: [LbSource] { store.sources.filter(\.isLinked) }

    var body: some View {
        let count = LetterboxdLogic.linkedCount(read, sources: store.sources)
        let max = read.maxLinkedLists
        let full = count >= max
        Section {
            if linked.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing linked yet.").fontWeight(.semibold).foregroundStyle(Theme.mut)
                    Text("Paste a Letterboxd list, or follow a friend’s public watchlist.").font(.caption).foregroundStyle(Theme.dim)
                }
            } else {
                ForEach(linked) { LinkedSourceRow(store: store, source: $0) }
            }
            Button { adding = true } label: {
                Label("Add a Letterboxd source", systemImage: "plus")
            }
            .disabled(full)
            .sheet(isPresented: $adding) {
                AddSourceSheet(store: store, linkedAfter: Swift.min(count + 1, max), max: max)
            }
        } header: {
            HStack {
                Text("Lists & other people’s watchlists")
                Spacer()
                Text(LetterboxdLogic.linkedOf(count, max: max)).monospacedDigit()
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if full {
                    Text("You’ve reached your limit of \(max) linked sources. Remove one to add another.")
                }
                if linked.contains(where: { $0.status == "BLOCKED" && !$0.viaFlaresolverr }) {
                    Text("**Lists are best effort.** Letterboxd sits behind Cloudflare and may block automatic readers.")
                }
            }
        }
        .listRowBackground(AccountStyle.cell)
    }
}

/// One linked list or followed watchlist (web `LinkedSourceRow`): status pill,
/// films, requested and last check, its switch, and Sync now / Remove.
private struct LinkedSourceRow: View {
    @Environment(AppModel.self) private var model
    let store: WatchlistsStore
    let source: LbSource
    @State private var askingRemove = false

    var body: some View {
        let meta = LetterboxdLogic.status(source.status)
        let solved = source.viaFlaresolverr && source.status == "OK"
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: source.isList ? "list.bullet" : "person.2")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(meta.tone.color)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title).foregroundStyle(Theme.txt).lineLimit(2)
                HStack(spacing: 6) {
                    WatchlistPill(text: solved ? "Healthy · via solver" : meta.label, color: meta.tone.color)
                    Text(detail).font(.caption).foregroundStyle(Theme.mut).lineLimit(1)
                }
                if let note { Text(note).font(.caption).foregroundStyle(Theme.miss) }
            }
            Spacer(minLength: 4)
            Toggle("Auto-request from \(source.title)", isOn: Binding(get: { source.enabled }, set: { on in setEnabled(on) }))
                .labelsHidden()
                .disabled(store.letterboxdBusy)
            Menu {
                Button("Sync now", systemImage: "arrow.clockwise") { sync() }
                Button("Remove", systemImage: "trash", role: .destructive) { askingRemove = true }
            } label: {
                Image(systemName: "ellipsis.circle").font(.system(size: 18))
            }
            .accessibilityLabel("Options for \(source.title)")
        }
        .confirmationDialog("Remove \(source.title)?", isPresented: $askingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { remove() }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Nothing already requested is cancelled.")
        }
    }

    private var detail: String {
        var parts = [source.isList ? "List" : "Watchlist"]
        if let films = source.itemCount { parts.append("\(films) films") }
        if source.enabled {
            parts.append("\(source.requestedCount) requested")
            parts.append("checked \(WatchlistTime.lastRun(source.lastCheckedAt))")
        } else {
            parts.append("Off")
        }
        return parts.joined(separator: " · ")
    }

    /// The status line under a source (web `StatusLine`).
    private var note: String? {
        switch source.status {
        case "BLOCKED":
            return LetterboxdLogic.blockedLine(hours: LetterboxdLogic.hoursUntil(source.retryAt))
        case "PRIVATE":
            guard let error = source.lastError else { return nil }
            return "\(error). fusionha can only follow what’s public on Letterboxd. Set it to public to keep it in sync."
        case "DEGRADED":
            return source.lastError.map { "\($0). The rest are fine." }
        case "ERROR":
            return source.lastError
        default:
            return nil
        }
    }

    private func setEnabled(_ on: Bool) {
        let id = source.id
        Task {
            await store.sourceChange(model, success: on ? nil : "Source turned off · nothing already requested is affected") {
                _ = try await $0.updateRequestSource(id: id, enabled: on)
            }
        }
    }

    private func sync() {
        let id = source.id
        let title = source.title
        Task {
            await store.sourceChange(model, success: "Checking \(title) now") { _ = try await $0.syncRequestSource(id: id) }
        }
    }

    private func remove() {
        let id = source.id
        Task {
            await store.sourceChange(model, success: "Removed · nothing already requested was cancelled") {
                try await $0.deleteRequestSource(id: id)
            }
        }
    }
}
